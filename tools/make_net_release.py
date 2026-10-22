"""Build the co-op release zip: build/RevisionCoop-<version>.zip (RevNet, no HX).

Usage: python -I make_net_release.py <version>
Needs: build/net/RevNet.u (tools/build_net.sh), src/relay/RevCoop.exe (src/relay/build.bat),
~/RevisionCoop/downloads/coop/HXCoop/steam_api.dll (Valve's Steamworks redistributable).
The zip holds no Revision or Deus Ex files: the installer copies Revision's own engine files
on the player's PC (dist/net/Install-RevNet.ps1).
"""
import os
import shutil
import sys
import zipfile

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(here, 'tools'))
sys.dont_write_bytecode = True
import make_net_ini  # noqa: E402

DL = os.path.expanduser(os.environ.get('DL', '~/RevisionCoop/downloads'))
REV = os.environ.get('REV', r'C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision')
# Revision's code RevNet is built against: the installer notes a different version.
CHECKED = ('System/Revision.u', 'System/DeusEx.u', 'System/RF.u', 'System/RevisionMission.u',
           'System/ConSys.u', 'System/Engine.u', 'System/Extension.u')


def write(path, text):
    open(path, 'w', encoding='latin1', newline='\r\n').write(text)


def main(version):
    name = f'RevisionCoop-{version}'
    stage = os.path.join(here, 'build', 'release', name)
    shutil.rmtree(stage, ignore_errors=True)
    pay = os.path.join(stage, 'payload')
    net = os.path.join(pay, 'CoopNet')
    for d in (os.path.join(net, 'Modes'), os.path.join(pay, 'Relay')):
        os.makedirs(d)

    dist = os.path.join(here, 'dist', 'net')
    for f in ('Install.bat', 'Uninstall.bat', 'README.txt'):
        shutil.copy(os.path.join(dist, f), stage)
    # The MIT notices: ours, and deus-ex-coop's (the relay in the zip is built from it).
    for f in ('LICENSE', os.path.join('src', 'relay', 'LICENSE-hxcoop')):
        shutil.copy(os.path.join(here, f), stage)
    for f in ('Install-RevNet.ps1', 'Uninstall-RevNet.ps1'):
        text = open(os.path.join(dist, f), encoding='utf-8').read()
        open(os.path.join(pay, f), 'w', encoding='utf-8-sig', newline='\r\n').write(text)

    shutil.copy(os.path.join(here, 'build', 'net', 'RevNet.u'), net)
    rev_ini = os.path.join(REV, 'System', 'RevisionDefault.ini')
    ini = make_net_ini.build(rev_ini, 'Revision')
    write(os.path.join(net, 'RevNet.ini'), ini)
    write(os.path.join(net, 'RevNetDefault.ini'), ini)
    for m in make_net_ini.MODES:
        write(os.path.join(net, 'Modes', m + '.mode'), make_net_ini.mode_file(rev_ini, m))
    user = open(os.path.join(REV, 'System', 'RevisionDefUser.ini'), encoding='latin1').read().splitlines()
    write(os.path.join(net, 'RevNetDefUser.ini'),
          '\n'.join('NetSpeed=20000' if l.startswith('NetSpeed=') else l for l in user) + '\n')

    relay = os.path.join(pay, 'Relay')
    shutil.copy(os.path.join(here, 'src', 'relay', 'RevCoop.exe'), relay)
    shutil.copy(os.path.join(DL, 'coop', 'HXCoop', 'steam_api.dll'), relay)
    open(os.path.join(relay, 'steam_appid.txt'), 'w').write('480')

    lines = [f'{f}|{os.path.getsize(os.path.join(REV, f))}' for f in CHECKED]
    write(os.path.join(pay, 'versions.txt'), '\n'.join(lines) + '\n')

    out = os.path.join(here, 'build', name + '.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(stage):
            for f in files:
                p = os.path.join(root, f)
                z.write(p, os.path.join(name, os.path.relpath(p, stage)))
    print(out, os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    main(sys.argv[1])
