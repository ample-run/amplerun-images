#!/usr/bin/env python3
"""CPU-only auth check of the exact pushed image; no GPU, ingress, or tenant data."""
import json
import re
import secrets
import subprocess
import sys
import time


IMAGE = sys.argv[1]
assert re.fullmatch(r"ghcr\.io/ample-run/amplerun-jupyter@sha256:[0-9a-f]{64}", IMAGE)


def docker(*args, timeout=30):
    """Run the docker CLI; fail loudly (never on a silent non-zero exit)."""
    r = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError(f"docker {args[0]} failed: {r.stderr.strip()[:300]}")
    return r


class backend:  # the few docker calls the check needs, no host-agent import
    create = staticmethod(lambda argv: docker(*argv[1:]).stdout.strip())
    inspect = staticmethod(lambda cid: json.loads(docker("inspect", cid).stdout)[0])
    start = staticmethod(lambda cid: docker("start", cid))
    wait = staticmethod(lambda cid, timeout: int(docker("wait", cid, timeout=timeout).stdout.strip()))
    logs = staticmethod(lambda cid: (lambda r: r.stdout + r.stderr)(docker("logs", cid)))
names = []
tokens = [secrets.token_urlsafe(32), secrets.token_urlsafe(32)]
probe_code = '''import json,sys,urllib.request,urllib.error
codes=[]
for token in json.load(sys.stdin):
 req=urllib.request.Request('http://127.0.0.1:8000/api/contents',headers={'Authorization':'token '+token} if token else {})
 try:
  with urllib.request.urlopen(req,timeout=2) as r:codes.append(r.status)
 except urllib.error.HTTPError as e:codes.append(e.code)
 except OSError:codes.append(0)
print(json.dumps(codes))
'''


def create(token):
    name = "amplerun-jupyter-auth-" + secrets.token_hex(8)
    names.append(name)
    argv = ["docker", "create", "--name", name, "--network", "none", "--runtime", "runc", "--read-only",
            "--cpus", "1", "--memory", "1g", "--memory-swap", "1g", "--pids-limit", "128",
            "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
            "--tmpfs", "/work:rw,size=128m,mode=1777", "--tmpfs", "/tmp:rw,size=32m,mode=1777",
            "-e", "JUPYTER_TOKEN=" + token, "-e", "AMPLERUN_API_KEY=" + token, IMAGE]
    cid = backend.create(argv)
    assert re.fullmatch(r"[0-9a-f]{64}", cid), "invalid created container id"
    effective = backend.inspect(cid)
    host = effective["HostConfig"]
    assert effective["Config"]["User"] == "10001:10001", "image user is not the tenant"
    assert host["NetworkMode"] == "none" and not host.get("PortBindings"), "unexpected ingress"
    assert host["Runtime"] == "runc" and not host.get("Devices") and not host.get("DeviceRequests"), "unexpected GPU device access"
    assert host["ReadonlyRootfs"] and host["PidsLimit"] == 128, "sandbox bounds missing"
    assert host["Memory"] == host["MemorySwap"] == 1024**3 and host["NanoCpus"] == 10**9, "resource bounds missing"
    assert "ALL" in host["CapDrop"] and any(s.startswith("no-new-privileges") for s in host["SecurityOpt"]), "privilege bounds missing"
    backend.start(cid)
    return cid


try:
    blank = create("")
    assert backend.wait(blank, timeout=15) == 64, "blank authentication did not fail closed"
    assert "Jupyter requires a per-job runtime credential." in backend.logs(blank)
    results = []
    for i, token in enumerate(tokens):
        cid = create(token)
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            result = subprocess.run(["docker", "exec", "-i", cid, "python", "-c", probe_code],
                                    input=json.dumps([None, token, tokens[1-i]]),
                                    capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                codes = json.loads(result.stdout)
                if codes == [403, 200, 403]:
                    break
            time.sleep(1)
        else:
            raise AssertionError("image authentication probe failed")
        logs = backend.logs(cid)
        assert all(value not in logs for value in tokens), "credential leaked into image logs"
        results.append({"anonymous": codes[0], "owner": codes[1], "other_lease": codes[2], "credential_in_logs": False})
        # Only one authenticated test container needs to run at a time.
        subprocess.run(["docker", "rm", "-f", cid], check=True, capture_output=True, text=True, timeout=15)
    print(json.dumps({"image": IMAGE, "blank_auth_exit": 64, "leases": results, "gpu_tested": False, "published_ports": []}, sort_keys=True))
finally:
    for name in names:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True, text=True, timeout=15)
