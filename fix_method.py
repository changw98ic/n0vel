f = sys.argv[1]
c = open(f, chr(114), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).read()
mtd = chr(10)+chr(32)*2+chr(105)+chr(110)+chr(116)+chr(32)+chr(95)+chr(100)+chr(101)+chr(102)+chr(97)+chr(117)+chr(108)+chr(116)+chr(77)+chr(97)+chr(120)+chr(84)+chr(111)+chr(107)+chr(101)+chr(110)+chr(115)+chr(70)+chr(111)+chr(114)+chr(84)+chr(105)+chr(101)+chr(114)+chr(40)+chr(77)+chr(111)+chr(100)+chr(101)+chr(108)+chr(84)+chr(105)+chr(101)+chr(114)+chr(32)+chr(116)+chr(105)+chr(101)+chr(114)+chr(41)+chr(32)+chr(123)+chr(10)+chr(32)*4+chr(114)+chr(101)+chr(116)+chr(117)+chr(114)+chr(110)+chr(32)+chr(115)+chr(119)+chr(105)+chr(116)+chr(99)+chr(104)+chr(32)+chr(40)+chr(116)+chr(105)+chr(101)+chr(114)+chr(41)+chr(32)+chr(123)+chr(10)+chr(32)*6+chr(77)+chr(111)+chr(100)+chr(101)+chr(108)+chr(84)+chr(105)+chr(101)+chr(114)+chr(46)+chr(102)+chr(97)+chr(115)+chr(116)+chr(32)+chr(61)+chr(62)+chr(32)+chr(52)+chr(48)+chr(57)+chr(54)+chr(44)+chr(10)+chr(32)*6+chr(77)+chr(111)+chr(100)+chr(101)+chr(108)+chr(84)+chr(105)+chr(101)+chr(114)+chr(46)+chr(109)+chr(105)+chr(100)+chr(100)+chr(108)+chr(101)+chr(32)+chr(61)+chr(62)+chr(32)+chr(56)+chr(49)+chr(57)+chr(50)+chr(44)+chr(10)+chr(32)*6+chr(77)+chr(111)+chr(100)+chr(101)+chr(108)+chr(84)+chr(105)+chr(101)+chr(114)+chr(46)+chr(116)+chr(104)+chr(105)+chr(110)+chr(107)+chr(105)+chr(110)+chr(103)+chr(32)+chr(61)+chr(62)+chr(32)+chr(49)+chr(54)+chr(51)+chr(56)+chr(52)+chr(44)+chr(10)+chr(32)*4+chr(125)+chr(59)+chr(10)+chr(32)*2+chr(125)
idx = c.find(chr(70)+chr(117)+chr(116)+chr(117)+chr(114)+chr(101)+chr(60)+chr(118)+chr(111)+chr(105)+chr(100)+chr(62)+chr(32)+chr(115)+chr(97)+chr(118)+chr(101)+chr(77)+chr(111)+chr(100)+chr(101)+chr(108)+chr(67)+chr(111)+chr(110)+chr(102)+chr(105)+chr(103))
if idx > 0:
    line_start = c.rfind(chr(10), 0, idx) + 1
    comment_start = c.rfind(chr(10), 0, line_start - 1) + 1
    c = c[:comment_start] + mtd + chr(10)*2 + c[comment_start:]
    open(f, chr(119), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).write(c)
    print(chr(79)+chr(75))
else:
    print(chr(78)+chr(79)+chr(84)+chr(70)+chr(79)+chr(85)+chr(78)+chr(68))
