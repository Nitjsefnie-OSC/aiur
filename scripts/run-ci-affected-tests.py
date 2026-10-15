#!/usr/bin/env python3
"""Run the existing selector's command without evaluating it as shell code."""
import os
import shlex
import subprocess
import sys

selection = subprocess.check_output(['mix', 'aiur.affected_tests', sys.argv[1]], text=True)
print(selection, flush=True)
commands = [line for line in selection.splitlines() if line.startswith('cd src && mise exec -- ')]
if not commands:
    if '# no affected test files detected' not in selection:
        raise ValueError('selector did not produce a supported command')
else:
    if len(commands) != 1:
        raise ValueError('selector produced multiple commands')
    command = shlex.split(commands[0].removeprefix('cd src && mise exec -- '))
    if command == ['make', 'ci']:
        reason = next((line.removeprefix('# full suite recommended: ')
                       for line in selection.splitlines()
                       if line.startswith('# full suite recommended: ')), 'unknown')
        print(f'::notice::Unsafe affected selection deferred to full CI in the merge queue: {reason}', flush=True)
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as out:
                out.write(f'Full CI is deferred to the merge queue because this affected selection is unsafe to scope: {reason}\n')
    elif command[:4] != ['mix', 'test', '--max-cases', '4']:
        raise ValueError('unsupported selector command')
    else:
        subprocess.run(command, check=True)
