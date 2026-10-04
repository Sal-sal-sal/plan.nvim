"""Drive a real Neovim terminal and retain frames for visual inspection."""
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "target/tui"
ANSI = re.compile(r"\x1b\[[0-9;:]*m")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="plan-tui-") as directory:
        socket = str(Path(directory) / "tmux.sock")

        def tmux(*args):
            return subprocess.check_output(["tmux", "-S", socket, *args], text=True)

        def capture():
            return tmux("capture-pane", "-p", "-e", "-t", "plan:0")

        command = f"cd {shlex.quote(str(ROOT))} && nvim -u tests/minimal.lua examples/today.plan"
        try:
            tmux("-f", "/dev/null", "new-session", "-d", "-s", "plan", "-x", "96", "-y", "22", command)
            tmux("set-option", "-g", "default-terminal", "tmux-256color")
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                before = capture()
                if "○ Learn Rust" in ANSI.sub("", before):
                    break
                time.sleep(0.05)
            else:
                raise AssertionError("Task icons were not drawn in the terminal")
            (OUTPUT / "00-before.ansi").write_text(before)
            tmux("send-keys", "-t", "plan:0", "3G", "Enter")
            frames = []
            for index in range(15):
                time.sleep(0.075)
                frame = capture()
                frames.append(frame)
                (OUTPUT / f"{index + 1:02}-completion.ansi").write_text(frame)
            plain = [ANSI.sub("", frame) for frame in frames]
            assert any("✦ Learn Rust" in frame for frame in plain), "Filled-star frame missing"
            assert any("✧ Learn Rust" in frame for frame in plain), "Hollow-star frame missing"
            assert "✓ Learn Rust" in plain[-1], "The animation must settle to a check"
            assert "Plan 2/5" in plain[-1], "The statusline must update"
            tmux("send-keys", "-t", "plan:0", ":qa!", "Enter")
            print("PASS: real terminal completion, both animation frames, check and counts")
        finally:
            subprocess.run(["tmux", "-S", socket, "kill-server"], capture_output=True)


if __name__ == "__main__":
    main()
