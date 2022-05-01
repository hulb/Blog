---
title: "Go JSON 序列化 []byte 类型的细节 "
date: 2022-05-01T18:19:31+08:00
lastmod: 2022-05-01T18:19:31+08:00
draft: false
keywords: ["go", "json"]
description: ""
tags: ["go", "serialization", "json"]
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
最近用go写web api时遇到一个关于`[]byte`类型JSON序列化的问题，做一下记录。
<!--more-->

事情的起因是我要做一个web服务，用来保存包含任何JSON内容的记录，并正常读出。这个需求其实很简单，由于JSON字段都是文本，可以直接读写JSON文本就可以了。但是考虑到JSON文本会涉及到转义的问题，我采用直接存储`[]byte`类型的数据。数据库也都支持这种类型的存储。模型结构大概是这样：
```
type record struct{
    Content []byte`json:"content"`
}
```
用这个接口对于创建请求来说，将http body绑定到这个结构没有问题，但是读取的时候如果返回这个结构，由于`Content`类型是`[]byte`，最终的响应里`Content`内容其实是被`base64`编码的字符串。经过同事的提点，将`[]byte`类型换成`json.RawMessage`就好了。可是`json.RawMessage`其实只是`[]byte`的另一个名字，为何会有这样的区别呢？带着疑问看了下go的json序列化细节才恍然大悟。

go内置的`encoding/json`包序列化JSON逻辑的核心在`encoding/json/encode.go`文件的`newTypeEncoder`函数：
```

// newTypeEncoder constructs an encoderFunc for a type.
// The returned encoder only checks CanAddr when allowAddr is true.
func newTypeEncoder(t reflect.Type, allowAddr bool) encoderFunc {
	if t.Kind() != reflect.Pointer && allowAddr && reflect.PointerTo(t).Implements(marshalerType) {
		return newCondAddrEncoder(addrMarshalerEncoder, newTypeEncoder(t, false))
	}
	if t.Implements(marshalerType) {
		return marshalerEncoder
	}
	if t.Kind() != reflect.Pointer && allowAddr && reflect.PointerTo(t).Implements(textMarshalerType) {
		return newCondAddrEncoder(addrTextMarshalerEncoder, newTypeEncoder(t, false))
	}
	if t.Implements(textMarshalerType) {
		return textMarshalerEncoder
	}

	switch t.Kind() {
	case reflect.Bool:
		return boolEncoder
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return intEncoder
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64, reflect.Uintptr:
		return uintEncoder
	case reflect.Float32:
		return float32Encoder
	case reflect.Float64:
		return float64Encoder
	case reflect.String:
		return stringEncoder
	case reflect.Interface:
		return interfaceEncoder
	case reflect.Struct:
		return newStructEncoder(t)
	case reflect.Map:
		return newMapEncoder(t)
	case reflect.Slice:
		return newSliceEncoder(t)
	case reflect.Array:
		return newArrayEncoder(t)
	case reflect.Pointer:
		return newPtrEncoder(t)
	default:
		return unsupportedTypeEncoder
	}
}
```
简而言之就是代码会通过反射获取要被序列化成json的对象的类型，然后`newTypeEncoder`中根据不同的类型返回不同的`encoderFunc`。而`[]byte`类型和`json.RawMessage`类型不同的处理逻辑就在这里分叉。对`[]byte`类型，会被识别成`reflect.Slice`, `return newSliceEncoder(t)`。我们接着看：

```
func newSliceEncoder(t reflect.Type) encoderFunc {
	// Byte slices get special treatment; arrays don't.
	if t.Elem().Kind() == reflect.Uint8 {
		p := reflect.PointerTo(t.Elem())
		if !p.Implements(marshalerType) && !p.Implements(textMarshalerType) {
			return encodeByteSlice
		}
	}
	enc := sliceEncoder{newArrayEncoder(t)}
	return enc.encode
}
```
在这里, 对于`[]byte`会直接返回`encodeByteSlice`，这是一种特殊处理，其他类型的slice不会会返回`sliceEncoder`。而在`encodeByteSlice`中会对于`[]byte`进行`base64`编码处理。

不要忘了，`json.RawMessage`底层也是`[]byte`类型，为什么它不会呢？因为它实现了`json.Marshaler`, 所以在`newTypeEncoder`中会返回`marshalerEncoder`, 而这里的实现对于`[]byte`来说处理有所不同：
```
func marshalerEncoder(e *encodeState, v reflect.Value, opts encOpts) {
	if v.Kind() == reflect.Pointer && v.IsNil() {
		e.WriteString("null")
		return
	}
	m, ok := v.Interface().(Marshaler)
	if !ok {
		e.WriteString("null")
		return
	}
	b, err := m.MarshalJSON()
	if err == nil {
		// copy JSON into buffer, checking validity.
		err = compact(&e.Buffer, b, opts.escapeHTML)
	}
	if err != nil {
		e.error(&MarshalerError{v.Type(), err, "MarshalJSON"})
	}
}
```
首先会调用类型自己的`MarshalJSON`，而`json.RawMessage`的`MarshalJSON`实现逻辑是直接返回`[]byte`。`marshalerEncoder`中会对返回的`[]byte`进行`compact`处理。

一切真相大白，虽然都是`[]byte`类型，但由于`encoding/json`包中的特殊处理，`json.RawMessage`返回的是经过`compact`的字符串而不是`base64`编码的字符串。
