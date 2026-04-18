import glob

def fix_consumed_quotes(filepath):
    with open(filepath, chr(114)+chr(98)) as f:
        raw = f.read()
    lines = raw.split(bytes([13,10]))
    if len(lines) == 1:
        lines = raw.split(bytes([10]))
        sep = bytes([10])
    else:
        sep = bytes([13,10])
    changed = False
    for i, line in enumerate(lines):
        if bytes([39,39,39]) in line:
            continue
        q = 0
        for bv in line:
            if bv == 0x27:
                q += 1
        if q % 2 == 0:
            continue
        has_high = any(bv > 0x7F for bv in line)
        if not has_high:
            continue
        new_line = bytearray(line)
        j = len(new_line) - 1
        while j >= 1:
            if new_line[j] == 0x3F and new_line[j-1] > 0x7F:
                if j + 1 < len(new_line):
                    next_byte = new_line[j + 1]
                    if next_byte in (0x2C, 0x29, 0x3B, 0x5D, 0x7D):
                        new_line[j] = 0x27
                        changed = True
                        break
                else:
                    new_line[j] = 0x27
                    changed = True
                    break
            j -= 1
        if changed:
            lines[i] = bytes(new_line)
    if changed:
        result = sep.join(lines)
        with open(filepath, "rb+") as f:
            f.write(result)
        print(f"Fixed quotes: {filepath}")
        return True
    return False

for f in sorted(glob.glob(chr(108)+chr(105)+chr(98)+chr(47)+chr(109)+chr(111)+chr(100)+chr(117)+chr(108)+chr(101)+chr(115)+chr(47)+chr(42)+chr(42)+chr(47)+chr(42)+chr(46)+chr(100)+chr(97)+chr(114)+chr(116), recursive=True)):
    fix_consumed_quotes(f)
