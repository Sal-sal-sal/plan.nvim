"""Run the same Rust and Neovim workflows locally and in CI."""
from pathlib import Path
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]


def run(*command):
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


run("cargo", "fmt", "--check")
run("cargo", "test", "--locked")
run("cargo", "clippy", "--all-targets", "--locked", "--", "-D", "warnings")
run("cargo", "build", "--release", "--locked", "--target-dir", "target")
if shutil.which("stylua"):
    run("stylua", "--check", "lua", "ftdetect", "ftplugin", "tests")
for script in sorted((ROOT / "tests/nvim").glob("*.lua")):
    if script.name != "helper.lua":
        run("nvim", "--headless", "-u", "tests/minimal.lua", "-c", f"luafile {script.relative_to(ROOT)}")
if shutil.which("tmux"):
    run("python3", "scripts/tui_smoke.py")
