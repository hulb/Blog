---
title: "Protobuf Import 路径问题"
date: 2019-09-16T17:54:49+08:00
lastmod: 2019-09-16T17:54:49+08:00
draft: false
keywords: ["protobuf", "path"]
description: ""
tags: ["protobuf"]
categories: ["protobuf"]
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
最近要把项目中的某块数据结构的序列化换成protobuf，遇到了引用其他`.proto`文件中结构的问题。查了很多资料总算解决了，这里记录一下。
<!--more-->

先说一下我的当前开发环境
```
- windows 10 1903
- go1.12.7 windows/amd64
- 当前项目使用go.mod来维护依赖关系
- visual studio code + ms-vscode.go插件 + zxh404.vscode-proto3插件
```

项目代码结构示意
```
- myproject
    - dir1
        - package_a
            - a.proto
    - dir3
        -package_b
            - b.proto
    
```

`a.proto`中需要引用`b.proto`中定义的结构。此时在`b.proto`中就按照标准写法定义结构

```
syntax = "proto3";
package b;

message StructB {
    bool test = 1;
}
```

然后在`a.proto`中引用

```
syntax = "proto3";
package a;
import "project_module/dir3/package_b/b.proto"

message StructA {
    package_b.StructB test = 1;
}
```

这里的`project_module`指的是go.mod中的module名称。然后这么配置的时候，zxh404.vscode-proto3插件会提示import的路径不存在，以及package_b。StructB未定义；忽略这些错误。

最后<b>将当前目录切换到my_project的上级目录</b>，执行
```
protoc --go_out=. ./my_project/dir1/package_a/a.proto
```

`my_project`名称要与module名称一致，protoc会先根据`./my_project/dir1/package_a/a.proto`路径找到文件，然后根据import的路径找到引用的元素；注意这里都是根据路径。protoc没有关心module名称。