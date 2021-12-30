---
title: "Postgres 分组排序取第一个"
date: 2019-09-25T13:53:06+08:00
lastmod: 2019-09-25T13:53:06+08:00
draft: false
keywords: ["postgres", "window function","group by"]
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
之前遇到一个场景，需要写一个sql取一个表中的数据按某字段分组排序后每个组的第一个元素，这里记录下。
<!--more-->

表结构如下：
```
Table "public.commission_group_employee_rel"
       Column            |  Type   
----------------------------------+---------
 commission_group_id     | integer 
 employee_id             | integer 
```

还有一个表，记录的是commission_group_id的表
```
Table "public.commission_group"
          Column          |            Type            
--------------------------+--------------------------
 id                       | integer                     
 state                    | character varying    

write_date                | timestamp without time zone
```
现在要针对commission_group_employee_rel表中，按照employee_id来分组得到的每个employee_id对应的多个commission_group_id在commission_group中的write_date最大的一条。

这里用postgres的窗口函数可以来实现：

```SQL
select employee_id, group_id from (
    select gel.employee_id as employee_id, gel.commission_group_id as group_id, row_number() over(partition by gel.employee_id order by cg.write_date desc) as rnum
        from commission_group_employee_rel as gel
        left join
            commission_group as cg on cg.id=gel.commission_group_id
        where cg.state='done'
    ) as tmp
where rnum = 1 order by employee_id;
```
使用row_number() 这个窗口函数搭配over (partition by gel.employee order by cg.write_date desc)来按照employee_id分组后，每个小组按照commission_group_id对应的write_date desc排序后，算出来row_numer, 然后最外面用select 取row_number为1的，即是write_date最大的。

还有一种写法也可以达到目的，用到了select 语句的WINDOW 从句：
```SQL
select distinct gel.employee_id,first_value(gel.commission_group_id) over w
from
    commission_group_employee_rel as gel
left join
    commission_group as cg on cg.id=gel.commission_group_id
where
    cg.state='done'
WINDOW w as (partition by gel.employee_id order by cg.write_date desc ) order by gel.employee_id;
```
这里是用WINDOW 从句来分组和排序，然后用first_value这个窗口函数来取每个分组里的第一条数据，但是最终的结果会出现重复值，所以加了distinct。
