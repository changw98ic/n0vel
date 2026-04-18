import sys
file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
new_line = chr(32)*12 + 'name: Value(' + chr(39) + 'Review ' + chr(36) + '{chapterIds.length} chapters' + chr(39) + '),' + chr(10)
lines[399] = new_line
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed line 400')
