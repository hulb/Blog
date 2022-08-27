---
title: "GPG Sign Commit"
date: 2022-08-14T22:16:52+08:00
lastmod: 2022-08-27T14:13:52+08:00
draft: false
keywords: ["gpg", "git", "signature"]
description: ""
tags: ["gpg","git"]
categories: []
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
很早就听说要给github的commit加上签名，但一直懒。直到最近做了一个小实验，在不加签名的情况下，在github或是bitbucket这类系统中对代码仓库有写权限的用户可以通过在本地配置`user.name`以及`user.email`的方式伪造commit author。因此耐着性子了解了下怎么使用gpg来签名commit，感觉也挺简单的，做下记录。
<!--more-->

#### 生成gpg密钥
首先要生成gpg key。对于linux平台一般应安装了gpg，使用以下命令生成：
```
gpg --full-generate-key
```
按照提示填写信息即可生成，密钥长度越长越安全。生成的是一对密钥，包含`public key`和`private key`；可以通过`gpg --list-keys`展示公钥，`gpg --list-secret-keys`展示私钥。

#### git commit签名
通过`git config`来配置git对commit进行签名，以及使用的密钥。可以通过`git config --global`来设置全局配置，如果是对单个仓库就不需要`--global`了。
```
git config user.signingkey <id> # 设置用来签名commit的key id
git config commit.gpgsign true # 设置git自动对每次commit都签名，如果不自动则每次commit需要带上 -S
```

当签名时遇到错误：
```
error: gpg failed to sign the data 
fatal: failed to write commit object
```
尝试如下：
```
export GPG_TTY=$(tty)
```
或是将这句放到 ~/.bashrc中，windows下不会有这个问题。


#### github 上传公钥
本地git提交commit签名后，要让github能识别到对应的签名需要在github设置中添加gpg公钥。使用`--export`可以显示公钥。
```
gpg --export -a <id> # 到处公钥
```
将导出的公钥添加到github账户中后，推送签名好的commit，github上就会显示`Verified`标志。

#### gpg 密钥备份和恢复
```
gpg --export-keys --export-option backup > public.gpg # 导出公钥
gpg --export-secret-keys --export-option backup > private.gpg # 到处私钥
gpg --import private.pgp # 导入私钥
```
通过`--export-keys`以及`--export-secret-keys`就可以导出密钥，`--import`导入密钥。

#### 从gpg服务器导入导出密钥
可以通过命令将本地的公钥发送到gpg密钥服务器，gpg工具默认的服务器是`keys.openpgp.org`。
```
gpg --send-keys <id> # 将公钥发送到密钥服务器
gpg --search-keys <id/email> # 在密钥服务器搜索公钥
gpg --receive-keys <id/email> # 从密钥服务器导入公钥
```
通过gpg将自己本地的公钥发送到密钥服务器后，别人就可以从服务器上下载你的密钥；从而可以用公钥加密信息后发送给你用私钥解密。通过公钥也可以验证签名是否是伪造的。
