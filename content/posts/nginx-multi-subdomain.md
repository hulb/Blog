---
title: "Nginx 配置多个子域名"
date: 2019-06-13T16:54:51+08:00
lastmod: 2019-06-13T16:54:51+08:00
draft: false
keywords: ["nginx", "subdomain"]
description: ""
tags: ["nginx"]
categories: ["nginx"]
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
查了很多资料，终于给网站加了多个子域名，这样以后就可以有很多玩法了。这里记录一下。

<!--more-->
首先需要在dns解析里添加A记录，将多个子域名都指同一个服务器的地址。

![subdomaindns](/subdomaindns.png)

然后下面是nginx配置，分别用了两个文件来放这两个server。
```nginx
server {
        listen 80 ;
        server_name blog.example.com;

        location / {
                proxy_pass http://127.0.0.1:8888;
        }
}
```

```nginx
server {
        listen 80 ;
        server_name git.example.com;

        location / {
                proxy_pass http://127.0.0.1:8899;
        }
}
```
这里两个server都监听80端口，但是server_name不同，nginx会根据请求的server来匹配这里的server_name，然后反向代理到不同的后端server。摸索了很久其实很简单。然后使用了cloudflare的服务将域名挂过去还自动给我加了SSL，太棒了。