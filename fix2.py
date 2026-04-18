import re, sys
f = sys.argv[1]
lines = open(f, chr(114), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).readlines()
# Remove stray closing brace after sqlite3 loading comment
new_lines = []
skip_next_blank = False
for i, line in enumerate(lines):
    if line.strip() == chr(125) and i > 0:
        prev_nonblank = None
        for j in range(i-1, -1, -1):
            if lines[j].strip():
                prev_nonblank = lines[j].strip()
                break
        if prev_nonblank == chr(47)+chr(47)+chr(32)+chr(115)+chr(113)+chr(108)+chr(105)+chr(116)+chr(101)+chr(51)+chr(32)+chr(108)+chr(111)+chr(97)+chr(100)+chr(105)+chr(110)+chr(103)+chr(32)+chr(114)+chr(101)+chr(109)+chr(111)+chr(118)+chr(101)+chr(100):
            continue
    # Remove _loadSqlite3WithFts5 call
    if chr(95)+chr(108)+chr(111)+chr(97)+chr(100)+chr(83)+chr(113)+chr(108)+chr(105)+chr(116)+chr(101)+chr(51)+chr(87)+chr(105)+chr(116)+chr(104)+chr(70)+chr(116)+chr(115)+chr(53) in line:
        new_lines.append(chr(32)+chr(32)+chr(32)+chr(32)+chr(47)+chr(47)+chr(32)+chr(115)+chr(113)+chr(108)+chr(105)+chr(116)+chr(101)+chr(51)+chr(32)+chr(108)+chr(111)+chr(97)+chr(100)+chr(105)+chr(110)+chr(103)+chr(32)+chr(114)+chr(101)+chr(109)+chr(111)+chr(118)+chr(101)+chr(100)+chr(10))
        continue
    new_lines.append(line)
open(f, chr(119), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).writelines(new_lines)
print(chr(79)+chr(75))
