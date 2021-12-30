---
title: "Odoo Web Server初探"
date: 2018-09-09T16:23:58+08:00
lastmod: 2018-09-09T16:23:58+08:00
draft: false
keywords: ["odoo", "python", "web server", "wsgi"]
description: ""
tags: ["python", "web", "odoo", "wsgi"]
categories: ["python", "odoo"]
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
最近有机会面试了几位python web方向求职者，聊到关于django,flask，就少不了WSGI，过程中发现自己对用了很久的odoo框架web server的运行机制印象很模糊，不是很了解。遂花了点时间看了下实现。

<!--more-->

先说说WSGI。WSGI是一个接口，或者说协议。对于一个web应用来说，要做的事情不外乎"接收请求"，"处理请求"，"返回请求处理结果"这三个步骤，至于如何接收请求和如何返回请求响应，这对不同的web程序来说大致是相同的，即都必须要遵循http协议和相关的规范。比如http请求响应的格式，响应码等等。

如果有一个通用的模块可以处理这些比较底层的东西，让大部分开发人员能专注于实际业务和数据的处理，就能显著提高开发效率。WSGI就是定义了一个这样的接口，只要是实现了WSGI接口的python 程序，就能把比较底层的http请求响应格式之类的处理逻辑交给现成的功能模块去做，程序本身专注于处理业务就行了。

odoo的web server 自己实现了WSGI接口,也用到了werkzeug的ThreadedWSGIServer，服务启动的过程比较繁琐，不像flask那么直接了当。当然，这也是由于odoo自身实现了很多特性。接下来我们一点点来分解。

odoo的入口在openerp.cli.main() 这个main方法用得也有点tricky，先看看代码

