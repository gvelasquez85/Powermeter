"""Exercise the exact supervisor shell unprivileged with a system-binary fixture."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

source = Path('Sources/Powermeter/Collector.swift').read_text()
command = re.search(r'let command = """\n(.*?)\n        """', source, re.S).group(1)
with tempfile.TemporaryDirectory(prefix='powermeter-supervisor-') as folder:
    output = Path(folder) / 'output'
    control = Path(folder) / 'control'
    output.touch(); control.touch()
    command = command.replace(r'\(path)', str(output)).replace(r'\(pid)', str(os.getpid())).replace(r'\(control.path)', str(control))
    command = command.replace(r'\(43200 / interval)', '2').replace(r'\(interval * 1000)', '1000')
    command = command.replace('" = 0 ]', f'" = {os.getuid()} ]')
    command = command.replace('/usr/bin/powermetrics --samplers cpu_power -n 2 -i 1000 -b 1', '/bin/sh -c \'echo "CPU Power: 1234 mW"; /bin/sleep 30\'')
    subprocess.run(['/bin/sh', '-n', '-c', command], check=True)
    process = subprocess.Popen(['/bin/sh', '-c', command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 5
        while 'CPU Power: 1234 mW' not in output.read_text() and time.monotonic() < deadline:
            time.sleep(.05)
        assert 'POWERMETER_READY' in output.read_text()
        assert 'CPU Power: 1234 mW' in output.read_text()
        control.unlink()
        process.communicate(timeout=12)
        assert not output.exists(), 'root-output equivalent was not cleaned'
        print('PASS: supervisor readiness, live output, control-marker cancellation and cleanup')
    finally:
        if process.poll() is None:
            process.kill()
