"""Ini for the Revision-native co-op (CoopNet): Revision's own ini with its package order,
the chosen gameplay mode on top (as Revision's menu does: RevMenuChoice_GameplayMode),
and our package listed for compiling and for clients.

Usage: python -I make_net_ini.py <RevisionDefault.ini> <mode> <out.ini> [<modes dir>]
With a modes dir, also writes <Mode>.mode for every mode: what the relay (src/relay) puts
into RevNet.ini to switch modes.
"""
import os
import sys

MODES = {'Revision': [], 'Shifter': ['u'], 'Biomod': ['u', 'utx'], 'Vanilla': ['u', 'utx'], 'HR': ['u', 'utx']}
# As Revision's menu names them (Revision.int, RevMenuChoice_GameplayMode).
TITLES = {'Revision': 'Revision (Normal)', 'Shifter': 'Shifter', 'Biomod': 'BioMod',
          'Vanilla': 'Vanilla', 'HR': 'Human Revolution'}
OURS = 'RevNet'
# The dev or install folder next to Revision's System (tools/setup_net.sh NETNAME).
FOLDER = os.environ.get('NETNAME', 'CoopNet')
# Revision.exe reads its paths from LaunchSystem, UCC tools from Core.System; its menu sets both.
SYSTEMS = ('Core.System', 'RevisionInternal.LaunchSystem')
MODE_KEYS = ('Paths=', 'OverrideLocalizationPaths=', 'SavePath=')


def mode_lines(rev_ini, mode):
    """The lines that select a mode, for both system sections: the mode's folder first, then
    our package, then Revision's own paths; its localization and its own save folder."""
    lines = [f'Paths=..\\{mode}\\*.{e}' for e in MODES[mode]] + [f'Paths=..\\{FOLDER}\\*.u']
    section = None
    for line in open(rev_ini, encoding='latin1').read().splitlines():
        s = line.strip()
        if s.startswith('[') and s.endswith(']'):
            section = s[1:-1]
        # ponytail: New Vision (optional HD textures, same package names as stock) makes
        # joining clients fail "Package 'UNATCO' version mismatch" (HX and RevNet alike).
        elif section == SYSTEMS[0] and s.startswith('Paths=') and 'NewVision' not in s and s not in lines:
            lines.append(s)
    if mode != 'Revision':
        lines.append(f'OverrideLocalizationPaths=..\\{mode}\\')
    lines.append(f'SavePath=..\\{FOLDER}\\Save' + ('' if mode == 'Revision' else mode))
    return lines


def server_packages(rev_ini):
    """Packages the host loads only after it starts listening: HDTP meshes and skins (loaded
    by the actors as they start up) and the conversations. A client can only be sent
    references into the packages listed when listening starts (the map's own, their imports
    and ServerPackages); into any other they arrive as None (an HDTP crate has no mesh).
    Not the speech (184 MB: listed, the 32-bit host ran out of memory as a client joined);
    clients play conversation speech from their own copy (CoopConClient)."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(rev_ini)))
    names = []
    for folder, ext in (('HDTP/System', '.u'), ('HDTP/Textures', '.utx'), ('System', '.u')):
        d = os.path.join(root, folder)
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            base, e = os.path.splitext(f)
            if e.lower() == ext and base.startswith(('HDTP', 'RevisionConversations')) and 'Audio' not in base:
                names.append(base)
    return names


def build(rev_ini, mode):
    out, section, engine = [], None, None
    for line in open(rev_ini, encoding='latin1').read().splitlines():
        s = line.strip()
        if section == 'Engine.Engine' and s.startswith('GameEngine='):
            engine = s.split('=', 1)[1]
        if s.startswith('[') and s.endswith(']'):
            section = s[1:-1]
            out.append(line)
            if section in SYSTEMS:
                out += mode_lines(rev_ini, mode)
            continue
        if section in SYSTEMS and s.startswith(MODE_KEYS):
            continue
        if section == 'FirstRun' and s.startswith('FirstRun='):
            out.append('FirstRun=1100')
            continue
        # A modem's 2600 bytes/s takes minutes to send a Revision map's ~1000 network
        # actors (the player list and game info come last): broadband for clients,
        # a smoother server.
        if section == 'Engine.Player' and s.startswith('ConfiguredInternetSpeed='):
            out.append('ConfiguredInternetSpeed=20000')
            continue
        if section == 'IpDrv.TcpNetDriver' and s.startswith('NetServerMaxTickRate='):
            out.append('NetServerMaxTickRate=35')
            continue
        # The menu map's game: it opens the launcher's host/join URL (CoopGameInfo, CoopLaunch).
        if section == 'Engine.Engine' and s.startswith(('DefaultGame=', 'DefaultServerGame=')):
            out.append(s.split('=')[0] + f'={OURS}.CoopGameInfo')
            continue
        # Revision's root window with co-op screens (CoopRootWindow).
        if section == 'Engine.Engine' and s.startswith('Root='):
            out.append(f'Root={OURS}.CoopRootWindow')
            continue
        out.append(line)
        if section == 'Editor.EditorEngine' and s == 'EditPackages=RevisionMission':
            out.append(f'EditPackages={OURS}')
    # The engine reads its config from its own class's section (Revision's ini has none).
    assert engine, 'GameEngine= not found'
    out += ['', f'[{engine}]'] + [f'ServerPackages={p}' for p in server_packages(rev_ini)]
    text = '\n'.join(out) + '\n'
    assert f'EditPackages={OURS}' in text, 'EditPackages anchor not found'
    assert f'Root={OURS}.CoopRootWindow' in text, 'Root= not found'
    return text


def mode_file(rev_ini, mode):
    return '\n'.join([f'Title={TITLES[mode]}', f'Game={OURS}.CoopGameInfo'] + mode_lines(rev_ini, mode)) + '\n'


if __name__ == '__main__':
    rev_ini, mode, out = sys.argv[1:4]
    assert mode in MODES
    open(out, 'w', encoding='latin1', newline='\r\n').write(build(rev_ini, mode))
    if len(sys.argv) > 4:
        os.makedirs(sys.argv[4], exist_ok=True)
        for m in MODES:
            open(os.path.join(sys.argv[4], m + '.mode'), 'w', encoding='latin1', newline='\r\n').write(mode_file(rev_ini, m))
