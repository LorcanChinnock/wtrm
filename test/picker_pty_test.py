#!/usr/bin/env python3
"""Drives the interactive worktree picker over a real pty and asserts the
arrow-key cursor moves and no shell errors leak into the output.
Run: python3 test/picker_pty_test.py
"""
import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin", "wtrm.sh")


def read_avail(fd, wait=0.4):
    end = time.time() + wait
    data = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            data += chunk
    return data


def main():
    base = tempfile.mkdtemp(prefix="wtrm-pty-test-")
    repo = os.path.join(base, "main")
    wt1 = os.path.join(base, "wt1")
    wt2 = os.path.join(base, "wt2")
    os.mkdir(repo)
    try:
        run = lambda *args: subprocess.run(args, cwd=repo, check=True, capture_output=True)
        run("git", "init", "-q", ".")
        run("git", "commit", "-q", "--allow-empty", "-m", "init")
        run("git", "worktree", "add", "-q", wt1, "-b", "wt1")
        run("git", "worktree", "add", "-q", wt2, "-b", "wt2")

        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(repo)
            os.execvp(SCRIPT, [SCRIPT])

        try:
            initial = read_avail(fd)
            assert b"invalid timeout specification" not in initial, "read -t rejected on this bash: %r" % initial
            assert b"> [x]" in initial, "no cursor pointer in initial draw: %r" % initial

            os.write(fd, b"\x1b[B")  # down arrow
            after_down = read_avail(fd)
            assert b"invalid timeout specification" not in after_down, "arrow key errored: %r" % after_down
            lines = [l for l in after_down.split(b"\r\n") if b"[x]" in l or b"[ ]" in l]
            assert lines and b"> [" in lines[-1] and b"> [" not in lines[0], (
                "cursor did not move to second item: %r" % after_down
            )

            os.write(fd, b"q")
            after_q = read_avail(fd)
            assert b"cancelled" in after_q, "q did not cancel cleanly: %r" % after_q
        finally:
            try:
                os.close(fd)
            except OSError:
                pass
            os.waitpid(pid, 0)

        print("ok")
    finally:
        shutil.rmtree(base, ignore_errors=True)


if __name__ == "__main__":
    main()
