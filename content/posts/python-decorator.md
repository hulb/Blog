---
title: "说说Python Decorator"
date: 2018-03-17T11:12:24+08:00
lastmod: 2018-07-17T07:50:00+08:00
draft: false
keywords: ["python","decorator"]
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
python装饰器这个东西用得好能给代码结构带来很大的方便，之前一直是用到就翻翻资料，今天做一个总结。

<!--more-->
在python中任何东西都是一个对象，包括function。这是装饰器的基础。因为function是一个对象，所以我们可以把一个function当作参数，或者把function当作返回值。于是我们可以在一个function中返回另一个function,借此实现一些特别的功能。比如下面：

```python
def printA():
    print 'a'

def printFuncName(func):
    def wrapper():
        print 'func {} called!'.format(func.__name__)
        func()

    return wrapper

>>>printA()
a
>>>printA = printFuncName(printA)
>>>printA()
func printA called!
a
```
这就实现了在调用printA之前打印日志的功能。当然功能不仅限于打印日志，通过这种方式，我们给printA附加了一些原本不属于它的一些功能，这就叫“装饰”。而python给这种写法提供了一个语法糖(快捷调用方式)"@":
```python
def printFuncName(func):
    def wrapper():
        print 'func {} called!'.format(func.__name__)
        func()

    return wrapper

@printFuncName
def printA():
    print 'a'

>>>printA()
func printA called!
a
```
使用@printFuncName跟printA = printFuncName(printA)的效果是一样的。以上就是装饰器的一个简单例子，这里例举的printA是一个没有参数的方法，如果是一个有参数的方法，又该怎么写呢？

```python
def printFuncName(func):
    def wrapper(*args, **xargs):
        print 'func {} called!'.format(func.__name__)
        func(*args, **xargs)

    return wrapper

@printFuncName
def printA(value):
    print value

>>>printA('a')
func printA called!
a
```

给wrapper加上args和xargs就行了，因为在Python执行到@printFuncName这一行的时候返回的时机是wrapper方法。
到这里，就会有一个问题：由于使用了装饰器，那么实际的printA指向的方法对象已经由原来的方法变成了wrapper，功能是都一样，但是方法的name和document变了。

