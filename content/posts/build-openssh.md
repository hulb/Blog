---
title: "源码编译linux OpenSSH"
date: 2024-07-25T21:35:45+08:00
draft: false
---
针对OpenSSH的安全漏洞，官方都会发布源码的新版本。记录一下如何通过源码编译rpm包。
<!--more-->

构建rpm包需要使用rpmbuild工具，提供一份构建所需的spec文件。而方便的是OpenSSH源码中即包含rpm包构建所需的spec文件。我们要做的就是在包含了所需构建工具的环境中进行编译构建。本文参考自[这篇博客](https://www.cnblogs.com/yanjieli/p/14220914.html)。

由于我的目标系统版本是redhat 8.4（目标系统决定了编译时用的glibc版本等依赖，最好在相同系统版本下编译），所以采用相同docker镜像来编译，以下是构建对应docker镜像的Dockerfile:
```Dockerfile
FROM centos:centos8.4.2105

RUN rm -rf /etc/yum.repos.d/* && curl https://mirrors.aliyun.com/repo/Centos-8.repo?spm=a2c6h.25603864.0.0.1d2f5969tcHnuS -o /etc/yum.repos.d/Centos-8.repo
RUN yum groupinstall -y "Development Tools" && yum install rpm-build zlib-devel openssl-devel gcc perl-devel pam-devel unzip gtk2-devel libXt-devel perl -y

RUN curl http://mirror.centos.org/centos/8-stream/PowerTools/x86_64/os/Packages/imake-1.0.7-11.el8.x86_64.rpm -o imake-1.0.7-11.el8.x86_64.rpm && rpm -iv imake-1.0.7-11.el8.x86_64.rpm

```

在该镜像中构建使用如下命令：
```shell
#! /usr/bin/bash

set -xe

if [ -z "$1" ]; then 
    version='8.9p1'
else 
    version=$1
fi

mkdir -p /root/rpmbuild/{SOURCES,SPECS} 
cd /root/rpmbuild/SOURCES 
curl https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$version.tar.gz -o openssh-$version.tar.gz 
curl https://src.fedoraproject.org/repo/pkgs/openssh/x11-ssh-askpass-1.2.4.1.tar.gz/8f2e41f3f7eaa8543a2440454637f3c3/x11-ssh-askpass-1.2.4.1.tar.gz -o x11-ssh-askpass-1.2.4.1.tar.gz 
tar -xzf openssh-$version.tar.gz 
cp openssh-$version/contrib/redhat/openssh.spec /root/rpmbuild/SPECS/ 
cd /root/rpmbuild/SPECS/ 
sed -i -e "s/%global no_x11_askpass 0/%global no_x11_askpass 1/g" openssh.spec 
sed -i -e "s/%global no_gnome_askpass 0/%global no_gnome_askpass 1/g" openssh.spec 
sed -i 's/BuildRequires: openssl-devel < 1.1/#&/' openssh.spec

rpmbuild -ba openssh.spec
echo $?
ls /root/rpmbuild/RPMS/x86_64/

```
通过`sed`调整了源码中的`openssh.spec`文件，这些配置和依赖项不是必要的。编译完成后即可看到rpm包。

不过在编译目前最新版本9.8p1时发现没有依赖openssl，导致编译出来的包不支持rsa密钥认证。后来发现是源码的`openssh.spec`中有bug:
```spec
...
%global without_openssl 0
# build without openssl where 1.1.1 is not available
%if 0%{?fedora} <= 28
%global without_openssl 1
%endif
%if 0%{?rhel} <= 7
%global without_openssl 1
%endif
...
```
这一段条件不正确，当我在redhat容器中编译时，`without_openssl`总会是`1`。于是在上面的命令中增加一行来修正：
```
sed -i -e "s/%global without_openssl 1/%global without_openssl 0/g" openssh.spec
```
不依赖openssl是可行的，只是会少很多来自于openssl的算法等。这样就可以编译出新的版本。

在升级时也要注意，需要备份`/etc/ssh/sshd_config`，`/etc/pam.d/sshd`和`/etc/sshd/`目录下的host key，以免host key变化后与客户端已经保存到`known_hosts`中指纹的不一致，造成问题。
可以用如下命令来升级：
```bash
mkdir -p /opt/sshd-update/backup /opt/sshd-update/rpms
cp /etc/ssh/sshd_config  /opt/sshd-update/backup/
cp /etc/pam.d/sshd /opt/sshd-update/backup/
rpm -Uvh /opt/sshd-update/rpms/openssh-*.rpm && \cp /opt/sshd-update/backup/sshd_config /etc/ssh/sshd_config && \cp /opt/sshd-update/backup/sshd /etc/pam.d/ && systemctl restart sshd
```
注意如果是通过ssh远程连接进入到系统，安装完rpm升级包后一定要在当前连接重启`sshd`服务。否则可能导致进不去系统。`systemctl restart sshd`不会导致当前连接断开，当前连接是for出来的子进程。
