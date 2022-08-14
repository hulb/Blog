---
title: "试用Cloudflare Pages"
date: 2022-08-14T12:41:24+08:00
lastmod: 2022-08-14T12:41:24+08:00
draft: false
keywords: ["CD","static website", "cloudflare pages"]
description: ""
tags: ["CD","blog", "cloudflare"]
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
之前介绍过我的这个博客的CI/CD方案。之前是用docker hub的hook来监听github仓库出发Docker镜像构建，然后通过webhook出发部署在我的VPS上的小工具去更新容器。最近知道Cloudflare Pages也提供类似的功能，来试试。

Cloudflare Pages更加方便地可以直接监听github仓库然后出发hugo构建，将构建好的静态网站文件直接部署。整个配置过程也非常简单且流畅。依次是：设置github仓库，选择支持的静态网站生成器或构建工具，然后配置一下环境变量，最后点击构建部署稍等片刻之后就好了。

首选选择Pages项目创建方式。Pages提供了三种方式：git, upload assets, cli。顾名思义git就是连接git仓库；upload assets是上传资源包；cli就是用cloudflare提供的cli工具。我这里选择git，并设置好github仓库。

![Git-repository-setting](/pages-conf-1.png)

接着配置构建框架和生成工具。Pages支持很多静态网站生成工具，我选择hugo,构建工具填的是`hugo`, 输出目录默认是`/public`;对于不同的构建工具默认输出目录不一样。具体可以看[文档](https://developers.cloudflare.com/pages/platform/build-configuration)。除此之外还要添加指定hugo版本的环境变量，因为默认使用的hugo版本比较低，这些在文档里也有说。

![build-params-setting](/pages-conf-2.png)

最后点击保存部署即可。几秒钟就能部署完成，且可以看到构建日志。Pages会默认分配一个域名来访问站点，你也可以设置自己的域名。

![build-deploy-done](/pages-conf-3.png)

整个过程非常方便流畅，且部署后直接可以访问，真香！