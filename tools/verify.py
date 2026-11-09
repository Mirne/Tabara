"""Run Godot checks and fail on script errors even when Godot returns exit 0."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--ui", action="store_true")
args = parser.parse_args()
godot = os.environ.get("GODOT", "godot")

def run(arguments, marker=None, timeout=300):
    result = subprocess.run([godot, "--path", str(ROOT), *arguments], cwd=ROOT,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=timeout)
    print(result.stdout, end="")
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "\nERROR:" in result.stdout:
        sys.exit(1)
    if marker and marker not in result.stdout:
        print("Missing expected completion marker:", marker)
        sys.exit(1)

for directory in ["scripts", "tests"]:
    for script in sorted((ROOT / directory).glob("*.gd")):
        run(["--headless", "--script", "res://" + script.relative_to(ROOT).as_posix(), "--check-only"])
run(["--headless", "--script", "res://tests/test_simulation.gd"], "0 failures")
if args.ui:
    (ROOT / "test-results").mkdir(exist_ok=True)
    run(["--audio-driver", "Dummy", "--script", "res://tests/test_ui.gd"], "UI RESULT: 22 checks, 0 failures")
print("All requested checks passed.")
