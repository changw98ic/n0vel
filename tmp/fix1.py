import sys
fp = chr(39)+chr(67)+chr(58)+chr(47)+chr(85)+chr(115)+chr(101)+chr(114)+chr(115)+chr(47)+chr(99)+chr(104)+chr(97)+chr(110)+chr(103)+chr(119)+chr(57)+chr(56)+chr(47)+chr(100)+chr(101)+chr(118)+chr(47)+chr(119)+chr(114)+chr(105)+chr(116)+chr(105)+chr(110)+chr(103)+chr(95)+chr(97)+chr(115)+chr(115)+chr(105)+chr(115)+chr(116)+chr(97)+chr(110)+chr(116)+chr(47)+chr(108)+chr(105)+chr(98)+chr(47)+chr(109)+chr(111)+chr(100)+chr(117)+chr(108)+chr(101)+chr(115)+chr(47)+chr(101)+chr(100)+chr(105)+chr(116)+chr(111)+chr(114)+chr(47)+chr(100)+chr(98)+chr(47)+chr(115)+chr(109)+chr(97)+chr(114)+chr(116)+chr(95)+chr(115)+chr(101)+chr(103)+chr(109)+chr(101)+chr(110)+chr(116)+chr(95)+chr(115)+chr(101)+chr(114)+chr(118)+chr(105)+chr(99)+chr(101)+chr(46)+chr(100)+chr(97)+chr(114)+chr(116)+chr(39)
with open(fp, chr(114), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)) as f:
    content = f.read()
lines = content.split(chr(10))
lines[10] = chr(32)*4+chr(40)+chr(39)+chr(92)+chr(117)+chr(51)+chr(48)+chr(48)+chr(67)+chr(39)+chr(44)+chr(32)+chr(39)+chr(92)+chr(117)+chr(51)+chr(48)+chr(48)+chr(68)+chr(39)+chr(41)+chr(44)+chr(32)+chr(47)+chr(47)+chr(32)+chr(12304)+chr(12305)
lines.insert(11, chr(32)*4+chr(40)+chr(39)+chr(92)+chr(117)+chr(51)+chr(48)+chr(48)+chr(69)+chr(39)+chr(44)+chr(32)+chr(39)+chr(92)+chr(117)+chr(51)+chr(48)+chr(48)+chr(70)+chr(39)+chr(41)+chr(44)+chr(32)+chr(47)+chr(47)+chr(32)+chr(12310)+chr(12311))
lines.insert(12, chr(32)*2+chr(93)+chr(59))
for i, line in enumerate(lines):
    if 'final triggers = [' in line:
        lines[i] = chr(32)*4+chr(102)+chr(105)+chr(110)+chr(97)+chr(108)+chr(32)+chr(116)+chr(114)+chr(105)+chr(103)+chr(103)+chr(101)+chr(114)+chr(115)+chr(32)+chr(61)+chr(32)+chr(91)+chr(39)+chr(35828)+chr(39)+chr(44)+chr(32)+chr(39)+chr(36947)+chr(39)+chr(44)+chr(32)+chr(39)+chr(38382)+chr(39)+chr(44)+chr(32)+chr(39)+chr(21914)+chr(39)+chr(44)+chr(32)+chr(39)+chr(22016)+chr(23125)+chr(39)+chr(44)+chr(32)+chr(39)+chr(22047)+chr(22036)+chr(39)+chr(93)+chr(59)
