---
title: "Pgbadger Analyze"
date: 2018-03-30T17:10:33+08:00
lastmod: 2018-03-30T17:10:33+08:00
draft: false
keywords: ["pgbadger","log analyze","postgres"]
description: ""
tags: ["postgres"]
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
记录一下如何使用pgbadger分析postgres数据库日志。

<!--more-->
[pgbadger](https://github.com/dalibo/pgbadger)是一个Postgres 数据库的日志分析工具，可以根据日志出一些统计报表。

使用方法比较简单，从github下载源码在本地编译然后运行。
```shell
wget https://github.com/dalibo/pgbadger/archive/v9.2.tar.gz
tar xzf v9.2.tar.gz
cd pgbadger
perl Makefile.PL
make && sudo make install
```
安装完后执行pgbadger -V 可以显示版本好，-H可以查看帮助。

要分析postgres日志，首先要调整postgresql.conf配置文件，开启记录日志，pgbadger给了一个参考配置：
```
log_min_duration_statement = 0
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_error_verbosity = default
lc_messages='C'
```
除此之外还有比较重要的一个就是log_line_prefix 日志格式设置，一般postgresql.conf文件默认的log_destination='stderr'，按照pgbadger文档，对于'stderr'输出的日志，log_line_prefix必须至少包含：

```
log_line_prefix = '%t [%p]: [%l-1] '
```
还可以添加别的，如下：

```
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```
这个prefix一定要设置好，否则很可能pgbadger分析不出来什么东西。对于不是'stderr'的输出方式，可以参考pgbadger的README。

设置好后重启postgres就会按照新的配置生成日志文件了。然后执行命令：

```shell
pgbadger postgresql.log -o ~/Downloads/cc.html
```
![output](/out.png)
就会在Downloads目录下生成一个cc.html文件，用浏览器打开就会看到统计结果。
pgbadger还可以指定很多参数，这里就不一一展开，详细的可以看文档。