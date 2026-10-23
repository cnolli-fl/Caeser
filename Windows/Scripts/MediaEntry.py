"""Windows-only dispatch: the tiny yt-dlp shim shares spotDL's Python runtime."""
import sys

if __name__ == "__main__":
    if sys.argv[1:2] == ["--caeser-ytdlp"]:
        del sys.argv[1]
        from yt_dlp import main
        main()
    elif sys.argv[1:] == ["--caeser-runtime-check"]:
        from ytmusicapi import YTMusic
        from spotdl.providers.audio.ytmusic import YouTubeMusic
        YTMusic(language="en")
        YTMusic(language="pt")
        YouTubeMusic._create_client()
        print("Caeser Windows media runtime OK (en/pt/de parser catalogs)")
    else:
        from spotdl.console import console_entry_point
        console_entry_point()
