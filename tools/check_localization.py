"""Verify a localized AutoHotkey installation against an unmodified baseline."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installation', type=Path, default=Path(r'D:\AutoHotkey'))
    parser.add_argument('--baseline', type=Path, required=True)
    args = parser.parse_args()
    installation = args.installation.resolve(strict=True)
    baseline = args.baseline.resolve(strict=True)
    if baseline == installation:
        parser.error('installation and baseline must be separate directories')

    root = Path(__file__).resolve().parents[1]
    patch = json.loads((root / 'localization/manifest.json').read_text(encoding='utf-8'))
    help_manifest = json.loads((root / 'localization/help_manifest.json').read_text(encoding='utf-8'))
    interpreter = installation / 'v2/AutoHotkey64.exe'
    errors = []
    checks = []
    localized = {entry['path'] for entry in patch}
    for entry in patch:
        name = entry['path']
        original = baseline / name
        target = installation / name
        if not original.is_file() or sha256(original) != entry['original_sha256']:
            errors.append(f'Baseline file differs: {name}')
        if not target.is_file() or sha256(target) != entry['localized_sha256']:
            errors.append(f'Applied file differs: {name}')
            continue
        process = subprocess.run(
            [str(interpreter), '/ErrorStdOut=UTF-8', '/Validate', str(target)],
            capture_output=True, encoding='utf-8', errors='replace', timeout=15,
        )
        checks.append({'path': name, 'exit': process.returncode, 'output': process.stdout + process.stderr})
        if process.returncode:
            errors.append(f'AHK load failed: {name}')

    protected = 0
    for original in baseline.rglob('*'):
        name = original.relative_to(baseline).as_posix()
        if not original.is_file() or name in localized:
            continue
        target = installation / name
        if not target.is_file():
            errors.append(f'Unrelated file missing: {name}')
            continue
        actual = sha256(target)
        if name == help_manifest['target'] and actual == help_manifest['sha256'].lower():
            continue
        if actual != sha256(original):
            errors.append(f'Unrelated file changed: {name}')
        else:
            protected += 1

    print(json.dumps({
        'result': 'FAIL' if errors else 'PASS',
        'localized_files': len(patch),
        'other_files_unchanged': protected,
        'ahk_load_checks': checks,
        'errors': errors,
    }, ensure_ascii=False))
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
