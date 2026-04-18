import sys
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 400 (index 399): replace the garbled line entirely
lines[399] = '            name: Value(' + chr(39) + 'Review  chapters' + chr(39) + '),' + chr(10)
print('Fixed line 400')

with open(file, 'w', encoding='utf-8') as f:
    f.writelines(lines)
