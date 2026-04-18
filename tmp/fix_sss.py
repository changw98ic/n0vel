import sys
fp=r'C:\Users\changw98\dev\writing_assistant\lib\modules\editor\db\smart_segment_service.dart'
with open(fp,'r',encoding='utf-8') as f:
    c=f.read()
lines=c.split(chr(10))
print(len(lines))
print(chr(0x9286) in lines[10])
