"""Dispatch two independent CLIs from one bundled Python runtime.

yt-dlp is a relative symlink to spotdl in the distribution. Only the invocation
name selects the upstream entry point; upstream package code is not patched.
"""
import os
import sys

if __name__ == "__main__":
    if os.path.basename(sys.argv[0]) == "yt-dlp":
        from yt_dlp import main
        main()
    else:
        from spotdl.console import console_entry_point
        console_entry_point()
