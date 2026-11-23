# Componentes distribuídos no Caeser Linux

O AppImage inclui os avisos de licença disponíveis nos pacotes Python em `usr/share/doc/caeser/licenses/`. As versões são fixadas em `Linux/requirements.txt`.

| Componente | Uso | Fonte e licença |
| --- | --- | --- |
| PySide6 e Qt | Interface KDE/Qt | <https://www.qt.io/licensing/> |
| yt-dlp | Download de vídeo e áudio | <https://github.com/yt-dlp/yt-dlp> |
| spotDL | Metadados do Spotify e busca no YouTube | <https://github.com/spotDL/spotify-downloader> |
| FFmpeg | Mesclagem e conversão | <https://ffmpeg.org/legal.html> |
| imageio-ffmpeg | Distribuição do FFmpeg | <https://github.com/imageio/imageio-ffmpeg> |
| Deno | JavaScript para extratores do yt-dlp | <https://github.com/denoland/deno> |
| appimagetool | Criação do AppImage, não distribuído dentro dele | <https://github.com/AppImage/appimagetool> |

O executável FFmpeg vem do wheel `imageio-ffmpeg` fixado no build. O projeto do FFmpeg disponibiliza o código-fonte e os termos de cada biblioteca em <https://ffmpeg.org/download.html>. O executável Deno vem do arquivo oficial da release 2.9.8, conferido pelo checksum publicado pelo projeto.
