---
title: "Firewalld 防火墙service和rich rule设置"
date: 2024-07-25T21:43:57+08:00
draft: false
---
开启防火墙可以减少暴露服务器开放的端口，缩小攻击面。这里记录一下两种在防火墙开启的情况下，设置开放哪些端口和规则的方式：service和rich rule。
<!--more-->

## Firewalld Service
我们可以通过文件定义一个service，声明外部访问这个service下的端口的流量应该被如何处置。更详细的信息可以看[redhat手册](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/using-and-configuring-firewalld_configuring-and-managing-networking#firewalld-zones_using-and-configuring-firewalld)
例如创建包含如下内容的文件`test.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>test</short>
  <port port="2377" protocol="tcp"/>
  <port port="5000" protocol="tcp"/>
</service>
```

将该文件放于`/etc/firewalld/services/`目录下，然后增加该service并reload:
```bash
firewall-cmd --permanent --add-service=test
firewall-cmd --reload
```

通过
```bash
firewall-cmd --list-services
```
可以查看已经添加成功。

如果要去掉：
```bash
firewall-cmd --permanent --remove-service=test
firewall-cmd --list-services
```

## Firewalld Rich Rule
[rich rule](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/security_guide/configuring_complex_firewall_rules_with_the_rich-language_syntax#Formatting_of_the_Rich_Language_Commands)可以用来实现更复杂的规则，例如：只允许某些ip访问某些端口。

先设置包含指定ip列表的[ipset](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/security_guide/sec-setting_and_controlling_ip_sets_using_firewalld):
```xml
<?xml version="1.0" encoding="utf-8"?>
<ipset type="hash:net">
  <short>nodes</short>
  <entry>192.168.10.1</entry>
  <entry>192.168.10.2</entry>
</ipset>
```
将该文件放于`/etc/firewalld/ipsets/`目录下，然后增加rich rule:
```bash
firewall-cmd --permanent --add-rich-rule 'rule family="ipv4" source ipset="nodes" service name="test" accept'
```
这样就定义了在ipset`nodes`中列举的ip地址都可以访问service`test`中的端口，而其他ip无法访问这些端口。

顺便提一下，防火墙之所以默认禁止了外部对所有监听端口的访问是因为它的默认策略是"Reject"。

通过：
```bash
firewall-cmd --list-all
```
可以看到所有目前生效的规则，例如：
```bash
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0
  sources: 
  services: cockpit dhcpv6-client test ssh
  ports: 
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
	rule family="ipv4" source ipset="nodes" service name="test" accept
```
其中`target`的值为`default`，对[redhat系统](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/using-and-configuring-firewalld_configuring-and-managing-networking#creating-a-new-zone_working-with-firewalld-zones)而言默认拒绝所有访问。
>default: Similar behavior as for REJECT, but with special meanings in certain scenarios.

之后如果接触到其他的再做补充。