---
title: "Python Xlrd"
date: 2018-03-23T12:58:44+08:00
lastmod: 2018-03-23T12:58:44+08:00
draft: false
keywords: ["python","xlrd","excel"]
description: ""
tags: ["python","excel"]
categories: ["python"]
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
记录下python读取excel的做法。

<!--more-->
python读取excel可以用[xlrd这个库](https://github.com/python-excel/xlrd)，使用起来还算简单。
```python
import xlrd
from datetime import date

filename = 'MIL_update.xlsx'
with xlrd.open_workbook(filename) as excel_file:
    sheet = excel_file.sheets()[0]  # 取得第一个sheet，还可以用sheet_by_index方法拿到指定sheet
    for line in sheet._cell_values[1:]: 
        period_name = int(line[1])
        pay_day = date(*xlrd.xldate_as_tuple(line[2], excel_file.datemode)[:3]).strftime('%Y-%m-%d')
        check_payroll_day = date(*xlrd.xldate_as_tuple(line[3], excel_file.datemode)[:3]).strftime('%Y-%m-%d')
        data.append((period_name, pay_day, check_payroll_day))
```
这里xlrd.open_workbook返回一个excel对象，除了直接用sheets()获取所有sheet还可以用sheet_by_index拿到指定index的sheet。excel的内容存放在sheet的_cell_values这个二维数组变量中，可以通过sheet.cell_value(rowx, colx)通过两个纬度的index来访问，

值得注意的一点是，excel中关于日期格式的处理，如果一个单元格是日期格式，那么这里读到的很有可能是一个float类型的数字，而不是excel展示的日期，需要调用xlrd.xldate_as_tuple(value, date_mode)来转换一下，xldate_as_tuple有两个参数，第一个是需要转换的值，第二个是转换模式，可以直接用excel对象的datemode。
