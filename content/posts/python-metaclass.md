---
title: "Python Metaclass"
date: 2018-03-23T13:13:09+08:00
lastmod: 2018-03-23T13:13:09+08:00
draft: false
keywords: ["python","metaclass"]
description: ""
tags: ["python","metaclass"]
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
关于python metaclass 也就是元类的一点体会。

<!--more-->
网络上说python metaclass的文章很多，感觉[这一篇](http://blog.jobbole.com/21351/)看了以后还是能比较清楚对元类有一个理解。下面谈谈自己的一些体会。

何为元类，其实也没那么神秘。python中所有的东西都是对象，方法是对象，变量是对象，类也是对象。一般我们在创建一个类的时候，会在代码里这么写

```python
class ClassA(object):
    pass
>>> ClassA
<class '__main__.ClassA'>
```
这就创建了一个类。由于类是一个对象，那么我们可以在代码运行时动态地创建一个类，不需要预先写任何代码。

```python
ClassA = type('ClassA', (), {})
>>> ClassA
<class '__main__.ClassA'>
```
这里我们用到了type，这样创建的一个类与之前我们在代码里写的时候创建的类一模一样。这就是类的动态创建。type是一个很特殊的方法。可以判断一个对象是属于什么类型，也可以用来动态创建类。那么既然类也是一个对象，那么这个对象是什么类型呢？
```python
class ClassA(object):
    pass
>>> type(ClassA)
<type 'type'>
```
可以验证，不管是通过代码里写的一个类还是用type创建的一个类，它的类型都是type!type创建类时需要三个参数，类名，继承列表，属性。于是我们甚至在不用写代码的情况下创建一个继承自ClassA并且自带一些属性的类
```python
class ClassA(object):
    pass

def printa(self):
    print self.a

ClassB = type('ClassB', (ClassA,), {'a': 1})
classb = ClassB()
>>> type(ClassB)
<type 'type'>
>>> ClassB.a
1
>>> classb.printa()
1
```
其实当我们写代码来声明一个类,python解释器在执行到这个类的相关代码时会收集到这个类的名字，继承列表和属性，然后用type来创建它。

type就是元类。元类就是可以创建类的类。python里type是所有类的元类。我们可以用类的__class__属性看到一个对象是哪个类的对象。

```python
>>> classb.__class__
<class '__main__.ClassB'>
>>> classb.__class__.__class__
<type 'type'>
```
那么除了type这个元类是不是还有别的元类呢，可以的。我们可以自己创建一个类作为另一个类的元类。这里列举一段[odoo](https://github.com/odoo/odoo)的代码来看看。在odoo代码openerp/cli包的__init__文件中先从command.py中引入了Command类，然后在server.py,shell.py中各自继承Command创建了子类。而command.py中的Command类定义了一个元类CommandType。

```python
commands = {}

class CommandType(type):
    def __init__(cls, name, bases, attrs):
        super(CommandType, cls).__init__(name, bases, attrs)
        name = getattr(cls, name, cls.__name__.lower())
        cls.name = name
        if name != 'command':
            commands[name] = cls

class Command(object):
    """Subclass this class to define new openerp subcommands """
    __metaclass__ = CommandType

    def run(self, args):
        pass

class Help(Command):
    """Display the list of available commands"""
    def run(self, args):
        print "Available commands:\n"
        names = commands.keys()
        padding = max([len(k) for k in names]) + 2
        for k in sorted(names):
            name = k.ljust(padding, ' ')
            doc = (commands[k].__doc__ or '').strip()
            print "    %s%s" % (name, doc)
        print "\nUse '%s <command> --help' for individual command help." % sys.argv[0].split(os.path.sep)[-1]

def main():

    # Default legacy command
    command = "server"

    if command in commands:
        o = commands[command]()
        o.run(args)

```
这里摘录了command.py中的部分代码，用来展示这里是如何使用元类的。可以看到Command类里定义了一个空run方法就没了。但由于它的元类是CommandType（注意所有自定义的元类都要继承自type），在解释器执行到Command类时，先收集代码中定义的Command类的属性，继承列表等，然后由于这里定义了元类，就不是直接调用type来创建一个了类了。而是会调用元类的__new__方法，来创建一个类，然后调用元类的__init__方法。

这里由于CommandType类没有定义__new__方法，会直接调用其父类也就是type的__new__方法创建一个类，然后传给__init__方法执行初始化。在初始化的时候传入了Command类的属性，装进了commands这个字典里。

稍后到了Help类，由于其继承自Command，也继承了它的元类属性，所以也会执行刚刚Command类创建时的一些操作，从而也将Help类的一些属性装进了commands里，server.py， shell.py中的继承自Command的类也是如此。

然后后面main方法在遍历commands字典，根据参数取出相应的类来执行其方法。这就实现了一种模式，任何想要拓展commands的行为，只需要继承Command类，然后定义run方法就行了。感觉很不错的思路。