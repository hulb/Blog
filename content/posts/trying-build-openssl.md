---
title: "尝试构建Openssl的见闻"
date: 2024-07-25T21:00:47+08:00
draft: false
---
我的服务器环境是redhat 8.4，上面的openssl版本比较老是1.1.1g。最近关注openssh漏洞实留意到openssl其实也应该使用比较新的版本才好，但是考虑到兼容性风险，想着升级到官方1.1.1w版本。但是没有找到现成的包，于是自己编译构建。从中学习到了redhat backporting机制，记录一下。
<!--more-->

不像openSSH源码中就带有编译rpm包的spec文件，openssl编译rpm需要自己准备。不过好在redhat也有现成[开源的构建配置](https://gitlab.com/redhat/centos-stream/rpms/openssl/-/blob/c8s/openssl.spec?ref_type=heads)，只是版本是1.1.1k。天真的我在它的基础上做了写删减就开干了。编译好安装到系统上发现不兼容：
```bash
sudo: error in /etc/sudo.conf, line 19 while loading plugin "sudoers_policy"
sudo: unable to load /usr/libexec/sudo/sudoers.so: /lib64/libk5crypto.so.3: undefined symbol: EVP_KDF_ctrl, version OPENSSL_1_1_1b
```

sudo命令报依赖错误。原来redhat系统上发布的openssl并非万全由上游openssl官方源码编译而来！这时才惊觉为什么redhat开源的构建仓库中有很多patch文件之类的东西。而且一般不推荐自己编译openssl来替换当前发行版上的版本。openssl组件太底层了，可能涉及到很多组件依赖它。

既然这样，那我就用redhat构建配置和脚本，只是将版本换成1.1.1w(开源的构建配置中版本为1.1.1k)。结果发现也不行，patch文件应用时报错了。估计是代码不一致导致的。

再仔细看了下spec文件，发现这些patch都是在修复一些安全漏洞。原来redhat通过backporing机制来应对发布出去的软件的缺陷。在[这里](https://github.com/openssl/openssl/issues/11471#issuecomment-609645505)有更详细的说明。

例如redhat在发布8.4系统时带了openssl 1.1.1g（假设）,但是后来发现了bug，openssl官方源码实际已经到了openssl 3.xxx版本。redhat的做法并不是编译最新版本openssl源码发布更新给客户，因为这样会造成潜在的兼容性风险太多。

redhat会关注openssl官方的每个commit更新，来决定将哪些作为patch引入到他们发布的那个版本上。经过测试验证没问题后再发布给客户。这时虽然软件版本仍然是1.1.1g，但是相关的缺陷实际上已经被修复了。

了解到这一点后，我果断选择了安装从https://pkgs.org/search/?q=openssl上找到的Rocky Linux发布的1.1.1k版本的rpm包。


参考：
https://mta.openssl.org/pipermail/openssl-users/2019-November/011552.html
https://github.com/openssl/openssl/issues/11471#issuecomment-609645505
