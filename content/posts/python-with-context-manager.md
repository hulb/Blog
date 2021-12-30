---
title: "对python上下文管理器的认识"
date: 2018-06-11T15:59:40+08:00
lastmod: 2018-06-11T15:59:40+08:00
draft: false
keywords: ["python", "with", "contextmanager"]
description: ""
tags: ["python", "contextmanager"]
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
odoo框架给我们单元测试提供了BaseCase.assertRaises之类的方法去assert异常类型，一直在使用从未探究过其实现。今天突然来了兴趣，仔细看看收获不少。
<!--more-->

我们在断言一种异常时，经常这样用:
```python
with self.assertRaises(ValidateError):
    do_something()
```

这里如果do_something方法执行抛出异常，而异常类型为ValidateError,就会被识别到，从而断言为True。这里是如何捕获到这个异常，进而实现断言的呢？
这里就要提到["with"这个关键字和python提供的上下文管理器](https://docs.python.org/2.5/whatsnew/pep-343.html)。

关于with的解释网络上很多，简单来说就是实现了____enter____和____exit____方法的对象就叫做“上下文管理器(context manager)”，可以用with，举个数据库连接的例子：
```python
class Connnection(object):
    def __enter__(self):
        return self

    def __exit__(self, err_type, value, traceback):
        self.close()

with Connnection() as con:
    do_something()
```

可以看到有了with就不用繁琐地写try/finaly了。执行的顺序是先执行Connection()得到一个实例，然后执行Connection类的____enter____返回这个实例，由于存在as，这个实例会被赋值给con，然后执行do_something()，完成后最后执行Connection类的____exit____方法。同时可以看到____exit____方法有三个参数，这是因为当do_something执行抛出异常的时候，如果do_something后面还有代码，就不会执行了，而会直接进入到____exit____，其中err_type是异常的类型，value是异常具体对象，traceback是异常时的堆栈，对于接下来的处理，如果____exit____返回False则异常会继续往上抛，如果返回True则不在继续抛。这就是一个catch机制嘛，难怪可以替代try啦。

在看看BaseCase.assertRaises的实现:

```python
@contextmanager
def _assertRaises(self, exception):
    """ Context manager that clears the environment upon failure. """
    with super(BaseCase, self).assertRaises(exception) as cm:
        with self.env.clear_upon_failure():
            yield cm
```

这里出现了一个contextmanager装饰器。讲python的上下文管理器，contextlib.contextmanager是一定会被提到的。它作用到一个generator上使得实现上下文管理器的过程更简化了。被contextlib.contextmanager装饰的generator，yield之前的部分作为____enter____方法，yield之后的部分作为____exit____方法。执行到yield时就执行with包围的do_something的内容。但需要注意的是这个generator只能输出一个值，如果是多个值就不能用contextlib.contextmanager。那么之前的数据库连接的例子就可以改为:

```python
class Connection(object):
    pass

def get_con():
    con = Connection()
    yield con
    con.close()

with get_con() as con:
    do_something()
```

这样就不必每个想要用with的对象都要实现一遍____enter____和____exit____。接下来看看让我产生兴趣的一个地方，关于with的嵌套。我把异常断言用到的主要代码列出来:

```python
with self.assertRaises(ValidateError): # 1.由于assertRaises是一个generator，这里获取到这个generator对象后就会进入这个对象的__enter__方法，就是执行assertRaises方法yield之前的部分
    do_something() # 4.
...

@contextmanager
def _assertRaises(self, exception):
    """ Context manager that clears the environment upon failure. """
    with super(BaseCase, self).assertRaises(exception) as cm:   #  2.执行到这里的时候可以看到super(BaseCase, self).assertRaises(exception)返回的是一个_AssertRaisesContext对象，它实现了__enter__和__exit__方法
        with self.env.clear_upon_failure(): # 3.执行到这里的时候由于clear_upon_failure方法是一个generator，所以会执行yield之前的部分(啥也没有)，然后到8, 然后完成3这一层with的"__enter__"，执行下一句5直接是yield，那么对于_assertRaises来说，其yield方法已经执行完了，那么回到最开始的with，开始执行do_something方法4
            yield cm    # 5.
...

class _AssertRaisesContext(object):
    """A context manager used to implement TestCase.assertRaises* methods."""

    def __init__(self, expected, test_case, expected_regexp=None):
        self.expected = expected
        self.failureException = test_case.failureException
        self.expected_regexp = expected_regexp

    def __enter__(self):    # 6.
        return self

    def __exit__(self, exc_type, exc_value, tb): # 7.这里是异常类型断言的核心逻辑，通过在__exit__里判断异常类型与expected是否一致来决定是返回True还是False来决定异常断言的结果
        if exc_type is None:
            try:
                exc_name = self.expected.__name__
            except AttributeError:
                exc_name = str(self.expected)
            raise self.failureException(
                "{0} not raised".format(exc_name))
        if not issubclass(exc_type, self.expected):
            # let unexpected exceptions pass through
            return False
        self.exception = exc_value # store for later retrieval
        if self.expected_regexp is None:
            return True

        expected_regexp = self.expected_regexp
        if not expected_regexp.search(str(exc_value)):
            raise self.failureException('"%s" does not match "%s"' %
                     (expected_regexp.pattern, str(exc_value)))
        return True
...

@contextmanager
def clear_upon_failure(self):
    """ Context manager that clears the environments (caches and fields to
        recompute) upon exception.
    """
    try:
        yield   #  8.
    except Exception:
        self.clear()    #9.
        raise   # 10.
```

这里要注意，如果是实现了____enter____和____exit____的对象，当do_something执行异常后会进入____exit____，但对于用contextlib.contextmanager装饰的generator来说，do_something异常之后并不会再执行yield之后的内容，所以在4执行异常的时候，异常被3这一层with机制捕获，接着进入clear_upon_failure的异常捕获逻辑，执行9，做一个资源清理，然后10将异常往外抛被2这一层的with机制捕获进入到7这个____exit____逻辑，在这里通过对比异常类型，如果这不是期待的类型，则抛出“不匹配”的异常，如果是期待的类型则返回True，异常不继续往上抛。

这就是这个异常断言的实现机制，可以这个过程中with的嵌套分两种：

一种是对于1来说，assertRaises方法得到的是一个generator，所以它的____enter____是整个assertRaises方法yield之前的内容，可以理解为一直执行到assertRaises方法yield了才算完，这里在某些情况下可以不仅仅只执行到5。

而且如果4执行没有异常，这时候就要执行assertRaises方法yield后面的内容，而5这里yield后没有东西了，但并不意味着assertRaises方法的yield后面的内容执行完了，还需要执行完3这一层with的"____exit____"以及2这一层的"____exit____"，而执行3这一层的"____exit____"时，由于clear_upon_failure是一个generator,会要执行clear_upon_failure方法yield后面的内容，也是什么都没有，于是3这一层的with执行完了；2这层with也是一样会执行到7这里的____exit____，然后没有异常所以返回False，至此整个assertRaises方法执行完了，也是1这个with的"____exit____"过程执行完了。整个过程就完了。

另一种其实在第一种的过程中包含了。在执行1的"____enter____"过程的时候，进入到assertRaises，现执行外层with的"____enter____"过程，然后执行外层with的"do_something"过程时执行到内层with的"____enter____"过程。执行完内层的"do_something"过程后先执行内层with的"____exit____"过程。
