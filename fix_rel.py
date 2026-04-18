import sys, os
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 116 (index 115): separate comment and code
old_line = lines[115]
if 'final current = await' in old_line:
    comment_part = old_line[:old_line.index('final current = await')].rstrip()
    code_part = '    final current = await (_db.select('
    lines[115] = comment_part + chr(10) + code_part + chr(10)
    print('Fixed relationship line 116')

# Fix line 121 (index 120): separate comment and code
old_line2 = lines[120]
if 'await (_db.update' in old_line2:
    comment_part2 = old_line2[:old_line2.index('await (_db.update')].rstrip()
    code_part2 = '    await (_db.update('
    lines[120] = comment_part2 + chr(10) + code_part2 + chr(10)
    print('Fixed relationship line 121')

with open(file, 'w', encoding='utf-8') as f:
    f.writelines(lines)
