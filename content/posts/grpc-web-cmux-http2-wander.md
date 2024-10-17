---
title: "Grpc Web Cmux HTTP2 漫游"
date: 2024-10-17T19:56:59+08:00
draft: true
keywords: ["grpc","cmux", "connect-rpc", "vanguard", "buf", "http2"]
description: ""
tags: ["grpc", "rpc", "http2"]
categories: ["grpc"]
author: "hulb"
comment: false
toc: false
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
reward: false
mathjax: false
---
很早就听说有类似grpc gateway的东西，可以通过定义grpc服务的方式来提供REST api服务。最近有空简单尝试了下，记录一下。

<!--more-->
先是看到[构建浏览器兼容的 gRPC 服务](https://george.betterde.com/technology/20240904.html), 按图索骥使用了下buf，还是挺好用的。先贴一下我使用的buf配置：
```buf.yaml
# For details on buf.yaml configuration, visit https://buf.build/docs/configuration/v2/buf-yaml
version: v2
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
deps:
  - buf.build/googleapis/googleapis
```

```buf.gen.yaml
version: v2
plugins:
  - local: protoc-gen-go
    out: gen/go
    opt: 
      - paths=source_relative
  - local: protoc-gen-connect-go
    out: gen/go
    opt: 
      - paths=source_relative
  - local: protoc-gen-go-grpc
    out: gen/go
    opt:
      - paths=source_relative
```
通过在`buf.gen.yaml`中使用不同的plugin就可以编译出对应的go代码。这里我了三个插件：protoc-gen-go生成定义的struct对应的go代码；protoc-gen-connect-go生成connectRPC对应的服务代码；protoc-gen-go-rpc生成gRPC对应的服务端代码。

我的Proto文件定义如下：
```proto
syntax = "proto3";

package test.v1;

import "google/api/annotations.proto";

option go_package = "github.com/hulb/rpc-test/gen/go/proto";

service TestService {
  rpc GetSelectOptions(GetSelectOptionsReq) returns (GetSelectOptionsResp) {}
}

message GetSelectOptionsReq {
  string id = 1;
}

message GetSelectOptionsResp {
  message Option {
    string name = 1;
    repeated string values = 2;
  }

  repeated Option options = 1;
}
```
包含生成代码的目录结构如下：
```
├── gen
│   └── go
│       └── proto
│           ├── protoconnect
│           │   └── test.connect.go
│           ├── test_grpc.pb.go
│           └── test.pb.go
├── proto
│   └── test.proto
├── buf.gen.yaml
├── buf.lock
├── buf.yaml
```
执行`buf dep update`生成`buf.lock`文件固定依赖的proto版本。执行`buf lint`进行格式检查，执行`buf generate`生成go代码。

使用也比较简单：
```go
import "github.com/hulb/rpc-test/gen/go/proto/protoconnect"

...
servicePath, handler := protoconnect.NewTestServiceHandler(taskDetailReportSvc)

```
得到的`servicePath`就是http接口路径， `handler`就是具体的处理器。不过这里`servicePath`可不符合restful风格，而且hanlder只能是POST请求。

在proto定义中可以通过`google.api.http`这个option来指定http 接口路径和参数等，例如改成：
```proto
...
service DetailTaskReportService {
  rpc GetSelectOptions(GetSelectOptionsReq) returns (GetSelectOptionsResp) {
    option (google.api.http) = {get: "/v1/taskreport/detail/{task_id}"};
  }
}
...
```
再通过 `vanguard`包装一下：
```go
servicePath, handler := protoconnect.NewTestServiceHandler(testSvc)
service := vanguard.NewService(
    servicePath,
    handler,
    vanguard.WithTargetProtocols(
        vanguard.ProtocolGRPC,
    ),
)

handler, err := vanguard.NewTranscoder([]*vanguard.Service{service})
if err != nil {
    panic(errors.WithStack(err))
}
```
得到的仍然是一个处理器，不过这个处理器能处理的接口路径就是在proto中定义的`/v1/taskreport/detail/{task_id}`。具体可以看上面提到的博客和跟着[connectRPC的快速开始教程](https://connectrpc.com/docs/go/getting-started/)，写得非常清楚了。

到这里我开始产生了一个疑问，既然通过一份proto文件可以生成gRPC和restful接口两种对外提供服务的方式，那是否可以让他们监听在同一个端口，对外提供两种服务呢？

由于grpc server实现了http.Handler接口，所以可以这么做：
```go
grpcServ := grpc.NewServer()
httpMux := http.NewServeMux()

mySvc := &MyGrpcService{}
grpc_health_v1.RegisterHealthServer(grpcServ, mySvc)

mixedHandler := newHTTPandGRPCMux(httpMux, grpcServ)
http2Server := &http2.Server{}
http1Server := &http.Server{Handler: h2c.NewHandler(mixedHandler, http2Server)}
lis, err := net.Listen("tcp", ":8080")
if err != nil {
    panic(err)
}

err = http1Server.Serve(lis)

func newHTTPandGRPCMux(httpHand http.Handler, grpcHandler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.ProtoMajor == 2 && strings.HasPrefix(r.Header.Get("content-type"), "application/grpc") {
			grpcHandler.ServeHTTP(w, r)
			return
		}
		httpHand.ServeHTTP(w, r)
	})
}
```
这段代码来自于[Serving gRPC+HTTP/2 from the same Cloud Run container](https://ahmet.im/blog/grpc-http-mux-go/).不过gRPC的[`ServeHTTP`](https://github.com/grpc/grpc-go/blob/master/server.go#L1046)是实验性的，并不包含所有`grpc.Serve`的所有特性,且[性能差很多](https://github.com/grpc/grpc-go/issues/586)。

还看到了[vanguard的例子](https://github.com/connectrpc/vanguard-go/blob/main/internal/examples/pets/README.md)， 不过这个例子里只是在说明vanguard将RPC请求翻译成rEST请求的能力。

而后找到了[cmux](https://github.com/soheilhy/cmux)这个开源项目。它实现了一个tcp复用器,可以实现在一个监听端口上将不同请求的连接分发给不同的server来处理，这样就可以直接用`grpc.Server.Serve`了。不过发现它在处理http和grpc请求时会存在[bug](https://github.com/soheilhy/cmux/issues/91)。

cmux的原理在于将原始`net.Conn`上封装了一层`bufferReader`，通过读取连接开头的小部分数据判断该连接是http, tls还是http2, grpc。gRPC协议是基于http2的，理论上通过这种方式可以识别并将他们区分开。但是cmux对http2连接的处理存在问题，在使用时会导致`PROTOCOL ERROR`。之后看到[这个PR](https://github.com/soheilhy/cmux/pull/96/files)在尝试解决这个问题。我对此产生了兴趣，这个PR做了什么解决了这个问题呢？通过阅读代码，查阅HTTP2协议相关的资料大概有了了解。

HTTP2协议在建连过程中，client和server会发送setting frame来确认连接的一些参数，cmux中的没有正确处理setting frame导致了问题。找到了[这个博客](https://liqiang.io/post/how-http2-connection-connect-9e3ba97c?lang=ZH_CN)也讲了同样的问题。

但是看着PR代码，我还是觉得没有太理解。翻了下go HTTP2 server的实现发现server在连接开始时会先发送setting frame给客户端，然后等待客户端的preface。而cmux在对连接的开头的处理并不是这样，先是读取preface，然后读取客户端发来的frame。如果是不带ACK标记的setting frame会向客户端发送setting frame。[这里就有点奇怪了](https://github.com/soheilhy/cmux/pull/96/files#diff-12fb7eca9c5a82b2cf0ecc893fb10d7cc7599f605a23de6d54974d78d3fb7dd1R270)。

我猜是为了解决java grpc客户端会一直等待server端发送setting frame而采取的操作，但是感觉这时应该发送带ACK标记的setting frame才对。而PR的修正方式是丢弃了客户端发来的ACK setting frame，避免上层http2 server内部的`unackedSettings`计数错误。

上层http2 server并不知道conn在此之前经历了什么，而在bufferReader的作用下，预先读取的用作协议检测数据也会被上层http2 server读取到。cmux的代码中每次向客户端发送了setting frame，客户端返回的ACK setting frame都会被上层读到。[这段逻辑](https://cs.opensource.google/go/x/net/+/refs/tags/v0.30.0:http2/server.go;l=1738-1747)因此就出错了！

貌似PR的修正方法偏离了根本原因，只是通过将客户端的ACK setting frame丢弃避免了错误的出现。不过PR作者也说他在生产生应用了他的patch，但是依然很罕见地会出现`PROTOCOL ERROR`。

到这里时间已经过去很久了，这一路漫游还挺有趣的。跟PR作者留言表达了看法，不知道自己的想法是不是正确的。





参考：
- https://george.betterde.com/technology/20240904.html
- https://blog.cong.moe/post/2022-05-18-buf-tool/
- https://connectrpc.com/docs/go/getting-started/
- https://medium.com/@soheilhy/multiplexing-connections-in-go-5f198dbc68e7
- https://ahmet.im/blog/grpc-http-mux-go/