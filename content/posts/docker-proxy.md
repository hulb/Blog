---
title: "Docker Proxy"
date: 2020-11-25T22:43:26+08:00
lastmod: 2020-11-25T22:43:26+08:00
draft: false
keywords: ["docker", "proxy"]
description: ""
tags: ["docker"]
categories: []
author: "hulb"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: false
toc: false
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
reward: false
mathjax: false
---
最近在用docker拉“墙”外镜像时设置的proxy总是不生效，坑了好久终于好了，记录一下。

<!--more-->
要想让docker走代理说起来也简单，分几种情况：
  - 想要运行起来的容器使用代理
  - 想要docker pull的时候走代理

第一种情况就是设置docker client配置文件，一般在`~/.docker/config.json`;对于Docker 1.06以及以下版本的这个方法不适用，只能给容器设置环境变量，如在Dockerfile中添加
```
ENV HTTP_PROXY="http://127.0.0.1:3001"
```
或是docker run的时候带上`--env HTTP_PROXY="http://127.0.0.1:3001"`。官方文档在[这里](https://docs.docker.com/network/proxy/)

对于第二种情况还需要细分，如果是比如WSL2里安装的docker，docker服务是通过`sudo service docker start`起来的，启动时实际会执行脚本`/etc/init.d/docker`;而这个脚本中会读取`/etc/default/docker`这个文件中的内容加载为环境变量，所以需要在文件中添加：
```
export HTTP_PROXY="http://web-proxy:8080"
export HTTPS_PROXY="http://web-proxy:8080"
export NO_PROXY="localhost,127.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.0.0.0/8"
```

如果docker服务是通过systemd来管理的，docker deamon起来时会读取systemd相关的docker.sevice的服务配置，要想让docker pull可以走proxy需要在systemd的docke.sevice目录下添加http-proxy.conf文件中添加：
```
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:80"
Environment="HTTPS_PROXY=https://proxy.example.com:443"
Environment="NO_PROXY=localhost,127.0.0.1,docker-registry.example.com,.corp"
```
而使用systemd的时候，docker服务文件位置会因为起docker服务的方式不同略微不同。正常情况下文件路径为`/etc/systemd/system/docker.service.d`,如果文件夹不存在需要创建，然后添加http-proxy.conf文件；在使用rootless mode起docker服务时路径在~/.config/systemd/user/docker.service.d。

systemd的配置文件更改后需要执行systemd重启。
```
# 一般模式重启
sudo systemctl daemon-reload
sudo systemctl restart docker

# rootless mode重启
systemctl --user daemon-reload
systemctl --user restart docker

```

参考：
- https://docs.docker.com/network/proxy/
- https://medium.com/@stevegy/wsl-2-docker-behind-proxy-fc55083d5ec5
- https://docs.docker.com/config/daemon/systemd/