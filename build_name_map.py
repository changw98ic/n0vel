import os
import glob

BASE = os.path.dirname(os.path.abspath(__file__))

# Read missing getters
with open(os.path.join(BASE, 'missing_getters.txt'), 'r') as f:
    missing = [line.strip() for line in f if line.strip()]

# Read available getters
with open(os.path.join(BASE, 'available_getters.txt'), 'r') as f:
    available = set(line.strip() for line in f if line.strip())

# Module prefixes to try, longest first
modules = [
    'aiDetectionConfig', 'aiDetection', 'aiConfig', 'usageStats',
    'assistantPanel', 'povGeneration', 'povResult',
    'statistics', 'settings', 'timeline',
    'work', 'editor', 'reader', 'review',
]

mappings = {}
unmapped = []

for m in missing:
    if m in available:
        continue
    found = False
    for mod in sorted(modules, key=len, reverse=True):
        if m.startswith(mod) and len(m) > len(mod):
            rest = m[len(mod):]
            candidate = mod + '_' + rest[0].lower() + rest[1:]
            if candidate in available:
                mappings[m] = candidate
                found = True
                break
    if not found:
        # Try case-insensitive match
        lowered = m.lower().replace('_', '')
        for a in available:
            if a.lower().replace('_', '') == lowered:
                mappings[m] = a
                found = True
                break
    if not found:
        unmapped.append(m)

print(f'Mapped: {len(mappings)}')
print(f'Unmapped: {len(unmapped)}')

if unmapped:
    print('\nUnmapped getters:')
    for u in unmapped:
        print(f'  {u}')

# Apply replacements to all Dart files
dart_files = glob.glob(os.path.join(BASE, 'lib', '**', '*.dart'), recursive=True)
total = 0
for fpath in dart_files:
    if '.g.dart' in fpath or '.freezed.dart' in fpath or 'l10n/' in fpath:
        continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content
    for wrong, correct in sorted(mappings.items(), key=lambda x: -len(x[0])):
        content = content.replace(f'.{wrong}', f'.{correct}')
    if content != original:
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(content)
        total += 1
        print(f'Fixed: {os.path.relpath(fpath, BASE)}')

print(f'\nTotal files fixed: {total}')
