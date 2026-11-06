#!/usr/bin/env python3
"""Exercise a shipped CLI (Swift or Python) without a Swift installation."""
import os
from pathlib import Path
import subprocess
import shlex
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
COMMAND = [str(Path(arg).resolve()) if Path(arg).is_file() else arg for arg in sys.argv[1:]]
if not COMMAND:
    raise SystemExit('Usage: smoke.py EXECUTABLE [SCRIPT]')
ENV = dict(os.environ, MD_REWRAP_WIDTH='70')


def check(arguments, source, expected):
    result = subprocess.run(COMMAND + arguments, input=source, text=True,
                            capture_output=True, env=ENV, check=True)
    assert result.stdout == expected, (arguments, result.stdout, expected)
    assert not result.stderr, result.stderr


check(['--version'], '', 'rewrap-markdown ' + (ROOT / 'VERSION').read_text().strip() + '\n')
check(['16'], 'These words should wrap across lines.\n',
      'These words\nshould wrap\nacross lines.\n')
source = '- Café and naïve\n  prose with `inline code`.\n\n```\nkeep   spaces\n```\n'
unwrapped = '- Café and naïve prose with `inline code`.\n\n```\nkeep   spaces\n```\n'
check(['--unwrap'], source, unwrapped)
check(['0'], source, unwrapped)
release_note = (
    '* [508391] Fixed a JavaScript syntax coloring bug in which a regular\n'
    "expression inside a template literal's `${...}` expression (such as\n"
    r'`/\//g` ) could cause everything after the template literal to be' '\n'
    'colored as part of it. This also affected TypeScript and ActionScript,\n'
    'which use the same language module.\n'
)
table = '| A | B |\n| --- | --- |\n| 1 | 2 |\n'
for mode in ('--unwrap', '0'):
    check([mode], release_note, ' '.join(release_note.splitlines()) + '\n')
    check([mode], '1. First line\n continuation\n   more text.\n2. Next item.\n',
          '1. First line continuation more text.\n2. Next item.\n')
    check([mode], '- ```\n  keep   spaces\noutside the fence\nand the list.\n',
          '- ```\n  keep   spaces\noutside the fence and the list.\n')
    check([mode], '- First item.\n\nOutside\nthe list.\n',
          '- First item.\n\nOutside the list.\n')
    check([mode], '- Outer item\n  - Inner item\ncontinues here.\n',
          '- Outer item\n  - Inner item continues here.\n')
    check([mode], '- First item.\n' + table, '- First item.\n' + table)
check(['17'], '- First line\ncontinues here.\n',
      '- First line\n  continues here.\n')
commit = ('Subject stays exactly as written\n\nThese words should wrap across lines.\n\n'
          '# Keep this comment exactly as written.\n\nSigned-off-by: Tester <test@example.com>\n')
wrapped = commit.replace('These words should wrap across lines.',
                         'These words\nshould wrap\nacross lines.')
check(['--commit', '16'], commit, wrapped)
check(['--commit', '--unwrap'], wrapped, commit)
check(['--commit', '0'], wrapped, commit)
check(['--commit'], commit, commit)

# Invoke the installed hook through Git itself, including its failure path.
with tempfile.TemporaryDirectory(prefix='rewrap smoke ') as directory:
    repo = Path(directory)
    def git(*args, **kwargs):
        return subprocess.run(['git', '-C', directory, *args], env=ENV,
                              capture_output=True, text=True, **kwargs)
    git('init', check=True)
    git('config', 'user.name', 'Smoke Test', check=True)
    git('config', 'user.email', 'test@example.com', check=True)
    git('config', 'commit.gpgsign', 'false', check=True)
    git('config', 'core.hooksPath', str(repo / '.git/hooks'), check=True)
    hook = repo / '.git/hooks/commit-msg'
    hook_source = Path(os.environ.get('REWRAP_SMOKE_HOOK', ROOT / 'Distribution/Git/commit-msg'))
    hook.write_bytes(hook_source.read_bytes())
    hook.chmod(0o755)
    # The hook accepts one executable path; support the Python CLI via a wrapper.
    launcher = repo / 'filter command'
    launcher.write_text('#!/bin/sh\nexec ' + shlex.join(COMMAND) + ' "$@"\n')
    launcher.chmod(0o755)
    if os.environ.get('REWRAP_SMOKE_USE_PATH') == '1':
        ENV.pop('REWRAP_MARKDOWN', None)
    else:
        ENV['REWRAP_MARKDOWN'] = str(launcher)
    message = repo / 'message file'
    message.write_text('Subject\n\nBody is split\nacross lines.\n', encoding='utf-8')
    git('commit', '--allow-empty', '--cleanup=verbatim', '-F', str(message), check=True)
    actual = git('log', '-1', '--format=%B', check=True).stdout
    assert actual == 'Subject\n\nBody is split across lines.\n\n', actual
    original = message.read_bytes()
    head = git('rev-parse', 'HEAD', check=True).stdout
    ENV['REWRAP_MARKDOWN'] = str(repo / 'missing executable')
    failed = git('commit', '--allow-empty', '-F', str(message))
    assert failed.returncode != 0
    assert message.read_bytes() == original
    assert (repo / '.git/COMMIT_EDITMSG').read_bytes() == original
    assert git('rev-parse', 'HEAD', check=True).stdout == head
print('CLI and Git commit-msg smoke tests passed:', ' '.join(COMMAND))
