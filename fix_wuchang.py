import re, sys
f = sys.argv[1]
c = open(f, chr(114), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).read()
c = c.replace(chr(10)+"import "+chr(39)+"package:sqlite3/open.dart"+chr(39)+";"+chr(10), chr(10)+"// sqlite3/open.dart removed (v3.x)"+chr(10))
c = c.replace(chr(10)+"import "+chr(39)+"dart:ffi"+chr(39)+";"+chr(10), chr(10)+"// dart:ffi removed"+chr(10))
c = re.sub(r"void _loadSqlite3WithFts5\(\)[\s\S]*?\n\}", "// sqlite3 loading removed", c, count=1)
c = c.replace("setUpAll(_loadSqlite3WithFts5);", "setUpAll(() {});")
c = c.replace("getCoreModelConfig(any())", "getCoreModelConfig(any<feature_config.ModelTier>())")
c = c.replace("getCoreProviderConfig(any())", "getCoreProviderConfig(any<feature_config.ModelTier>())")
c = c.replace("getFunctionOverrideTier(any())", "getFunctionOverrideTier(any<String>())")
old = "registerFallbackValue(feature_config.ModelTier.fast);"
newv = old + chr(10) + "    registerFallbackValue("+chr(39)+chr(39)+");"
c = c.replace(old, newv)
open(f, chr(119), encoding=chr(117)+chr(116)+chr(102)+chr(45)+chr(56)).write(c)
print(chr(79)+chr(75))
