#!/usr/bin/env python3
"""Regenerates docs/ui/copy-inventory.md from the ARB resources.

Usage: python3 tool/gen_copy_inventory.py
"""
import collections
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> None:
    en = json.load(open(os.path.join(ROOT, 'lib/l10n/app_en.arb')))
    zh = json.load(open(os.path.join(ROOT, 'lib/l10n/app_zh.arb')))
    keys = [k for k in en if not k.startswith('@')]

    sources = {}
    for root, _, files in os.walk(os.path.join(ROOT, 'lib')):
        if 'l10n/generated' in root:
            continue
        for name in files:
            if not name.endswith('.dart'):
                continue
            path = os.path.join(root, name)
            sources[path] = open(path).read()

    usage = collections.defaultdict(list)
    for key in keys:
        pattern = re.compile(r'l10n\.' + key + r'\b')
        for path, text in sources.items():
            if pattern.search(text):
                usage[key].append(os.path.relpath(path, ROOT))

    lines = [
        '# 文案迁移清册（Copy Inventory）',
        '',
        '由 `lib/l10n/app_en.arb` / `app_zh.arb` 生成，列出每条用户可见文案的 key、中英文与使用位置。',
        '重新生成：`python3 tool/gen_copy_inventory.py`。',
        '',
        f'共 **{len(keys)}** 条。',
        '',
        '| # | key | 中文 | English | 使用文件 |',
        '| --- | --- | --- | --- | --- |',
    ]
    for index, key in enumerate(sorted(keys), 1):
        files = sorted({os.path.basename(p) for p in usage.get(key, [])})
        where = ', '.join(files) or '（仅文档/间接）'
        zh_text = (zh.get(key) or '').replace('|', r'\|').replace('\n', '⏎')
        en_text = (en.get(key) or '').replace('|', r'\|').replace('\n', '⏎')
        lines.append(f'| {index} | `{key}` | {zh_text} | {en_text} | {where} |')

    out = os.path.join(ROOT, 'docs/ui/copy-inventory.md')
    with open(out, 'w') as handle:
        handle.write('\n'.join(lines) + '\n')
    print(f'wrote {out} ({len(keys)} keys)')


if __name__ == '__main__':
    main()
