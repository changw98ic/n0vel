import sys
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

old = 'name: Value(' + chr(39) + 'Review  chapters' + chr(39) + ','
new = 'name: Value(' + chr(39) + 'Review  chapters' + chr(39) + '),'
content = content.replace(old, new)
print('Replaced name line')

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
