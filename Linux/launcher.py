"""One frozen executable runs the UI and both media tools."""

import sys


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--tool":
        name = sys.argv[2]
        sys.argv = [name, *sys.argv[3:]]
        if name == "yt-dlp":
            import yt_dlp
            yt_dlp.main()
        elif name == "spotdl":
            import spotdl
            spotdl.console_entry_point()
        else:
            raise SystemExit("Ferramenta desconhecida.")
    else:
        from app import main
        raise SystemExit(main())
