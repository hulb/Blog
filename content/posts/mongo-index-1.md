---
title: "Mongodb 索引介绍（一）"
date: 2022-02-27T22:33:16+08:00
draft: false
keywords: ["mongodb", "index"]
description: ""
tags: ["mongodb", "index"]
categories: ["database", "mongodb"]
author: "hulb"
---

index作为数据库不可缺少的一部分可以极大加速数据查询，这里记录下Mongodb中的index类型和一些要点。以下内容基于[Mongodb 4.0文档](https://docs.mongodb.com/v4.0/indexes/).

### 索引创建
Mongodb支持通过`createIndex`函数创建索引, 创建时可以指定一些options:
- background: 
    默认false, 是否后台创建；默认情况下在建立索引期间，Mongodb为了更快速地构建更有效的索引会阻止所有对集合的读写访问；后台创建索引构建速度较慢，且结构稍不理想，但允许在构建过程中对数据库进行读写
- unique：
    默认false, 是否唯一；如果唯一，将不能插入或更新与已经存在的文档中索引字段值相同的文档。
- name：
    索引名称，如不指定Mongodb默认按照索引字段和排序方向生成索引名称
- partialFilterExpression：
    部分过滤表达式，当指定部分过滤表达式时，Mongodb将只对满足过滤条件的文档字段进行索引。
- expireAfterSeconds：
    设置TTL index的过期时间
- storageEngine:
    存储引擎，可以通过这个参数执行存储引擎，4.0版本Mongodb支持两种存储引擎：WiredTiger(默认), 内存存储引擎

除了`createIndex`外，还可以通过`createIndexes`批量创建索引。创建示例：
```
db.collection.createIndex( { "user_id": 1} )
```
字段的值1表示升序，-1表示降序。


### Mongodb index类型
mongodb 有以下几种index类型：
- 单字段索引(single field index)
    - 过期索引
- 地理空间索引(Geospatial Index)
- 哈希索引(hash index)
- 复合索引(compound index)
- 多值索引(multikey index)
- 文本索引(text index)

这里暂时把地理空间索引和文本索引放一边，主要看看复合索引，多值索引和过期索引。

#### 单字段索引
single field index索引中_id index是Mongodb自动创建的一个特殊索引，每个文档都会有一个_id字段，Mongodb会自动对这个字段进行索引。用户可以创建自己的单字段索引，索引顺序无关紧要，因为Mongodb可以从任何排序遍历索引。

##### 过期索引
TTL index是特殊的单字段索引，Mongodb会自动根据TTL设置删除过期的文档，在创建时需要指定一个时间类型字段或一个包含时间类型值的数组字段,然后通过options指定过期时间。例如：
```
db.eventlog.createIndex( { "lastModifiedDate": 1 }, { expireAfterSeconds: 3600 } )
```
这样设置以后，在lastModifiedDate+3600s时间段后Mongodb将会删除这些过期的文档。删除操作是通过Mongodb的后台线程执行的，当TTL 线程启动后可以通过`db.currentOp()`或[数据库profiler](https://docs.mongodb.com/v4.0/tutorial/manage-the-database-profiler/#database-profiler)查看。

一旦Mongodb在mongodb的主要节点上完成索引创建即会开始执行过期文档的清理，但是TTL index并不能保证过期时间一到，过期的文档会立即被删除，这中间会有一点延时。Mongodb每60秒运行一次后台过期清理任务，但由于清理时长取决于Mongodb的负载，过期的文档可能会存在时间超过60s.

过期索引具有几个限制：
1. TTL index只支持单字段索引
2. _id 字段不支持TTL
3. 如果一个非TTL index要变成一个TTL index，或要更新一个TTL index的过期时间需要删除旧索引重新创建。


#### 哈希索引
哈希索引指按照某个字段的hash值来建立索引，目前主要用于MongoDB Sharded Cluster的Hash分片，hash索引只能满足字段完全匹配的查询，不能满足范围查询。创建hash index时将index 字段的值设置为`hashed`
```
db.collection.createIndex( { _id: "hashed" })
```

#### 复合索引
Compound index 可以对多个字段创建索引，如：
```
db.products.createIndex( { "item": 1, "stock": 1 } )
```
复合索引可以支持多个字段的查询过滤；Mongodb最多允许32个字段的复合索引。使用上述语句创建索引后，索引将包含先以`item`字段排序，后以`stock`字段排序的索引。查询时除了查询时查询条件匹配所有的索引字段，复合索引还支持查询条件匹配索引字段的“前缀”，即按顺序排在前面的字段。例如以下的查询会使用到上述创建的索引
```
db.products.find( { item: "Banana" } )
db.products.find( { item: "Banana", stock: { $gt: 5 } } )
```

#### 排序
索引会以要么升序或降序存储引用的文档字段值，对单字段索引来说，创建索引字段时候指定的排序方向无关紧要，但是对复合字段来说，创建索引时的字段顺序或排序方向会对文档的查询排序产生决定性影响。例如如下创建索引：
```
db.events.createIndex( { "username" : 1, "date" : -1 } )
```
对于以下查询排序会使用到索引：
```
db.events.find().sort( { username: 1, date: -1 } )
db.events.find().sort( { username: -1, date: 1 } )
```
对于以下查询排序不会使用到索引：
```
db.events.find().sort( { username: 1, date: 1 } )
db.events.find().sort( { username: -1, date: -1 } )
```

#### 多值索引
Multikey index可以针对数组类型的字段进行索引，Mongo会为数组中每一个元素创建索引用来加速对数组字段的查询。数组字段可以是普通字段的数组也可以是嵌套文档的数据。创建多值索引和创建单字段索引语句并没有什么不同，只是因为索引字段是数组，Mongodb就会创建多值索引。

##### 多值索引边界
索引边界定义了索引在执行查询时的搜索范围，对在一个索引中存在多个predicates时，Mongodb会尝试通过交集或组合这些predicates的边界以产生一个更小的查询边界。例如有如下文档：
```
{ _id: 1, item: "ABC", ratings: [ 2, 9 ] }
{ _id: 2, item: "XYZ", ratings: [ 4, 3 ] }
```
创建多值索引如下：
```
db.survey.createIndex( { ratings: 1 } )
```
查询如下：
```
db.survey.find( { ratings : { $elemMatch: { $gte: 3, $lte: 6 } } } )
```
查询中使用了`$elemMatch`去查询文档文档的`ratings`字段中至少有一个值同时满足`$elemMatch`定义的两个条件。而单独看这两个条件会得出两个边界：
```
[ [ 3, Infinity ] ]
[ [ -Infinity, 6 ] ]
```
由于使用了`$elemMatch`,Mongodb会对这两个边界取交集得到`[ [ 3, 6 ] ]`用来查询文档。如果不使用`$elemMatch`,Mongodb不会交叉两个边界，那么就会得到不一样的查询结果。

##### 多值复合索引
multikey index of a compound index 即一个索引中既有单值字段也有数组字段，Mongodb对这样的索引有一个约束即索引中只能包含一个数组字段。例如有如下文档
```
{ _id: 1, item: "ABC", ratings: [ 2, 9 ] }
{ _id: 2, item: "XYZ", ratings: [ 4, 3 ] }
```
创建如下索引：
```
db.survey.createIndex( { item: 1, ratings: 1 } )
```
进行如下查询：
```
db.survey.find( { item: "XYZ", ratings: { $gte: 3 } } )
```
分开来看会得到两个边界：
```
[ [ "XYZ", "XYZ" ] ]
[ [ 3, Infinity ] ]
```
Mongodb会将两个边界组合起来查询：
```
{ item: [ [ "XYZ", "XYZ" ] ], ratings: [ [ 3, Infinity ] ] }
```
这是针对复合索引中，非多值字段与普通类型的数字字段的情况。对于复合索引中，非多值字段与嵌套数组字段的情况有所不同, 例如：
```
{
  _id: 1,
  item: "ABC",
  ratings: [ { score: 2, by: "mn" }, { score: 9, by: "anon" } ]
}
{
  _id: 2,
  item: "XYZ",
  ratings: [ { score: 5, by: "anon" }, { score: 7, by: "wv" } ]
}
```
创建索引如下：
```
db.survey2.createIndex( { "item": 1, "ratings.score": 1, "ratings.by": 1 } )
```
查询如下指定了三个字段：
```
db.survey2.find( { item: "XYZ",  "ratings.score": { $lte: 5 }, "ratings.by": "anon" } )
```
分开来看有三个边界：
```
[ [ "XYZ", "XYZ" ] ]
[ [ -Infinity, 5 ] ]
[ "anon", "anon" ]
```
Mongodb会组合`item`的边界和`ratings.score`或`ratings.by`的边界，具体是组合`item`和`rating.score`还是组合`item`和`ratings.by`取决于查询边界以及索引的值列表；而且Mongodb对此并不提供保证。然后如果我们想要组合`ratings.score`和`ratings.by`两个边界则必须使用`$elemMatch`。更多可以看[官方文档](https://docs.mongodb.com/v4.0/core/multikey-index-bounds/#multikey-index-bounds)


### References:
- https://www.cnblogs.com/eternityz/p/13595660.html
- https://docs.mongodb.com/v4.0/indexes/
- https://blog.csdn.net/u013066244/article/details/117337477
