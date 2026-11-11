"""Losslessly compress texture containers, align, and sign an exported debug APK.

Godot stores GPU texture containers without ZIP compression. Transparent scenery
compresses well; this changes ZIP storage only, never texture pixels or scripts.
Uses the same existing development key so installed settlements can update.
"""
from pathlib import Path
import argparse
import hashlib
import os
import subprocess
import tempfile
import zipfile
import zlib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('input', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--sdk', type=Path, default=os.environ.get('ANDROID_HOME', '/workspace/toolchains/android'))
parser.add_argument('--keystore', type=Path, default=Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'godot/keystores/debug.keystore')
args = parser.parse_args()
build_tools = args.sdk / 'build-tools/36.0.0'
env = os.environ.copy()
env.setdefault('TABARA_KEY_PASSWORD', 'android')
env.setdefault('TABARA_KEY_ALIAS', 'androiddebugkey')
args.output.parent.mkdir(parents=True, exist_ok=True)

def signature(name):
    return name.startswith('META-INF/') and (name.endswith(('.RSA', '.DSA', '.EC', '.SF')) or name == 'META-INF/MANIFEST.MF')

originals = {}
with tempfile.TemporaryDirectory(prefix='tabara-apk-') as directory:
    unsigned = Path(directory) / 'unsigned.apk'
    aligned = Path(directory) / 'aligned.apk'
    with zipfile.ZipFile(args.input) as source, zipfile.ZipFile(unsigned, 'w', allowZip64=False) as target:
        for info in source.infolist():
            if signature(info.filename):
                continue
            payload = source.read(info)
            originals[info.filename] = hashlib.sha256(payload).digest()
            if info.filename.endswith('.ctex') and len(zlib.compress(payload, 9)) + 1024 < len(payload):
                info.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(info, payload, compresslevel=9 if info.compress_type == zipfile.ZIP_DEFLATED else None)
    subprocess.run([build_tools / 'zipalign', '-P', '16', '-f', '4', unsigned, aligned], check=True)
    subprocess.run([build_tools / 'apksigner', 'sign', '--ks', args.keystore, '--ks-pass', 'env:TABARA_KEY_PASSWORD', '--ks-key-alias', env['TABARA_KEY_ALIAS'], '--out', args.output, aligned], check=True, env=env)
subprocess.run([build_tools / 'zipalign', '-c', '-P', '16', '4', args.output], check=True)
subprocess.run([build_tools / 'apksigner', 'verify', '--print-certs', args.output], check=True)
with zipfile.ZipFile(args.output) as result:
    for name, digest in originals.items():
        if hashlib.sha256(result.read(name)).digest() != digest:
            raise RuntimeError('APK payload changed: ' + name)
size = args.output.stat().st_size
print(f'Payloads identical; {args.input.stat().st_size:,} -> {size:,} bytes')
print('SHA-256:', hashlib.file_digest(args.output.open('rb'), 'sha256').hexdigest())
if size >= 100 * 1024 * 1024:
    raise RuntimeError('APK exceeds the direct GitHub download file limit')
