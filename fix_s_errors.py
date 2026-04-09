import os, re, subprocess

BASE = os.path.dirname(os.path.abspath(__file__))

# Run flutter analyze and get "Undefined name 's'" errors
result = subprocess.run(
    ['flutter', 'analyze'],
    capture_output=True, text=True,
    cwd=BASE,
    timeout=120,
)

# Parse error lines
error_lines = {}  # file -> set of line numbers
for line in result.stdout.splitlines():
    m = re.search(r"Undefined name 's' - (.+?):(\d+):\d+", line)
    if m:
        fpath = m.group(1)
        lineno = int(m.group(2))
        relpath = os.path.relpath(fpath, BASE).replace('\\', '/')
        error_lines.setdefault(relpath, set()).add(lineno)

# Also get "Undefined name 'context'" errors for pov_config_panel
for line in result.stdout.splitlines():
    m = re.search(r"Undefined name 'context' - (.+?):(\d+):\d+", line)
    if m:
        fpath = m.group(1)
        lineno = int(m.group(2))
        relpath = os.path.relpath(fpath, BASE).replace('\\', '/')
        error_lines.setdefault(relpath, set()).add(lineno)

print(f"Files with 'Undefined name' errors: {len(error_lines)}")
for f, lines in sorted(error_lines.items()):
    print(f"  {f}: {len(lines)} errors at lines {sorted(lines)}")

total_added = 0

for relpath in sorted(error_lines.keys()):
    fpath = os.path.join(BASE, relpath)
    if not os.path.exists(fpath):
        print(f"  SKIP (not found): {relpath}")
        continue

    with open(fpath, 'r', encoding='utf-8') as f:
        lines_text = f.readlines()

    # Find which methods need `s` or `context` declaration
    # Strategy: for each error line, walk backward to find the method start
    # Then check if that method already has the declaration

    error_set = error_lines[relpath]

    # Group error lines by their enclosing method (by finding method start line)
    method_needs_decl = {}  # method_start_line -> True/False (needs s or context)

    for err_line in error_set:
        # Walk backward to find method/function start
        found_method_start = None
        brace_count = 0
        for i in range(err_line - 1, -1, -1):  # 0-indexed
            line = lines_text[i].rstrip('\n')
            # Count braces
            opens = line.count('{') - line.count('}')
            # Actually count properly considering strings
            for ch in line:
                if ch == '{':
                    brace_count += 1
                elif ch == '}':
                    brace_count -= 1

            # Check if this is a method start (has { and brace_count just became positive)
            if '{' in line and brace_count > 0:
                # Check if this looks like a method signature
                if re.search(r'(Widget|void|String|bool|List|Future|Widget)\s+\w+\s*\(', line) or 'build(' in line:
                    found_method_start = i
                    break

        if found_method_start is not None:
            method_needs_decl[found_method_start] = True
        else:
            print(f"  WARNING: Could not find method start for line {err_line} in {relpath}")

    # Now add declarations after each method start
    new_lines = list(lines_text)
    offset = 0

    for method_start in sorted(method_needs_decl.keys()):
        insert_idx = method_start + 1 + offset

        # Check if declaration already exists in the next few lines
        already_has = False
        for j in range(insert_idx, min(insert_idx + 3, len(new_lines))):
            if 'final s = S.of(context)' in new_lines[j]:
                already_has = True
                break

        if not already_has:
            # Get indentation from method line
            method_line = new_lines[method_start + offset]
            indent = len(method_line) - len(method_line.lstrip())
            indent_str = ' ' * (indent + 4)  # One level deeper

            # Check if this file needs 'context' or 's'
            needs_context = relpath in [
                'lib/features/pov_generation/presentation/widgets/pov_config_panel.dart'
            ]

            if needs_context:
                # For files with "Undefined name 'context'" - need BuildContext
                new_lines.insert(insert_idx, f'{indent_str}final s = S.of(context)!;\n')
                print(f"  Added 'final s' after method at line {method_start + 1} in {relpath}")
            else:
                new_lines.insert(insert_idx, f'{indent_str}final s = S.of(context)!;\n')
                print(f"  Added 'final s' after method at line {method_start + 1} in {relpath}")

            offset += 1
            total_added += 1

    if offset > 0:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)

print(f"\nTotal declarations added: {total_added}")
