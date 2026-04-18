import sys
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 400 (index 399): correct the name line and add type line
lines[399] = '            name: Value(' + chr(39) + 'Review  chapters' + chr(39) + '),' + chr(10)
lines.insert(400, '            type: const Value(' + chr(39) + 'review' + chr(39) + '),' + chr(10))
print('Fixed lines 400-401')

with open(file, 'w', encoding='utf-8') as f:
    f.writelines(lines)
