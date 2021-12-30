---
title: "Python Defaultdict"
date: 2018-03-15T13:13:49+08:00
lastmod: 2018-03-15T13:13:49+08:00
draft: false
keywords: ["python", "defaultdict"]
description: ""
tags: ["python"]
categories: ["python"]
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
在看代码的时候，发现用到一个collections.defaultdic类，以前接触得不多，查了查资料自己体验了一下，做个记录。

<!--more-->
[defaultdict](https://docs.python.org/2/library/collections.html#collections.defaultdict)类是dict的子类，返回一个类字典的对象。可以看作一个带有指定默认值的字典。一个典型的用法是给某个字典中不存在的key赋默认值，如：
```python
s = [('a', 1), ('b', 2), ('a', 3)]
d = defaultdict(list)
for k, v in s:
    d[k].append(v)

```
这里defaultdict接收了一个list类型作为参数，然后对于其中的元素，它的默认值就是list()。dict有一个setdefault()方法也可以实现这个功能，但是用defaultdict要更快更方便。

defaultdict的参数必须是callable的，除了list，set,int它们的初始默认值外，如果我们想传别的默认值，可以通过来传入返回值为一个callable对象的callable对象来做到，例如可以传入一个生成器
```python
a = [1,2,3]
def got():
    for i in a:
        yield i

d = defaultdict(got().next)
b = ['a', 'b', 'c']
for k in b:
    d[k] += 1

>>> d.items()
[('a', 2), ('c', 4), ('b', 3)]
```
但如果这里的len(a)<len(b)，当b遍历到后面是，got().next这个生成器会因为已经走完了而raise StopIteration异常。

也可以用itertools.repeat来设置一个固定默认值, [itertools.repeat()](https://docs.python.org/2/library/itertools.html#itertools.repeat)接收一个参数，构造一个返回该参数的迭代器。
```python
def got(value):
    return itertools.repeat(value).next

d = defaultdict(got(100))
b = ['a', 'b', 'c']
for k in b:
    d[k] += 1

>>> d.items()
[('a', 101), ('c', 101), ('b', 101), ('d', 101)]
```
