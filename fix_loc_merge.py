import sys

# Fix location_repository.dart: merge comment lines that got split
file_path = r'C:\Users\changw98\dev\writing_assistant\lib\modules\settings\db\location_repository.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
i = 0
while i < len(lines):
    line = lines[i]
    # Check if this is a comment line ending with ? and next line is not a comment/blank/brace
    if (line.strip().startswith('//') and line.rstrip().endswith('?') and
        i + 1 < len(lines) and
        not lines[i+1].strip().startswith('//') and
        not lines[i+1].strip().startswith('}') and
        not lines[i+1].strip().startswith('{') and
        lines[i+1].strip() != ''):
        # Merge this line with the next
        merged = line.rstrip() + lines[i+1].lstrip()
        fixed.append(merged if not merged.endswith(chr(10)) else merged + chr(10))
        print(f'Merged line {i+1} with {i+2}')
        i += 2
    else:
        fixed.append(line)
        i += 1

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed location_repository.dart')
