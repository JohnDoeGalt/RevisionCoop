"""Do the game properties RevNet uses directly have the same shape in every mode? (Matches
by name: a hit may be another class's property of that name; check each.)
A property that is one value in Revision's DeusEx but an array (or another type) in a
mode's is read and written as Revision's: reading Biomod's BioelectricCell.rechargeAmount
(int[4]) as an int copied all four into one, over the memory next to it (host crash).
check_modes.py can't see this: the import is found. Compares `var` declarations in the
decompiled mode sources (~/RevisionCoop/ref/sz/<mode>/DeusEx) for every `.Name` RevNet
code touches. Usage: python -I tools/check_arrays.py [<RevNet Classes dir>] [<ref/sz dir>]
"""
import os
import re
import sys

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'src', 'RevNet', 'Classes')
sz = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser('~/RevisionCoop/ref/sz')
MODES = ('Vanilla', 'Shifter', 'Biomod', 'HR')
VAR = re.compile(r'^\s*var\s*(?:\([^)]*\))?\s*((?:\w+\s+)*?)(\w+(?:<[^>]*>)?)\s+([^;]+);', re.M)


def declarations(folder):
    """{(class, name): 'type[dim]'} of every var in the folder's .uc files."""
    out = {}
    for f in os.listdir(folder):
        if not f.endswith('.uc'):
            continue
        text = open(os.path.join(folder, f), encoding='latin1').read()
        cls = f[:-3]
        for m in VAR.finditer(text):
            typ = m.group(2).lower()
            for part in m.group(3).split(','):
                part = part.strip()
                name = re.match(r'(\w+)', part)
                if not name:
                    continue
                dim = re.search(r'\[(\w+)\]', part)
                out[(cls.lower(), name.group(1).lower())] = typ + (f'[{dim.group(1)}]' if dim else '')
    return out


used = set()
for f in os.listdir(src):
    if f.endswith('.uc'):
        text = open(os.path.join(src, f), encoding='latin1').read()
        text = re.sub(r'//.*', '', text)
        used |= {n.lower() for n in re.findall(r'\.\s*(\w+)\s*(?![\w(])', text)}

rev = declarations(os.path.join(sz, 'Rev', 'DeusEx'))
bad = 0
for mode in MODES:
    folder = os.path.join(sz, mode, 'DeusEx')
    if not os.path.isdir(folder):
        print(f'{mode}: no sources at {folder}')
        continue
    other = declarations(folder)
    for (cls, name), shape in sorted(rev.items()):
        if name not in used or (cls, name) not in other:
            continue
        if other[(cls, name)] != shape:
            bad += 1
            print(f'{mode}: {cls}.{name} is {other[(cls, name)]} (Revision: {shape})')
print('all same shape' if bad == 0 else f'{bad} differences: use those by name (Get/SetPropertyText)')
