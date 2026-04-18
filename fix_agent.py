import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
data = open(r"C:\Users\changw98\dev\writing_assistant\lib\core\services\ai\agent\agent_service.dart", "rb").read()
text = data.decode("utf-8", errors="replace")
# Check for the pattern \ufffd followed by ?
pattern = chr(0xFFFD) + "?"
count = text.count(pattern)
print(f"Pattern found: {count}")
# Show occurrences
idx = 0
for i in range(min(10, count)):
    pos = text.find(pattern, idx)
    ctx = text[max(0,pos-15):pos+20]
    print(f"  At pos {pos}: ...{repr(ctx)}...")
    idx = pos + 1
