---
title: "如何使用vagrant"
date: 2022-11-17T22:24:43+08:00
draft: false
keywords: ["vagrant", "vm", "virtulbox"]
description: ""
tags: ["vagrant","vm"]
categories: []
author: "hulb"
comment: false
toc: false
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: '<a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/" target="_blank">CC BY-NC-ND 4.0</a>'
reward: false
mathjax: false
---
vagrant是一款通过配置文件创建虚机的命令行工具。平时在本地搭建开发环境需要跑虚拟机时用它很方便，这里记录下简单使用步骤。
<!--more-->
vagrant包含比较丰富的功能，这里只介绍最常用的：如何用vagrant创建虚拟机。
使用vagrant创建虚拟机首先需要下载想要创建的虚拟机操作系统的box。box是其他人做好的虚拟机模板，可以理解为其他人做好的虚拟机；通过`vagrant box add`可以导入box到本地vagrant box目录。

在[Vagrant Cloud](https://app.vagrantup.com/boxes/search)这里可以看到其他人分享的box,找到你需要的然后通过`vagrant box add`命令来导入就行。由于大陆网络环境直接导入时vagrant会通过网络将box下载到本地，这比较慢；也可以在网站上找到box后通过页面下载到本地后添加。例如我是这么调价centos8 box的
```
vagrant box add --name generic/centos8 ~\Downloads\xxxx
```
`xxxx`就是下载好的box文件。添加好后通过`vagrant box list`可以查看本地的box。

接下来新建目录，然后初始化`Vagrantfile`;`Vagrantfile`可以理解为配置文件，vagrant读取文件中的配置来创建对应配置的虚拟机，不同的虚拟化平台(或管理软件)可能有不同的配置，可以看[官方文档](https://developer.hashicorp.com/vagrant/docs)

```bash
mkdir vagrant-test & cd vagrant-test
vagrant init
```

`vagrant init`之后会创建一个默认`Vagrantfile`，使用`base` box:

```
Vagrant.configure("2") do |config|

  config.vm.box = "base"

end
```
vagrant 是ruby写的，这是ruby语法。实际上不存在`base`这个box，此时如果试图通过`vagrant up`来启动会报错。我们在init的时候应该指定box，删掉vagrant生成的`Vagrantfile`和`.vagrant`目录重来:

```
vagrant init generic/centos8
```

然后指定`vagrant up`即可启动虚拟机。启动后通过`vagrant ssh`可以直接通过ssh进入虚拟机，用户是`vagrant`。vagrant在启动虚拟机后会生成一个vagrant用户以及一对ssh密钥，将公钥插入虚机的ssh服务。默认虚拟机的配置由box决定。通过`vagrant destroy`即可销毁虚拟机。

下面通过修改配置将虚拟机改为1个CPU核心，256M内存，且修改root用户密码为root：
```
Vagrant.configure("2") do |config|
  
  config.vm.box = "generic/centos8"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "256"
    vb.cpus = "1"
  end

  config.vm.provision "shell", inline: <<-SHELL
    echo root | sudo passwd root --stdin
  SHELL
end
```
我这里使用的是virtualbox，不同的虚拟平台有不同的配置，可以看对应官方文档。改root密码通过`shell`这个provision来实现。改完后通过`vagrant up`即可启动，`vagrant suspend`可以暂定虚机。

在一个`Vagrantfile`中可以定义多个虚机，下面来定义三台虚机，写三台虚拟都与host共享同一个目录：
```
Vagrant.configure("2") do |config|

  config.vm.define "node1" do |node1|
    node1.vm.box = "generic/centos7"
    node1.vm.host_name = "node1"
    node1.vm.network "public_network"
    node1.vm.synced_folder "./data", "/vagrant_data"
    
    node1.vm.provider "virtualbox" do |vb|
      vb.memory = "256"
      vb.cpus = "1"
    end

    node1.vm.provision "shell", inline: <<-SHELL
      echo root | sudo passwd root --stdin
    SHELL
  end

  config.vm.define "node2" do |node2|
    node2.vm.box = "generic/centos7"
    node2.vm.host_name = "node2"
    node2.vm.network "public_network"
    node2.vm.synced_folder "./data", "/vagrant_data"
    
    node2.vm.provider "virtualbox" do |vb|
      vb.memory = "256"
      vb.cpus = "1"
    end

    node2.vm.provision "shell", inline: <<-SHELL
      echo root | sudo passwd root --stdin
    SHELL
  end

  config.vm.define "node3" do |node3|
    node3.vm.box = "generic/centos7"
    node3.vm.host_name = "node3"
    node3.vm.network "public_network"
    node3.vm.synced_folder "./data", "/vagrant_data"
    
    node3.vm.provider "virtualbox" do |vb|
      vb.memory = "256"
      vb.cpus = "1"
    end

    node3.vm.provision "shell", inline: <<-SHELL
      echo root | sudo passwd root --stdin
    SHELL
  end

end
```

`vagrant up`一键依次启动三个虚机。
