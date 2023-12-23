---
title: "Sd Card Recovery"
date: 2023-12-17T17:15:16+08:00
draft: false
keywords: ["sd card","windows","storage"]
description: ""
tags: ["windows","sd", "sd-card"]
categories: ["storage"]
author: "hulb"
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
---
今天整理sd卡中的文件时，可能操作不当将sd卡搞成无法打开需要格式化了。在网上找到一种方法恢复正常，这里记录一下。

<!--more-->
usb,sd卡等即时插拔存储设备一定要用正确的方式先退出然后再从电脑上拔出，否则就有可能导致存储设备损坏。

TL;DR
方法来自[这里](https://huifu.wondershare.cn/sdkashujuhuifu/310662.html)，我使用了文中的步骤2,即在windows系统命令行工具中执行
```
chkdsk /f D:
```
我的sd卡插入后被自动分配的盘符是`D:`。

回车等待程序处理完成后就好了。


