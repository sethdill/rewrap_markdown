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


def check_status(arguments, source, status):
    result = subprocess.run(COMMAND + ['--check'] + arguments, input=source,
                            capture_output=True, env=ENV)
    assert result.returncode == status, (arguments, result.returncode, status, result.stderr)
    assert result.stdout == b'', (arguments, result.stdout)
    assert bool(result.stderr) == (status == 2), (arguments, result.stderr)


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
    check(['--repair', mode], release_note,
          ' '.join(release_note.splitlines()).replace('` )', '`)') + '\n')
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

tabbed_list = '*\tParent words go here.\n\t*\tChild words go here.\n'
wrapped_tabs = '*\tParent words go\n\there.\n\t*\tChild words\n\t\tgo here.\n'
for indent_args in ([], ['--indent=preserve']):
    check(indent_args + ['20'], tabbed_list, wrapped_tabs)
    check(indent_args + ['--unwrap'], wrapped_tabs, tabbed_list)
check(['--indent=spaces', '20'], tabbed_list, wrapped_tabs.expandtabs(4))
check(['--indent=tabs', '20'], '* Parent words go here.\n  * Child words go here.\n', wrapped_tabs)
check(['--indent=tabs', '--commit', '20'],
      'Subject\n\n* Parent words go here.\n  * Child words go here.\n',
      'Subject\n\n' + wrapped_tabs)
check(['20'], '*   Parent words go here.\n\t *\tChild words go here.\n',
      '*   Parent words go\n\there.\n\t *\tChild words\n\t\tgo here.\n')
check(['--indent=tabs', '--unwrap'], '*     code  stays\n', '*     code  stays\n')
check(['--unwrap'], '*\t\tcode  stays\n', '*\t\tcode  stays\n')
check(['--unwrap'], '*\t\n*\tSecond item.\n', '*\t\n*\tSecond item.\n')
check(['--indent=tabs', '--unwrap'], '* Text.\n\n  \t  code\tstays\n',
      '*\tText.\n\n\t    code\tstays\n')
check(['--indent=spaces', '--unwrap'], '*\tText.\n\t```\n\tkeep\tspaces\n\t```\n',
      '*   Text.\n    ```\n    keep\tspaces\n    ```\n')
check(['0'], 'Run `go`\n, then record the result.\n',
      'Run `go`, then record the result.\n')
# Repair is opt-in and composes with the existing CLI modes.
repair_source = 'Before ( `code` ) after.\n'
check(['0'], repair_source, repair_source)
check(['--repair', '10'], repair_source, 'Before\n(`code`)\nafter.\n')
check(['--repair', '18'], 'Before ( several\nordinary words\n) after.\n',
      'Before ( several\nordinary words )\nafter.\n')
for mode in ('--unwrap', '0'):
    check(['--repair', mode], repair_source, 'Before (`code`) after.\n')
    for style in ('preserve', 'tabs', 'spaces'):
        body = '*\t( `code` )\n'
        expected_body = '*   (`code`)\n' if style == 'spaces' else '*\t(`code`)\n'
        prefix = 'Subject ( `subject` )\n\n'
        suffix = '\n# ( `comment` )\n\nSigned-off-by: ( `trailer` )\n'
        check(['--repair', '--commit', '--indent=' + style, mode],
              prefix + body + suffix, prefix + expected_body + suffix)
protected_repair = '```\n( `code` )\n```\n\n    ( `code` )\n'
check(['--repair', '10'], protected_repair, protected_repair)
check(['--repair', '0'], '( `` a ` b  `` ) [ `code` ]\n',
      '(`` a ` b  ``) [ `code` ]\n')

invalid_indent = subprocess.run(COMMAND + ['--indent=invalid'], input='', text=True,
                                capture_output=True, env=ENV)
assert invalid_indent.returncode == 2 and not invalid_indent.stdout
assert '--indent=preserve' in invalid_indent.stderr

commit = ('Subject stays exactly as written\n\nThese words should wrap across lines.\n\n'
          '# Keep this comment exactly as written.\n\nSigned-off-by: Tester <test@example.com>\n')
wrapped = commit.replace('These words should wrap across lines.',
                         'These words\nshould wrap\nacross lines.')
check(['--commit', '16'], commit, wrapped)
check(['--commit', '--unwrap'], wrapped, commit)
check(['--commit', '0'], wrapped, commit)
check(['--commit'], commit, commit)

check_status(['16'], b'These words\nshould wrap\nacross lines.\n', 0)
check_status(['16'], b'These words should wrap across lines.\n', 1)
check_status([], b'', 0)
check_status([], b'Hello.\r\n', 1)
for mode in ('--unwrap', '0'):
    check_status([mode], unwrapped.encode('utf-8'), 0)
    check_status([mode], source.encode('utf-8'), 1)
check_status(['0'], b'( `code` )\n', 0)
check_status(['--repair', '0'], b'( `code` )\n', 1)
check_status(['--commit', '16'], wrapped.encode('utf-8'), 0)
check_status(['--commit', '16'], commit.encode('utf-8'), 1)
check_status(['--indent=spaces', '20'], wrapped_tabs.expandtabs(4).encode('utf-8'), 0)
check_status(['--indent=spaces', '20'], wrapped_tabs.encode('utf-8'), 1)
for arguments in (['--unknown'], ['wide'], ['16', '20'], ['--indent=invalid']):
    check_status(arguments, b'', 2)
check_status([], b'\xff', 2)
with open(os.devnull, 'wb') as write_only:
    read_error = subprocess.run(COMMAND + ['--check'], stdin=write_only,
                                capture_output=True, env=ENV)
assert read_error.returncode == 2 and not read_error.stdout, read_error
assert b'Could not read standard input' in read_error.stderr

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
