---
title: "Docker Security 笔记（一）"
date: 2024-04-03T13:02:16+08:00
draft: false
---
在工作中经常遇到docker容器部署使用时与操作系统权限和安全特性有关的问题，于是查了下docker文档和一些资料，这里结合自己的理解做一下记录。
<!--more-->

## Docker的基本原理
粗略地看docker容器是一种利用[Linux的namespace](https://en.wikipedia.org/wiki/Linux_namespaces)进行进程隔离的技术。实际的进程还是运行在主机上，跟普通非docker容器进程的区别是它运行在特定的一组Linux namespace中。很多博客关于这一点都有很详细的介绍，比如[这个](https://www.cnblogs.com/sammyliu/p/5878973.html)，这里就不展开。

Namespace 实现了对容器中进程的资源隔离，因此进程看到的文件系统是一套隔离与host上的文件系统。而很多时候进程需要读写host上的文件系统，这时一般采用volume或bind来实现。原理就是将指定的host文件挂在到容器的文件系统指定位置，这时容器中的进程就可以对挂载的目录进行读写，这时就会有安全隐患。想象一下，host上的/root, /etc, /sys 等目录被挂载进去后，进程可以对这些目录进行读写的话，就有可能损坏host系统。同时Linux系统提供一些系统调用，有些系统调用使用不当也可能造成严重后果，比如init_module可以加载内核模块。

对于这些安全风险，Linux系统已经有相应的安全机制来应对，而结合到容器上可能会对容器中进程的正常运行产生一些影响。以下就我自己的理解来谈谈。

## Linux 用户目录权限
Linux上有一种比较常见的用户组目录权限，即一个目录/文件的权限分为对所有者，所有组和others的：读(r)，写(w)，执行(x)。基于此，进程是否能读写文件区别于执行进程的用户是否有对文件的权限。root是Linux的超级用户，不受这个权限机制的约束。而docker在运行容器时一般是以root用户执行进程，所以这时进程拥有对挂载到容器中的文件的权限。

常见的一种做法是在容器镜像构建时使用`User`指令声明容器启动时以特定非root用户来运行进程，或是容器运行时用`--user`指定以什么用户来启动容器执行进程；这时该进程就执行访问`User`用户有权限的文件。因此对挂载进容器的文件而言，只有它的 others 权限为`r/w`，容器中的进程才可以读写。或者挂载进去的目录允许 others 读写，这样进程可以在这个目录下创建自己可以读写的文件。

## SELinux 机制
基础的Linux文件目录权限机制粒度比较粗，Linux系统还有[SELinux(Security-Enhanced Linux)](https://en.wikipedia.org/wiki/Security-Enhanced_Linux)，对进程可访问的资源进行更细粒度的控制。这个机制不是取代文件目录权限机制，而是从另一个维度进行更加严格的控制。比如有的进程是以root用户运行的，那么它就可以读写所有文件；而SELinux通过对比进程和文件等资源上的文本标签，来确定该进程是否可以访问这个文件，不看用户。

于是可以实现容器中的进程虽然以root身份运行，但仍然对挂载进去的某些目录不具备访问权限。SELinux在现在的操作系统中大多默认是开启的，但是docker没有默认将它应用到容器上。要启用需要调整docker daemon的配置，一般是编辑文件`/etc/docker/daemon.json`，添加：
```json
{
    "selinux-enabled": true
}
```
然后重启docker服务后，docker在运行容器时就会对进程打上特定SELinux标记(`container_file_t`)，以约束该进程只能访问带有特定SELinux标记的文件。

## Linux Capabilities 和 seccomp 机制
[Linux Capabilities]（https://en.wikipedia.org/wiki/Capability-based_security）是对权限的另一种细粒度的划分和控制。它将root的权限分割成多个部分，可以做到虽然进程以root用户运行，但只能执行某些root权限操作。比如可以禁止容器中的进程(root运行)执行kill命令：`--cap-drop KILL`， 或是允许容器中的进行修改host的时间: `--cap-add SYS_TIME`。容器运行时默认就有的可以看[这里](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux_atomic_host/7/html/container_security_guide/linux_capabilities_and_seccomp#doc-wrapper)

[seccomp](https://en.wikipedia.org/wiki/Seccomp)是一种沙箱，约束进程可以使用的系统调用，在host开启的前提下docker默认会应用一个[seccomp profile](grep CONFIG_SECCOMP= /boot/config-$(uname -r))来对容器中的进程进行约束。默认的seccomp profile中被限制的系统调用有[这些](https://docs.docker.com/engine/security/seccomp/#significant-syscalls-blocked-by-the-default-profile)。有时我们可能需要容器中的进程可以执行某些被限制的系统调用，可以使用`--security-opt seccomp=unconfined`来万全禁用容器内的seccomp约束，或是使用

## user namespace remapping
到此可以安全机制存在的目的就是限制对一些文件的访问，对普通用户基础的用户目录权限可能就够了。SELinux可以用来root用户运行的进程进行更细粒度的控制。在容器的使用场景中，也有通过`User`或`--user`来避免使用root用户的方式。正常情况下这些措施足够使用，但在某些场景中容器中的进程需要以root身份运行，这时对host来说通常意味这更多的安全风险。而在容器数量和文件数量较多的情况下SELinux设置可能也比较繁琐。那么或许可以从另一个角度来解决这个问题，即容器内进程以 root 用户运行，但实际上对host而言它是以某一个普通用户运行的。

前面说道docker基本原理就是linux namespace，其中有一个叫做user namespace。使用它可以让人容器中使用另一套与host上不同的用户和组ID。`User`和`--user`功能也是基于此的。容器运行时创建一个新的user namespace，有这个namespace内的用户和组id；同时可以跟host上的用户和组id建立映射，这种映射使得容器内的用户继承了相应host上用户和组对文件的权限和所有权。这种映射范围通过`/etc/subuid`和`/etc/subgid`来定义
```
vagrant:100000:65536
```
这个配置的意思是`vagrant`用户在当前namespace中可以有65536和从属用户，用户id从1000000开始，最大为100000+65536。默认情况下docker并没有启用这种映射，需要通过更改docker daemon配置文件开启：
```json
{
    "userns-remap": true
}
```
重启docker服务生效后会发现镜像和已经运行的容器都看不到了。这是因为开启后docker做了相应处理，详细可以看[这里](https://www.cnblogs.com/sparkdev/p/9614326.html)。这种映射机制更进一步提供了安全保障，但同时也会带来使用上的[问题](https://docs.docker.com/engine/security/userns-remap/#user-namespace-known-limitations)。

## 结语
以上这些机制的根本目的是约束进程可以访问的资源和行为。容器虽然基于namespace虽然实现了一定程度的隔离，但这种隔离有可能被绕过，这称为逃逸。不止在容器技术中，在虚拟化技术中也存在逃逸。于是如何避免逃逸后的进程对系统进行非法访问和破坏就变得很重要，这些安全机制的重要性也不言而喻。以上只是对了解到的机制和技术做了简单记录和梳理，并未细致展开各项机制的配置，作用原理。每个都包含不少的内容，如果想详细了解还需查阅相关资料。

## 参考
- https://projectatomic.io/blog/2016/07/docker-selinux-flag/
- https://projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/
- https://abdelouahabmbarki.com/linux-user-namespaces/
- https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux_atomic_host/7/html/container_security_guide/docker_selinux_security_policy
- https://docs.docker.com/engine/security/userns-remap/
- https://www.cnblogs.com/sparkdev/p/9614326.html
- https://book.hacktricks.xyz/linux-hardening/privilege-escalation/docker-security/namespaces/user-namespace
- https://github.com/containers/podman/issues/10779#issuecomment-868783046
