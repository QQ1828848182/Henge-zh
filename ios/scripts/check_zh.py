#!/usr/bin/env python3
"""Report which Chinese UI strings are present in a built Henge binary."""
import re
import sys

raw = open(sys.argv[1], "rb").read()
CJK = re.compile(r"[\u4e00-\u9fff]+")
segs = set()
for m in re.finditer(rb"(?:[\xe4-\xe9][\x80-\xbf]{2})+", raw):
    for part in CJK.findall(m.group().decode("utf-8", "ignore")):
        segs.add(part)

print("binary chinese word count:", len(segs))
for kw in ["还没有 Mac", "秒续", "外观", "色彩匹配", "隐藏控制条", "Mac 已关机",
           "Mac 应用", "添加示例程序", "跟随系统", "这里还是空的", "启动", "删除", "设置"]:
    print(("有  " if kw in segs else "无  ") + kw)
