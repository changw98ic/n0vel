import sys
file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
new_line = '            name: Value('Review ${chapterIds.length} chapters'),'
lines[399] = new_line + '\n'
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed line 400')