```python
def printFuncName(func):
    def wrapper(*args, **xargs):
        """wrapper"""
        print 'func {} called!'.format(func.__name__)
        func(*args, **xargs)

    return wrapper

@printFuncName
def printA(value):
    """printA"""
    print value

>>> printA.__doc__
'wrapper'
>>> printA.__name__
'wrapper'
```
要解决这个问题，需要用到[functools的wraps](https://docs.python.org/2/library/functools.html#functools.wraps)方法。

```python
from functools import wraps
def printFuncName(func):
    @wraps(func)
    def wrapper(*args, **xargs):
        """wrapper"""
        print 'func {} called!'.format(func.__name__)
        func(*args, **xargs)

    return wrapper

@printFuncName
def printA(value):
    """printA"""
    print value

>>> printA.__doc__
'printA'
>>> printA.__name__
'printA'
```
functools.wraps帮我们将printA原始的name和document复制给了wrapper，解决了上面的问题，但其实还有一个问题，只是这个问题对一般功能的实现不会有影响，但对于需要获取一个被"装饰"的方法的参数时，就会出现问题，这就需要decorator这个python库来解决，我们最后说这个问题。

接下来我们对上面的装饰器再进一步：在装饰器上增加参数。
例如我们在日志时需要用一个参数"level"来标志日志等级，这又如何实现呢？


```python
from functools import wraps
def printFunc(level='name'):
    def _decorate(func):
        @wraps(func)
        def wrapper(*args, **xargs):
            """wrapper"""
            if level=='name':
                print 'func {} called!'.format(func.__name__)
            else:
                print 'func called!'
            
            func(*args, **xargs)

        return wrapper
    
    return _decorate

@printFunc(leval='args')
def printA(value):
    """printA"""
    print value

>>> printA('b')
func called!
b
>>> printA.__name__
'printA'
>>> printA.__doc__
'printA'
```
就是在原来的装饰器方法外面再套一层，这一层返回的其实是一个装饰器，在执行到@printFunc(level='args')时最外层方法被执行，返回一个装饰器，至于在wrapper里用到level参数则是利用了python闭包的特性。

除了一个方法可以作为一个装饰器之外，类也可以作为装饰器，我们用类作为装饰器来改写一些上面的代码：


```python
from functools import wraps
class printFuncName(object):
    def __init__(self):
        pass
    def __call__(self, func)
        @wraps(func)
        def wrapper(*args, **xargs):
            """wrapper"""
            print 'func {} called!'.format(func.__name__)
            func(*args, **xargs)

        return wrapper

@printFuncName()
def printA(value):
    """printA"""
    print value

>>> printA('A')
func printA called!
A
>>> printA.__name__
'printA'
>>> printA.__doc__
'printA'
```
用类作为装饰器就是利用类的__call__方法，来返回一个wrapper。上面的代码是一个不带参数的装饰器，一个带参数的装饰器这样写：

```python
from functools import wraps
class printFuncName(object):
    def __init__(self, level='name'):
        self.level = level
    def __call__(self, func)
        @wraps(func)
        def wrapper(*args, **xargs):
            """wrapper"""
            if self.level == 'name':
                print 'func {} called!'.format(func.__name__)
            else:
                print 'func called!'
            func(*args, **xargs)

        return wrapper

@printFuncName()
def printA(value):
    """printA"""
    print value

>>> printA('A')
func printA called!
A
>>> printA.__name__
'printA'
>>> printA.__doc__
'printA'
```
就是在类的__int__方法中接收装饰器参数，然后再__call__方法中使用。

最后再说之前遗留的一个问题：尽管我们用了functools.wraps后经过装饰器装饰的方法与原方法再name和document上都与原来一样了，但是它的参数列表还是不一样的，比如下面的例子：

```python
from functools import wraps
def printFuncName(func):
    @wraps(func)
    def wrapper(*args, **xargs):
        """wrapper"""
        print 'func {} called!'.format(func.__name__)
        func(*args, **xargs)

    return wrapper

def printA(value):
    """printA"""
    print value

>>> inspect.getargspec(printA)
ArgSpec(args=['value'], varargs=None, keywords=None, defaults=None)

@printFuncName
def printA(value):
    """printA"""
    print value
>>> printA.__doc__
'printA'
>>> printA.__name__
'printA'
>>> getargspec(printA)
ArgSpec(args=[], varargs='args', keywords='xargs', defaults=None)
```
可以看到，这里被装饰器装饰过后，方法的参数列表发生了变化。在需要用到方法的参数列表做一些判断的时候，这里就要小心了；如果一个方法是经过装饰器装饰过的，那么你取到的参数列表可能有问题。那么如何解决呢？这就需要用到python的[decorator库](http://decorator.readthedocs.io/en/latest/tests.documentation.html)。

接着来看decorator库。decorate库主要是为了解决在使用装饰器的过程中，方法签名发生变化的问题。一个很典型的例子是在odoo的openerp/api.py中，许多装饰器例如@api.one, @api.model, @api.multi等都会先获取一些被装饰方法的参数列表，以此来做一层api转换。

最近在做一些性能优化的工作，要加一段profile装饰器的代码，来给需要的方法做性能评估。比较好的方式是加到openerp/api.py中，这时就遇到上面说的问题，即如何在使用装饰器的时候保证被装饰方法的签名，这样在使用多个装饰器时不受影响。

直接看代码：

```python
from decorator import decorator
from pyinstrument import Profiler
from cProfile import Profile
def do_profile(profiler_type='pyinstrument', save=False):
    def _decorate(func):
            def wrapper(func, *args, **xargs):
                if profiler_type == 'pyinstrument':
                    profiler = Profiler()
                    profiler.start()
                elif profiler_type == 'cprofile':
                    profiler = Profile()
                    profiler.enable()
                res = func(*args, **xargs)
                if profiler_type == 'pyinstrument':
                    profiler.stop()
                    print(profiler.output_text(unicode=True, color=True))

                elif profiler_type == 'cprofile':
                    profiler.disable()
                    profiler.print_stats(sort=2)

                return res

            return decorator(wrapper, func)

        return _decorate

```

这里用到带参数的装饰器，可以在使用的时候选择profiler。顺带提一下,cProfile对程序执行的效率影响比较大，pyinstrument这个profiler对程序执行影响较小，其结果展示也比较直观。

最核心的就是用到了decorator.decorator。它提供了一种非常简单的方式，将一个装饰器包装为一个保留被装饰方法签名的装饰器。一般在_decorate方法返回时，会直接return wrapper，这时这个wrapper与被装饰方法func相比，就丢失了func原本的方法签名。这是使用decorator(wrapper, func)就能轻松解决。注意，wrapper方法的定义需要做微调，即第一个参数为被装饰的func。