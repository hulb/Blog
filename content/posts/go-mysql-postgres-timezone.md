---
title: "Go使用mysql和Postgres的时区问题"
date: 2022-04-24T00:04:16+08:00
draft: false
keywords: ["timezone", "mysql", "postgres", "timestamp", "golang"]
description: ""
tags: ["golang", "mysql", "postgres", "timezone"]
categories: ["database", "golang"]
author: "hulb"
---
使用mysql或postgres数据库来处理时间类型的数据时，经常会要处理时区的问题。对于go开发而言，这两个数据库对时区的处理并不一样，这里做一个简单总结。

#### myql 时区配置
mysql会根据当前时区对timestamp类型的写入和读取进行处理。mysql维护了三种时区，即系统时区(对应变量`system_time_zone`)，当前时区(对应变量`time_zone`)，以及会话时区。（https://dev.mysql.com/doc/refman/8.0/en/time-zone-support.html）
- 系统时区：当mysql server启动时，会获取当前操作系统时区，将该时区设置为 `system_time_zone` 系统变量；如果要明确设置时区可以通过设置`TZ`环境变量之后再启动mysqld; 如果使用mysqld_safe启动服务，可以通过`--timezone`参数设置
- 当前时区：全局系统变量`time_zone`指明当前mysql服务端所用的时区。初始值是`SYSTEM`,表明使用操作系统时区。全局服务端时区可以在启动服务时通过命令行参数`--default-time-zone`指定默认值; 如果当前用户具有`SYSTEM_VARIABLES_ADMIN`权限，也可以通过`SET GLOBAL time_zone = timezone`语句来设置当前全局时区。
- 会话时区：每个client连接会话有它自己的时区设置，默认取全局时区，也可以通过`SET time_zone = timezone`语句来设置。

#### 查询当前mysql时区配置
通过一下语句
```
SELECT @@GLOBAL.time_zone, @@SESSION.time_zone;
```
可以看到当前的全局时区和会话时区，默认情况下会得到：
```
mysql> SELECT @@GLOBAL.time_zone, @@SESSION.time_zone;
+--------------------+---------------------+
| @@GLOBAL.time_zone | @@SESSION.time_zone |
+--------------------+---------------------+
| SYSTEM             | SYSTEM              |
+--------------------+---------------------+

```

通过查看timezone相关mysql系统变量可以看到当前系统时区和当前时区。
```
show variables like '%time_zone%';
```
默认情况下会得到：
```
mysql> show variables like '%time_zone%';
+------------------+--------+
| Variable_name    | Value  |
+------------------+--------+
| system_time_zone | UTC    |
| time_zone        | SYSTEM |
+------------------+--------+
```

#### timestamp类型
mysql 的timestamp类型支持是不带时区的。mysql来处理写入时会将对写入数据做时区转换，转成UTC来存储；读出时会将UTC存储的数据转为当前时区。也就是说mysql中存储的永远会是UTC时区，而不管当前mysql使用的是什么时区。
例如
```
mysql> set time_zone='UTC'; -- 设置当前会话时区为UTC
mysql> insert into test(t) values('2022-04-23 21:39:00'); -- 插入一条时间数据
mysql> select * from test; -- 查询结果会显示原样，因为读出的时候当前时区也是UTC
+---------------------+
| t                   |
+---------------------+
| 2022-04-23 21:39:00 |
+---------------------+

mysql> set time_zone='Asia/Shanghai'; -- 调整当前时区
mysql> select * from test; -- 查询结果会将存储的UTC时区转为当前时区
+---------------------+
| t                   |
+---------------------+
| 2022-04-24 05:39:00 |
+---------------------+

mysql> insert into test(t) values('2022-04-23 22:39:00'); -- 当前时区下再插入一条时间数据，但存储的是由当前时区转换为UTC时区之后的值
mysql> select * from test; -- 查询结果会将存储的UTC时区转为当前时区
+---------------------+
| t                   |
+---------------------+
| 2022-04-24 05:39:00 |
| 2022-04-23 22:39:00 |
+---------------------+
```

