
import sys
filepath = r'C:\Users\changw98\dev\writing_assistant\lib\modules\editor\db\smart_segment_service.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()
lines = content.split('\n')
print(f'Total lines: {len(lines)}')
print(f'Line 11: {repr(lines[10])}')
