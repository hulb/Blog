---
title: "了解了下Go Context"
date: 2019-09-24T21:02:48+08:00
lastmod: 2019-09-24T21:02:48+08:00
draft: false
keywords: ["go","context"]
description: ""
tags: ["go"]
categories: ["go"]
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
最近看到将go里面context的文章，之前对这块了解不多。感觉很奇怪为何parent context的取消同时可以影响到child context的取消,以此做链式控制。跟着网上前人的一些技术博客看了下context源码，代码不多也很容易看懂。这里记录下看到的几个有意思的地方。
<!--more-->

第一个是`WithCancel`这个函数返回的时候：

```go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc) {
	c := newCancelCtx(parent)
	propagateCancel(parent, &c)
	return &c, func() { c.cancel(true, Canceled) }
}
```

最后返回了一个`func(){c.cancel(true, Canceled)}`，这里很巧妙。用一个wrapper方法将实际函数内容返回出去，等到最终调用的时候才执行`c.cancel(true, Canceled)`，跟python的装饰器一样。

同样在找到的[Go语言并发模型：像Unix Pipe那样使用channel](https://segmentfault.com/a/1190000006261218)这篇博客里，使用channel实现的'pipline'也很有趣。摘抄一点代码

```
func gen(nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        for _, n := range nums {
            out <- n
        }
        close(out)
    }()
    return out
}
```

这里将channel返回出来，然后协程里起始在往这个channel里写数据，但是由于channel没有被读取而阻塞。所以当channel被读取的时候，协程里往channel里放数据的操作才会执行。

说回context接口。除了最原始的`background`和`todo`这两个`emptyCtx`类型之外，其余实现context接口的都是以`cancelCtx`作为基础。所以每个类型都会存在`done`和`children`，parent context之所以可以影响到child context就是因为它在`children`属性里记录了所有child context；控制通过`done`这个cahnnel来实现，在协程中通过调用`Done()`函数监听到`done`这个channel，然后在`cancel`函数被调用的时候关闭掉`done`channel，从而将一个信号让所有监听的地方收到；同时还会遍历当前context的'children'，去`cancel`掉所有的child context，致使所有监听child context的`done`channel的地方收到信号。
