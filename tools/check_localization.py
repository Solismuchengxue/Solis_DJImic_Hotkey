from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
installation = Path(r'D:\AutoHotkey')
patch = json.loads((root / 'localization' / 'manifest.json').read_text(encoding='utf-8'))
backup = json.loads((root / 'backups' / '20261029_before_changes' / 'backup_manifest.json').read_text(encoding='utf-8-sig'))
changed = {entry['path'].replace('\\', '/'): entry for entry in patch}
errors = []
checks = []
for entry in patch:
    target = installation / entry['path']
    if hashlib.sha256(target.read_bytes()).hexdigest() != entry['localized_sha256']:
        errors.append(f"Applied file differs: {entry['path']}")
    process = subprocess.run([str(installation / 'v2' / 'AutoHotkey64.exe'), '/ErrorStdOut=UTF-8', '/Validate', str(target)], capture_output=True, encoding='utf-8', errors='replace', timeout=15)
    checks.append({'path': entry['path'], 'exit': process.returncode, 'output': process.stdout + process.stderr})
    if process.returncode:
        errors.append(f"AHK load failed: {entry['path']}")
protected = 0
hotkey_state = root / 'hotkey_applied.json'
hotkey_hash = json.loads(hotkey_state.read_text(encoding='utf-8-sig'))['SourceSHA256'] if hotkey_state.exists() else None
for entry in backup:
    name = entry['Path'].replace('\\', '/')
    if name in changed:
        continue
    if name == 'DJI_Mic_Hotkey.ahk' and hotkey_hash:
        if hashlib.sha256((installation / name).read_bytes()).hexdigest().upper() != hotkey_hash:
            errors.append('Deployed hotkey differs from the applied version')
        continue
    protected += 1
    if hashlib.sha256((installation / name).read_bytes()).hexdigest().upper() != entry['SHA256']:
        errors.append(f'Unrelated file changed: {name}')
result = {'result': 'PASS' if not errors else 'FAIL', 'localized_files': len(patch), 'other_files_unchanged': protected, 'ahk_load_checks': checks, 'errors': errors}
(root / 'tmp' / 'localization_check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(bool(errors))
