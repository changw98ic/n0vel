import sys
file_path = sys.argv[1]
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix method declarations that lost indentation (start at column 0)
for i in range(len(lines)):
    line = lines[i]
    # Method declarations inside class should have 2-space indent
    if line.startswith('Future<') and not line.startswith('  '):
        lines[i] = '  ' + line
        print(f'Fixed line {i+1}: added indent to method declaration')
    if line.startswith('await (') and not line.startswith('  '):
        lines[i] = '  ' + line
        print(f'Fixed line {i+1}: added indent to await')

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Done')
