import sys
file = sys.argv[1]
with open(file, chr(39)+chr(114)+chr(39), encoding=chr(39)+chr(117)+chr(116)+chr(102)+chr(45)+chr(56)+chr(39)) as f:
    lines = f.readlines()
newline = chr(32)*12 + chr(110)+chr(97)+chr(109)+chr(101)+chr(58)+chr(32)+chr(86)+chr(97)+chr(108)+chr(117)+chr(101)+chr(40)+chr(39)+chr(82)+chr(101)+chr(118)+chr(105)+chr(101)+chr(119)+chr(32)+chr(36)+chr(123)+chr(99)+chr(104)+chr(97)+chr(112)+chr(116)+chr(101)+chr(114)+chr(73)+chr(100)+chr(115)+chr(46)+chr(108)+chr(101)+chr(110)+chr(103)+chr(116)+chr(104)+chr(125)+chr(32)+chr(99)+chr(104)+chr(97)+chr(112)+chr(116)+chr(101)+chr(114)+chr(115)+chr(39)+chr(41)+chr(44)+chr(10)
lines[399] = newline
with open(file, chr(39)+chr(119)+chr(39), encoding=chr(39)+chr(117)+chr(116)+chr(102)+chr(45)+chr(56)+chr(39)) as f:
    f.writelines(lines)
print(chr(68)+chr(111)+chr(110)+chr(101))