---
title: "Electron 框架学习(一)"
date: 2018-05-14T13:01:03+08:00
lastmod: 2018-05-14T13:01:03+08:00
draft: false
keywords: ["electron"]
description: ""
tags: ["electron"]
categories: ["electron"]
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
最近一个需求需要做一个windows客户端，第一时间想到了electron，遂简单学习了一下。
<!--more-->

[Electron](https://electronjs.org/)是使用web前端的js,css,html技术构建跨平台应用的框架。入门的话可以看官方的文档，比较全面。

我接到的需求要求应用打开后给用户一个选项，连接远程服务还是本地服务，本地服务就是部署在本地的web程序，远程服务就是连接公网上的web程序。其实就是需要一个可以客制化的浏览器壳子，web程序已经是存在的了。

在electron的[入门项目](https://github.com/electron/electron-quick-start)的基础上在调用BrowserWindow实例的loadURL()方法时参数直接为web程序的地址就行了。

但这时会有一个问题就是我们web程序前端引用的一些js框架在electron环境中都显示未定义。此时需要在new BrowserWindow的时候传入nodeIntegration参数，这样就是把electron当成浏览器使用。

```
winLocal = new BrowserWindow({
        webPreferences: {
            nodeIntegration: false
        },
        width: 800,
        height: 600,
        show: false
    })
win.loadURL('http://localhost:8088')
```

这样就可以将我们的web程序变成一个windows客户端。

至于让程序开始的时候让客户选择连接本地服务还是远程服务这个需求，可以在程序开始的时候打开一个index.html然后通过用户点击不同的按钮让程序加载不同的url。在实现这个的过程中注意到了electron另外一个问题。

在electron文档关于[主进程和渲染进程](https://electronjs.org/docs/tutorial/application-architecture#%E4%B8%BB%E8%BF%9B%E7%A8%8B%E5%92%8C%E6%B8%B2%E6%9F%93%E8%BF%9B%E7%A8%8B)中提到，web页面都是在隔离的渲染进程中运行的，而我们要在index.html这个web页面改变主程序的加载url无法直接做到。需要使用electron提供的ipcRenderer和ipcMain来进程进程间通信。

在index.html中我们在用户点击按钮的时候触发ipc.send,在主进程中我们用ipc.on来监听，然后实现加载不同的url。
在index.html中

```
<html>

<head>
    <meta charset="UTF-8">
    <title>Hello World!</title>
</head>

<body>
        <div id="container">
            <div>
                <button id="loadLocal">连接本地服务</button>
            </div>
            <div>
                <button id="localRemote">连接远程服务 </button>
            </div>
        </div>
</body>
<script>
var ipc = require('electron').ipcRenderer
var localButton = document.getElementById('loadLocal')
var remoteButton = document.getElementById('localRemote')

localButton.addEventListener('click', function(){
    ipc.send('loadLocal')
})

remoteButton.addEventListener('click', function(){
    ipc.send('loadRemote')
})
</script>

</html>
```

这里要注意js只能写在下面，页面加载完后，document.getElementById才能拿到元素。

在main.js中
```
const ipc = require('electron').ipcMain
ipc.on('loadLocal', function (event, data) {
    winLocal = new BrowserWindow({
        webPreferences: {
            nodeIntegration: false
        },
        width: 800,
        height: 600,
        show: false
    })

    winLocal.on('closed', () => {
        winLocal = null
        win = null
    })
    win = null
    win = winLocal
    win.show()
    // win.webContents.openDevTools()
    win.loadURL('http://localhost:8088')
})

```

通过ipc.on监听来自于渲染进程的RPC通信，然后创建不同的windows加载不同的url。

这部分入门还算比较容易，很快就做出了想要的效果，轻松构建了跨平台的应用。