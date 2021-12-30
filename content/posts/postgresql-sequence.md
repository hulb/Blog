---
title: "Postgresql Sequence"
date: 2019-09-25T13:50:25+08:00
lastmod: 2019-09-25T13:50:25+08:00
draft: false
keywords: ["postgres","sequence","auto_increament"]
description: ""
tags: ["postgres", "sequence"]
categories: ["postgres"]
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
记录下postgres中实现自增id的方式。
<!--more-->

在mysql中我们可以将给一个列定义auto_increment属性，用来实现自增id，但是在postgresql中并不支持这个属性。在postgresql中的要实现列自增有两种方式：

1. 创建将一个列声明为serial:
```SQL
    Create table test(
        Id not null serial
    );
```

2. 创建一个序列，然后这个自增列的默认值从序列生成:
```SQL
    Create sequence seq_test_id;
    Create table test(
        Id not null default nextval('seq_test_id')
    );
```

这两种方式是实现的效果是相同的的，见官方文档：https://www.postgresql.org/docs/8.1/static/datatype.html#DATATYPE-SERIAL

不同点在于，声明一个列为serial时，会自动创建一个sequence，然后这个列如果被删掉了，这个sequence会自动被删掉，如果有其他地方用到，则该处不在生效，所以如果要有多个地方公用一个sequence，正确的做法是手动创建sequence，类似于方法2.