#### golang 中的表现
golang中广泛使用的mysql驱动是 github.com/go-sql-driver/mysql。使用该驱动从mysql数据库中读取timestamp类型数据时，如果需要直接映射到`time.Time`类型，需要在连接参数中增加`parseTime=true`：
```
db, err := sqlx.Open("mysql", "root:password@/test?parseTime=true")
```
此时不管mysql服务端使用的什么时区，golang中读到的是mysql在当前服务端时区下的时间类型值，但映射到golang中time.Time类型字段，其location会是UTC。
例如，接着上面的例子，我们调整mysql全局时区：
```
mysql> set GLOBAL time_zone='Asia/Shanghai'; -- 设置全局时区
mysql> select * from test; -- 查询记录
mysql> select * from test; -- 查询结果会将存储的UTC时区转为当前时区
+---------------------+
| t                   |
+---------------------+
| 2022-04-24 05:39:00 |
| 2022-04-23 22:39:00 |
+---------------------+
```
通过golang查询：
```
db, err := sqlx.Open("mysql", "root:password@/test?parseTime=true")
if err != nil {
    panic(err)
}
defer db.Close()


var res []struct {
    T *time.Time `db:"t"`
}
if err := db.Select(&res, "select * from test"); err != nil {
    panic(err)
}

/*
2022-04-24 05:39:00 +0000 UTC
2022-04-23 22:39:00 +0000 UTC
/*
for _, r := range res {
    fmt.Println(r.T.String())
}
```
这里实际上golang里收到的值已经是mysql根据当前时区转换过之后的了，但是由于值上面是不带时区信息的，所以驱动在映射的时候变成了UTC时区。如果需要的到的time.Time类型字段时区符合预期，需要在连接参数中增加`loc`:
```
db, err := sqlx.Open("mysql", "root:password@/test?parseTime=true&loc=Asia%2FShanghai")
```
也就是说，对mysql而言，不管是读出还是写入，timestamp类型的值都不带时区信息，一切以mysql当前时区为准。
写入时，驱动会将time.Time根据连接参数指定的时区做一次转换，写入到mysql中，而mysql在存储时会将该数据转为UTC时区的数据来存储。
例如：
```
// 连接参数中未指定loc，默认为UTC，此时mysql时区为Asia/Shanghai
db, err := sqlx.Open("mysql", "root:password@/test?parseTime=true")
if err != nil {
    panic(err)
}
defer db.Close()

now := time.Now()
fmt.Println(now) // 2022-04-23 22:00:17.174757012 +0800 CST m=+1.426361215
_, err = db.Exec("insert into test(t) values (?)", now)
if err != nil {
    panic(err)
}
```
在mysql中查询到
```
mysql> SELECT @@GLOBAL.time_zone, @@SESSION.time_zone;
+--------------------+---------------------+
| @@GLOBAL.time_zone | @@SESSION.time_zone |
+--------------------+---------------------+
| Asia/Shanghai      | Asia/Shanghai       |
+--------------------+---------------------+

mysql> select * from test; -- 查询结果会将存储的UTC时区转为当前时区(Asia/Shanghai)
+---------------------+
| t                   |
+---------------------+
| 2022-04-23 14:00:17 |
+---------------------+
```

在通过golang读取出来会的到`2022-04-23 14:00:17 +0000 UTC`的time.Time类型。因为我们没有在连接参数中指定`loc`，拿到的时区是UTC, 实际这个值应该是`Asia/Shanghai`时区。所以最好连接参数中`loc`要保持和mysql时区一致，为了避免混乱建议都使用UTC.


### Postgres 时区
Postgres中有timestamp，和timestamptz均可以表示时间戳。其中timstamp是符合SQL标准的，实际含义是timestamp without timezone;而timestamptz是Postgres的对SQL标准的扩展，实际含义是timestamp with time zone.
简而言之就是前者类型的值中不带时区，而后者类型的值中带时区。

#### Postgres 时区配置和查询
postgres 时区可以通过配置文件postgres.conf来设置，默认为当前操作系统时区。Postgres还支持通过SQL标准的`SET time zone 'Asia/Shanghai'` 来设置，这时设置的是会话时区。
通过`show timezone`或者`select current_setting('TIMEZONE');`可以查询当前时区。

#### Posgres timestamp和timestamptz的读写
对于timestamp类型，Postgres会将数据原封不动地存入或读出，不管当前timezone是什么，你存入或读出的值都一样。而对于timestamptz， Postgres会将写入的当前时区的值转为UTC时区存入，读出时转为当前时区。
例如：
```
-- 当前时区为UTC, 插入一条UTC+8的时间
insert into test(t2) values('2022-04-23 19:52:49.858478+08');
-- 查询
test1=# select * from test;
              t2               
-------------------------------
 2022-04-23 11:52:49.858478+00

-- 调整当前会话时区
test1=# set time zone 'Asia/Shanghai';
-- 查询
test1=# select * from test;
              t2               
-------------------------------
 2022-04-23 19:52:49.858478+08

```
#### golang中的表现
golang中使用广泛的postgres驱动是github.com/lib/pq。使用这个库时，对于timestamp类型，写入时，time.Time类型的时区会被忽略，读出是得到的会是一个UTC时区的time.Time类型值。
而对于timestamptz类型，写入到Postgres一定是与golang中time.Time类型值的时区对应的UTC时区值。驱动提供了一个连接参数`TimeZone`来控制读出映射到golang的time.Time类型的时区。
读出时，如果连接参数未设置`TimeZone`, 拿到的time.Time时区与postgres当前时区一致，如果设置了`TimeZone`则与设置的时区一致。注意，为设置`TimeZone`和设置`TimeZone=UTC`结果是不一样的。
例如：
```
-- postgres.conf中设置的timezone是Asia/Shanghai
test1=# select * from test;
             t              |              t2               
----------------------------+-------------------------------
 2022-04-23 23:20:44.934052 | 2022-04-23 23:20:44.934052+08
(1 row)

test1=# select current_setting('TIMEZONE');
 current_setting 
-----------------
 Asia/Shanghai

```
通过以下代码查询：
```
db, err := sqlx.Open("postgres", "user=postgres password=password database=test1 sslmode=disable")
if err != nil {
    panic(err)
}
defer db.Close()

var res []struct {
    T  *time.Time `db:"t"`
    T2 *time.Time `db:"t2"`
}
if err := db.Select(&res, "select * from test"); err != nil {
    panic(err)
}

for _, r := range res {
    fmt.Println(r.T.String())
    fmt.Println(r.T2.String())
}
```
输出
```
2022-04-23 23:20:44.934052 +0000 +0000
2022-04-23 23:20:44.934052 +0800 CST
```
设置`TimeZone`参数后
```
db, err := sqlx.Open("postgres", "user=postgres password=password database=test1 sslmode=disable TimeZone=UTC")
```
输出：
```
2022-04-23 23:20:44.934052 +0000 +0000
2022-04-23 15:20:44.934052 +0000 UTC
```

为了避免混乱应该显式设置`TimeZone`参数，同时建议postgres和连接参数均使用UTC时区。