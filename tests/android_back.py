"""Supplemental fresh-activity Back test after the full native harness has saved a town."""
import os
import sys
os.environ.setdefault("ANDROID_REPORT_NAME", "android-frontier-back")
from android_smoke import native_checks
if __name__ == "__main__":
    sys.exit(native_checks(back_only=True))