```python
def main():
    args = sys.argv[1:]

    # The only shared option is '--addons-path=' needed to discover additional
    # commands from modules
    if len(args) > 1 and args[0].startswith('--addons-path=') and not args[1].startswith("-"):
        # parse only the addons-path, do not setup the logger...
        openerp.tools.config._parse_config([args[0]])
        args = args[1:]

    # Default legacy command
    command = "server"

    # TODO: find a way to properly discover addons subcommands without importing the world
    # Subcommand discovery
    if len(args) and not args[0].startswith("-"):
        logging.disable(logging.CRITICAL)
        for module in get_modules():
            if isdir(joinpath(get_module_path(module), 'cli')):
                __import__('openerp.addons.' + module)
        logging.disable(logging.NOTSET)
        command = args[0]
        args = args[1:]

    if command in commands:
        o = commands[command]()
        o.run(args)

```
一般启动odoo server的时候有多种方式，所需的一些参数我们可以直接在启动命令上带上，也可以写到配置文件里，然后启动的时候用"-c"指定配置文件就行了。我用得比较多的是启动的时候只指定配置文件，所以6-23行不会执行。程序执行到25行会发现,command默认值为'server'是会在commands里的，那么不禁要问commands的数据是怎么来的呢？可以看我之前写的一篇关于[python metaclass的博客](https://hulb.github.io/post/python-metaclass/)，里面介绍了commands数据初始化的过程用来举例说明python metaclass的用法。

接下来到27行后，程序会执行到openerp.cli.server.main()方法。至于前面需要用command去commands里找到一个实例来动态分发到这里的目的，是为了便于扩展odoo命令行执行的功能，使得其不仅可以用来run一个web服务，甚至还能用来将模块部署到远程或是启动一个交互式odoo服务以及创建一个标准结构的odoo模块等功能。要扩展更多功能只需将写好的文件放到openerp/cli目录下即可。

再来看到openerp.cli.server.main()方法，看看里面的逻辑。

```python
def main(args):
    check_root_user()
    openerp.tools.config.parse_config(args)
    check_postgres_user()
    report_configuration()

    config = openerp.tools.config

    # the default limit for CSV fields in the module is 128KiB, which is not
    # quite sufficient to import images to store in attachment. 500MiB is a
    # bit overkill, but better safe than sorry I guess
    csv.field_size_limit(500 * 1024 * 1024)

    if config["db_name"]:
        try:
            openerp.service.db._create_empty_database(config["db_name"])
        except openerp.service.db.DatabaseExists:
            pass

    if config["test_file"]:
        config["test_enable"] = True

    if config["translate_out"]:
        export_translation()
        sys.exit(0)

    if config["translate_in"]:
        import_translation()
        sys.exit(0)

    # This needs to be done now to ensure the use of the multiprocessing
    # signaling mecanism for registries loaded with -d
    if config['workers']:
        openerp.multi_process = True

    preload = []
    if config['db_name']:
        preload = config['db_name'].split(',')

    stop = config["stop_after_init"]

    setup_pid_file()
    rc = openerp.service.server.start(preload=preload, stop=stop)
    sys.exit(rc)
```
check_root_user()用来发出warning,建议不要用root用户运行odoo，以免造成一些安全性风险。check_postgres_user()用来禁止使用postgresql的默认postgres用户来连接数据库。setup_pid_file()检查了配置文件中的'pidfile'项，如果配置了，会将当前程序的进程id写入进去，其中用到了一个atexit.register(rm_pid_file, pid),这是注册了正常退出的回调，用来在退出时删除pidfile。

接下来我们重点关于43行。看到openerp.service.server.start()方法的逻辑。

```python
def start(preload=None, stop=False):
    """ Start the openerp http server and cron processor.
    """
    global server
    load_server_wide_modules()

    if openerp.evented:
        server = GeventServer(openerp.service.wsgi_server.application)
    elif config['workers']:
        server = PreforkServer(openerp.service.wsgi_server.application)
    else:
        server = ThreadedServer(openerp.service.wsgi_server.application)

    watcher = None
    if config['dev_mode']:
        if watchdog:
            watcher = FSWatcher()
            watcher.start()
        else:
            _logger.warning("'watchdog' module not installed. Code autoreload feature is disabled")
        server.app = DebuggedApplication(server.app, evalex=True)

    rc = server.run(preload, stop)

    # like the legend of the phoenix, all ends with beginnings
    if getattr(openerp, 'phoenix', False):
        if watcher:
            watcher.stop()
        _reexec()

    return rc if rc else 0
```
这里的stop是在前面从配置文件中读取stop_after_init配置项来的，一般都为False。我们主要看7-12行，根据配置文件和的不同，启动的server类型也不同。配置了"workers"的时候启动的是PreforkServer,当openerp.evented为True时，启动的是GeventServer,其他情况下启动ThreadServer,当然我们也可以在这里拓展出自己的Server。我们先来看看ThreadServer。

第12行将openerp.service.wsgi_server.application作为参数传入了ThreadServer, 它的就是odoo自己实现的WSGI接口，定义是这样的：

```python
def application_unproxied(environ, start_response):
    """ WSGI entry point."""
    # cleanup db/uid trackers - they're set at HTTP dispatch in
    # web.session.OpenERPSession.send() and at RPC dispatch in
    # openerp.service.web_services.objects_proxy.dispatch().
    # /!\ The cleanup cannot be done at the end of this `application`
    # method because werkzeug still produces relevant logging afterwards 
    if hasattr(threading.current_thread(), 'uid'):
        del threading.current_thread().uid
    if hasattr(threading.current_thread(), 'dbname'):
        del threading.current_thread().dbname

    with openerp.api.Environment.manage():
        # Try all handlers until one returns some result (i.e. not None).
        for handler in [wsgi_xmlrpc, openerp.http.root]:
            result = handler(environ, start_response)
            if result is None:
                continue
            return result

    # We never returned from the loop.
    response = 'No handler found.\n'
    start_response('404 Not Found', [('Content-Type', 'text/plain'), ('Content-Length', str(len(response)))])
    return [response]

def application(environ, start_response):
    if config['proxy_mode'] and 'HTTP_X_FORWARDED_HOST' in environ:
        return werkzeug.contrib.fixers.ProxyFix(application_unproxied)(environ, start_response)
    else:
        return application_unproxied(environ, start_response)
```

在27行判断了当前server是否处于代理服务器后面，如果是的话使用werkzeug.contrib.fixers.ProxyFix做一些转换，例如将http header里的远程地址转换一下，保证后面能拿到请求的真实来源等。整个WSGI接口的核心还是application_unproxied(env, start_response)方法。13-19行，在with的包裹下，分别用wsgi_xmlrpc和openerp.http.root两个handler去处理请求，result不为None的结果就直接返回。在实际程序执行的时候，一般只会用到openerp.http.root。

上面介绍了odoo自己实现的WSGI接口，那么这个接口是如何被调用的呢？回到openerp.service.server.start()方法。最终会调到ThreadServer.run(), 里面是这么实现的：

```python
def run(self, preload=None, stop=False):
        """ Start the http server and the cron thread then wait for a signal.

        The first SIGINT or SIGTERM signal will initiate a graceful shutdown while
        a second one if any will force an immediate exit.
        """
        self.start(stop=stop)

        rc = preload_registries(preload)

        if stop:
            self.stop()
            return rc

        # Wait for a first signal to be handled. (time.sleep will be interrupted
        # by the signal handler.) The try/except is for the win32 case.
        try:
            while self.quit_signals_received == 0:
                time.sleep(60)
        except KeyboardInterrupt:
            pass

        self.stop()
```

preload_registries()会预先加载再配置文件里配置的db_name数据库中的模块和模型。主要看第一句self.start()的逻辑。后面在stop为False的情况下程序会进入一个while循环，各60s判断self.quit_signals_received来决定是否让程序退出。这是一种优雅的退出方式，即留下一个标识检查，如果需要退出，只需在程序执行逻辑里改这个标识就行。我们来看看self.start()

```python
def start(self, stop=False):
        _logger.debug("Setting signal handlers")
        if os.name == 'posix':
            signal.signal(signal.SIGINT, self.signal_handler)
            signal.signal(signal.SIGTERM, self.signal_handler)
            signal.signal(signal.SIGCHLD, self.signal_handler)
            signal.signal(signal.SIGHUP, self.signal_handler)
            signal.signal(signal.SIGQUIT, dumpstacks)
            signal.signal(signal.SIGUSR1, log_ormcache_stats)
        elif os.name == 'nt':
            import win32api
            win32api.SetConsoleCtrlHandler(lambda sig: self.signal_handler(sig, None), 1)

        test_mode = config['test_enable'] or config['test_file']
        if test_mode or (config['xmlrpc'] and not stop):
            # some tests need the http deamon to be available...
            self.http_spawn()

        if not stop:
            # only relevant if we are not in "--stop-after-init" mode
            self.cron_spawn()
```

这里先是针对不同的操作系统，写了不同的信号响应逻辑，后续根据配置一次调用了self.http_spawn()和self.cron_spawn()。cron_spawn()用来启动定时任务，http_spawn()用来启动http服务，我们重点关注http_spawn()。

```python
def http_thread(self):
        def app(e, s):
            return self.app(e, s)
        self.httpd = ThreadedWSGIServerReloadable(self.interface, self.port, app)
        self.httpd.serve_forever()

def http_spawn(self):
        t = threading.Thread(target=self.http_thread, name="openerp.service.httpd")
        t.setDaemon(True)
        t.start()
        _logger.info('HTTP service (werkzeug) running on %s:%s', self.interface, self.port)

```

这里新开了一个线程来执行self.http_thread，而http_thread()则创建了一个ThreadedWSGIServerReloadable对象，传入的app即是前面说过的openerp.service.wsgi_server.application，通过代码可以知道ThreadedWSGIServerReloadable源于werkzeug.serving.ThreadedWSGIServer。接着调用server_forever()启动服务，监听请求。当请求来临时，根据WSGI协议，openerp.service.wsgi_server.application方法会被调用。

大致情况就是这样。当然这只是ThreadedServer的逻辑，还有另外的PreforkServer和GeventServer虽然大同小异，但也有一些区别，后续有空会陆续介绍一下。