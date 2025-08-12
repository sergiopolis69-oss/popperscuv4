#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$APP_DIR"
echo ">> Regenerando android/ (embedding v2)"
rm -rf android
flutter create --platforms=android .

python3 - <<'PY'
import io, os, re
app_dir = os.path.abspath('.')
for path in [os.path.join(app_dir,'android','app','build.gradle.kts'),
             os.path.join(app_dir,'android','app','build.gradle')]:
    if os.path.isfile(path):
        with io.open(path,'r',encoding='utf-8') as f: s=f.read()
        if 'ndkVersion' not in s:
            if path.endswith('.kts'):
                s=re.sub(r'(android\s*\{)', r'\1\n    ndkVersion = "27.0.12077973"', s, 1)
            else:
                s=re.sub(r'(android\s*\{)', r"\1\n    ndkVersion '27.0.12077973'", s, 1)
            with io.open(path,'w',encoding='utf-8') as f: f.write(s)
            print('Injected ndkVersion into', path)
        else:
            print('ndkVersion already present in', path)
props=os.path.join(app_dir,'android','gradle.properties')
os.makedirs(os.path.dirname(props), exist_ok=True)
lines=[]
if os.path.exists(props):
    with io.open(props,'r',encoding='utf-8') as f: lines=f.read().splitlines()
if not any(x.startswith('android.ndkVersion=') for x in lines):
    lines.append('android.ndkVersion=27.0.12077973')
    with io.open(props,'w',encoding='utf-8') as f: f.write('\n'.join(lines)+'\n')
    print('Added android.ndkVersion to gradle.properties')
else:
    print('gradle.properties already has android.ndkVersion')
PY

LP="android/local.properties"
mkdir -p android
touch "$LP"
# eliminar cualquier ndk.dir para dejar que Gradle resuelva por version
grep -v '^ndk\.dir=' "$LP" > "$LP.tmp" || true
mv "$LP.tmp" "$LP" || true
echo "ndk.dir removido (si existía)."
