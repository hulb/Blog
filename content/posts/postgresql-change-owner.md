---
title: "Postgresql Change Owner"
date: 2019-09-25T13:36:41+08:00
lastmod: 2019-09-25T13:36:41+08:00
draft: false
keywords: ["postgres","role","owner"]
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
之前在一次更改postgres数据库owner的时候遇到一些问题做过一点记录，摘录过来。
<!--more-->

更改数据库owner可以执行如下sql
```SQL
alter database dbname owner to new_owner;
```

但这仅仅只是改了数据库的owner，如果该数据库中原先已经存在数据表，视图，序列(sequence)，那他们的owner还是原来的owner，如果新的owner没有对这些object的访问权限，现在依然无法访问这些object。于是只能逐个改该数据库中object的权限，python示意代码如下：
```python
# 生成alter语句的sql,执行下面这些sql语句得到更新表，视图，序列owner的语句
update_sequence_owner_sql = "select 'ALTER TABLE ' || sequence_name || ' OWNER TO %s;' from information_schema.sequences where sequence_schema = 'public';" % new_user
update_view_owner_sql = "select 'ALTER TABLE ' || table_name || ' OWNER TO %s;' from information_schema.views where table_schema = 'public';" % new_user
update_table_owner_sql = "select 'ALTER TABLE ' || table_name || ' OWNER TO %s;' from information_schema.tables where table_schema = 'public';" % new_user

＃ 将语句加入到列表中，一次遍历执行，此处要注意一定要是先改table的owner再改sequence的owner,反过来执行会抱错
update_cmd = []
cr.execute(update_table_owner_sql)
update_cmd.extend(cr.fetchall())
cr.execute(update_sequence_owner_sql)
update_cmd.extend(cr.fetchall())
cr.execute(update_view_owner_sql)
update_cmd.extend(cr.fetchall())

for cmd in update_cmd:
    cr.execute(cmd[0])
```

后来找到有一种方式可以一劳永逸改所有的owner，就是权限赋予：
```SQL
reassign owned by old_role [, ….] to new_role
```
这句sql将old_role的权限全部赋予new_role；但这个语句有一个前提是执行这个语句的当前用户必须对old_role和new_role都具有权限。postgresql文档里说：
> REASSIGN OWNED requires privileges on both the source role(s) and the target role
