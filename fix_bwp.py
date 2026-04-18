import re, sys
f = sys.argv[1]
c = open(f, chr(114), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).read()
c = c.replace("import "+chr(39)+"package:sqlite3/open.dart"+chr(39)+";", "// sqlite3/open.dart removed (v3.x)")
c = c.replace("import "+chr(39)+"dart:ffi"+chr(39)+";", "// dart:ffi removed")
c = re.sub(r"void _loadSqlite3WithFts5\(\)[\s\S]*?\n\}", "// sqlite3 loading removed", c, count=1)
c = c.replace("setUpAll(_loadSqlite3WithFts5);", "setUpAll(() {});")
open(f, chr(119), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).write(c)
print(chr(79)+chr(75))
