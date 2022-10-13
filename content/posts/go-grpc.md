---
title: "Go gRPC"
date: 2022-10-13T14:50:07+08:00
lastmod: 2022-10-13T14:50:07+08:00
draft: false
keywords: ["gRPC", "go", "protocol-buffers"]
description: ""
tags: ["go","gRPC"]
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
go开发中经常使用gRPC,每次都需要重新熟悉一下，这里做个入门记录；对应代码在[这里](https://github.com/hulb/grpc-test).
<!--more-->

gRPC顾名思义是一种RPC协议。它采用`Protocol Buffers`来序列化数据。RPC调用一般包含两个部分，调用函数签名和请求响应格式。gRPC通过`.proto`文件来定义这两个部分，proto文件中定义传输结构和结构中的字段类型；protobuf支持的字段类型以及结构定义写法看[这里](https://developers.google.com/protocol-buffers/docs/proto3)。

#### proto文件
例如一个简单的请求响应格式定义 hello.proto：
```proto
syntax = "proto3"; // 版本申明，放最上面

option go_package = "github.com/hulb/grpc-test/pb"; // 申明包含这个文件生成的go代码所在package的import路径

message Request{ // 结构定义
    string msg = 1; // 字段定义,前面是类型，后面是字段名
}

message Response{
    string back = 1;
}

```
定义有了，如何来使用呢？

gRPC提供了`protoc`这个编译器将定义文件编译为不同语言的代码，不同语言代码的生成通过`protoc`的不同插件来实现。比如go语言需要使用的`protoc`插件是
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

安装这个插件后就可以通过`protoc`将上述`.proto`文件编译生成`.go`代码文件。通过如下命令：
```bash
protoc --go_out . --go_opt=module=github.com/hulb/grpc-test hello.proto
```

这里`--go_out`参数告诉`protoc`要调用go语言插件生成go代码,且生成的代码文件路径; `--go_opt`参数设置`protoc-gen-go`生成代码时的输出模式，可以看[这里](https://developers.google.com/protocol-buffers/docs/reference/go-generated)

生成的go代码中是`.proto`文件定义的数据结构在go语言中的定义。

上述这个过程是将数据结构的定义编译为go代码，接下来我们增加函数签名：
```proto
service Greeter{ // rpc 服务定义
    rpc SayHi(Request) returns(Response){};
}
```

`service`这部分定义RPC服务，需要通过另一个`protoc`插件来生成对应的go代码：
```
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```
安装好后生成命令上要增加`--go-grpc_out`以及`--go-grpc_opt`两个参数：
```bash
protoc \
--go-rpc_out= . \
--go-rpc_out=module=github.com/hulb/grpc-test \
--go_out . \
--go_opt=module=github.com/hulb/grpc-test \
hello.proto
```

#### 实现gRPC服务端和客户端
grpc代码生成后，接下来就是如何使用了。代码分为客户端和服务端。客户端很简单，去连接服务端调用接口即可：
```go
conn, err := grpc.Dial(serverAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
if err != nil {
    return err
}
client := pb.NewGreeterClient(conn)
resp, err := client.SayHi(cmd.Context(), &pb.Request{
    Msg:  "hi",
})
if err != nil {
    return err
}
```

服务端稍微麻烦点，`.proto`中定义了`service`，go代码中会对应生成`interface`，服务端需要实现这个接口；除此之外实现这个接口的结构需要嵌入生成的go代码中的`UnimplementedGreeterServer`结构：
```go
type service struct {
	pb.UnimplementedGreeterServer
}

func (s *service) SayHi(ctx context.Context, req *pb.Request) (*pb.Response, error) {
	return &pb.Response{
		Back: "back,hi",
	}, nil
}
```

这是对应`.proto`中`service`的go里面我们实现的服务, 然后新建一个grpc server实例，将这个`service`注册进去。有了这个以后再就是监听端口，接受请求：
```go
ls, err := net.Listen("tcp", listen)
if err != nil {
    return err
}
defer ls.Close()

s := grpc.NewServer()
pb.RegisterGreeterServer(s, &service{})

if err := s.Serve(ls);err!=nil{
    return err
}
```

通过`grpc.NewServer`新建一个gRPC server实例，将我们实现的`service`通过生成代码中的`RegisterGreeterServer`注册到gRPC server实例，然后启动实例提供服务。

#### proto定义import
有时候我们需要在`.proto`定义中使用`timestamp`类型的字段来代表时间，或是`struct`字段来代表动态结构。google 提供了这两种以及其他类型的[proto定义](https://github.com/protocolbuffers/protobuf/blob/main/src/google/protobuf/timestamp.proto)，下载`protoc`时会附带在里面，我们可以通过`import`的方式来使用：
```proto
import "timestamp.proto";
import "struct.proto";

message Request{
    string msg = 1;
    google.protobuf.Timestamp time = 2;
}

message Response{
    string back = 1;
    google.protobuf.Struct value = 2;
}

```

这里有两个问题，一是在生成代码是`protoc`如何找到通过`import`引入的proto定义; 二是引入的定义在使用时要带上包名，如：`google.protobuf.Timestamp`。

先看第一个问题。在执行代码生成时可以指定`--proto_path`来指定要引入的proto文件路径，比如我们将google的proto文件放在google/proto下，我们可以将上面的命令改为：
```bash
protoc \
--proto_path=./protoc/include/google/protobuf/
--proto_path= ./proto
--go-rpc_out= . \
--go-rpc_out=module=github.com/hulb/grpc-test \
--go_out . \
--go_opt=module=github.com/hulb/grpc-test \
hello.proto
```
注意当使用了`--proto_path`后，除了指定引入的proto文件所在路径外，还需要执行要编译的proto文件的路径，即`hello.proto`的路径。

第二个问题说的是每个proto文件都可以定义一个`package`名字，而在使用引入的proto定义时要带上这个`package`名字。比如google的`Timstamp`类型定义文件如下（截取开头片段）：
```proto
syntax = "proto3";

package google.protobuf;

...
```

所以我们在上面使用时应该用`google.protobuf.Timestamp`。

至此我们完成了go开发中gRPC的简单使用。