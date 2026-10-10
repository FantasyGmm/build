#!/usr/bin/env python3
"""Check the Git index (tracked/staged source), without deleting local files."""
import argparse
from pathlib import Path, PurePosixPath
import subprocess
import sys


def check(root):
    def git(*args):
        return subprocess.run(['git', '-C', str(root), *args], capture_output=True)

    listed = git('ls-files', '-z', '--cached')
    if listed.returncode:
        raise ValueError('cannot read Git index')
    forbidden = []
    for raw in listed.stdout.split(b'\0'):
        if not raw:
            continue
        name = raw.decode('utf-8', errors='surrogateescape')
        path = PurePosixPath(name)
        if (set(path.parts) & {'__pycache__', '.venv', '.pytest_cache', '.gnupg', '.ssh'}
                or path.parts[0] in {'output', 'work', 'cache', '.tmp'}
                or path.suffix in {'.pyc', '.pyo'}
                or path.name in {'.env', '.env.local', 'id_rsa', 'id_ed25519'}
                or path.name.endswith('.local.json')):
            forbidden.append(name)
    # Report only paths, never key contents. Public archive keys are allowed.
    keys = git('grep', '--cached', '-I', '-l', '-z', '-E',
               '^-----BEGIN ([A-Z0-9 ]*PRIVATE KEY|PGP PRIVATE KEY BLOCK)-----', '--')
    if keys.returncode not in (0, 1):
        raise ValueError('cannot inspect indexed text for private-key headers')
    forbidden.extend(p.decode('utf-8', errors='replace') for p in keys.stdout.split(b'\0') if p)
    if forbidden:
        raise ValueError('forbidden source entries: ' + ', '.join(sorted(set(forbidden))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    check(args.root)
    print('Repository hygiene passed: Git index; not a complete credential or ownership audit')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print('Repository hygiene failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
