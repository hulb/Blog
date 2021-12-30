---
title: "博客的CI/CD方案"
date: 2019-09-24T22:09:23+08:00
lastmod: 2019-09-24T22:09:23+08:00
draft: false
keywords: ["CI","CD", "docker", "webhook"]
description: ""
tags: ["CI","CD"]
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
好像还没有介绍我这个博客的CI/CD链。我自己感觉很清爽。
<!--more-->

不同与之前写的[用travis自动构建Hugo的Github Pages](https://hulb.club/post/hugo-travis-github-pages)，`hulb.club`这个站点的博客是部署在我的vps上的。也没有采用直接proxy[源站点](https://hulb.github.io)的方式。而是直接部署在容器中的静态站点。

首先跟之前说过的一样，我是采用hugo框架,通过向github的仓库提交`.md`文件来写博客；然后docker hub上可以设置监听我的博客源码仓库,有更新时，自动触发镜像构建。以下是我镜像构建的Dockerfile

```Dockerfile
FROM hulb/docker-hugo AS build
WORKDIR /hugo
COPY ./ /hugo
RUN mkdir /blog
RUN /go/hugo -d /blog

FROM nginx:alpine
COPY --from=build /blog /usr/share/nginx/html
```

为了构建时比较快，以及hugo版本稳定，我自己打了一个固定版本的hugo镜像。采用分阶段构建的方式，使用nginx镜像来跑镜像站点。然后docker hub也是可以设置web hook的，我写了一个简单的程序开放一个api，跑在vps上供docker 镜像构建好后调用。在程序中如果收到docker hub的web hook通知，我就去更新vps上的博客镜像并重启。这算是一个简单的CI/CD场景吧。其实也类似与IFTTT，将不同的web service或API通过一定的方式连接起来组成workflow。

如果实施具体的商业项目，应该还要有更多诸如降级，灰度等方面的考虑。
