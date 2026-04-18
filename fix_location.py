import sys
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 140 (index 139): separate comment and for loop
old_line = lines[139]
print(repr(old_line))
if 'for (final loc' in old_line and '//' in old_line:
    comment_part = old_line[:old_line.index('for (final loc')].rstrip()
    code_part = '    for (final loc in allLocations) {'
    lines[139] = comment_part + chr(10) + code_part + chr(10)
    print('Fixed location line 140')

with open(file, 'w', encoding='utf-8') as f:
    f.writelines(lines)
