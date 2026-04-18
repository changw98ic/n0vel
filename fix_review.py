import sys
file = sys.argv[1]
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()
old1 = chr(100)+chr(101)+chr(115)+chr(99)+chr(114)+chr(105)+chr(112)+chr(116)+chr(105)+chr(111)+chr(110)+chr(58)+chr(32)+chr(105)+chr(116)+chr(101)+chr(109)+chr(91)+chr(39)+chr(100)+chr(101)+chr(115)+chr(99)+chr(114)+chr(105)+chr(112)+chr(116)+chr(105)+chr(111)+chr(110)+chr(39)+chr(93)+chr(32)+chr(97)+chr(115)+chr(32)+chr(83)+chr(116)+chr(114)+chr(105)+chr(110)+chr(103)+chr(63)+chr(32)+chr(63)+chr(63)+chr(32)+chr(39)
idx = content.find(old1)
if idx >= 0:
    after = content[idx+len(old1):]
    comma = after.find(',')
    content = content[:idx] + old1 + 'N/A' + chr(39) + after[comma:]
    print('Fixed line 68')
old2 = chr(110)+chr(97)+chr(109)+chr(101)+chr(58)+chr(32)+chr(86)+chr(97)+chr(108)+chr(117)+chr(101)+chr(40)+chr(39)
idx2 = content.find(old2)
if idx2 >= 0:
    after2 = content[idx2+len(old2):]
    comma2 = after2.find(',')
    content = content[:idx2] + old2 + 'Review ' + chr(36) + chr(123)+chr(99)+chr(104)+chr(97)+chr(112)+chr(116)+chr(101)+chr(114)+chr(73)+chr(100)+chr(115)+chr(46)+chr(108)+chr(101)+chr(110)+chr(103)+chr(116)+chr(104)+chr(125)+chr(32)+chr(99)+chr(104)+chr(97)+chr(112)+chr(116)+chr(101)+chr(114)+chr(115) + chr(39) + after2[comma2:]
    print('Fixed line 400')
with open(file, 'w', encoding='utf-8') as f:
    f.write(content)
