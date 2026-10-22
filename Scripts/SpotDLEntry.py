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
    elif sys.argv[1:] == ["--caeser-runtime-check"]:
        # Exercise constructors, not only --version/--help: spotDL explicitly
        # needs the German parser catalog even in a Portuguese-only app.
        from ytmusicapi import YTMusic
        from spotdl.providers.audio.ytmusic import YouTubeMusic
        YTMusic(language="en")
        YTMusic(language="pt")
        YouTubeMusic._create_client()
        print("Caeser media runtime OK (en/pt/de parser catalogs)")
    else:
        from spotdl.console import console_entry_point
        console_entry_point()
