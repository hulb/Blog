---
title: "Python格式化输出"
date: 2018-03-14T12:57:57+08:00
lastmod: 2018-03-14T12:57:57+08:00
draft: false
keywords: [“python”, "format"]
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
python 格式化输出用的比较多的就是'%s'，用这个在文本中占位，然后后面给出这个位置的值。一旦位置可能发生变化就不好弄了，比如中英文翻译时，不同语境占位的顺序可能不固定，这时可以用format。以下举例常用的几种：

<!--more-->
- '%s, %s' % ('a', 'b') -> a, b
- '{}, {}'.format('a', 'b') -> a, b
- '{1}, {0}'.format('a', 'b') -> b, a
- '{name}, {age}'.format({'name': 'a', 'age': 'b'}) -> a, b
- '{name}, {age}'.format(name='a', age='b') -> a, b

关于format还有许多用法，可以看[官方文档](https://docs.python.org/2/library/string.html#format-string-syntax)。
