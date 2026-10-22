# Componentes do pacote Windows

O código do Caeser usa a licença MIT na raiz do repositório. Essa licença não substitui as licenças de ferramentas, runtimes e marcas.

- yt-dlp 2026.08.19: executável oficial Windows x64, Unlicense e avisos de terceiros da mesma versão.
- Deno 2.9.8: executável oficial x64 e licença MIT da mesma versão; a revisão dos avisos de dependências permanece no checklist anterior à release estável.
- FFmpeg/FFprobe 9.0.2 e LAME 3.100: construídos a partir dos fontes verificados em tools.lock.json; LGPL, sem habilitar GPL ou nonfree. Os dois tarballs, o script de construção e o registro de configuração acompanham o pacote em Tools/Sources.
- spotDL 4.5.2: reconstruído no Windows com o yt-dlp atual fixado nas dependências compartilhadas, em vez de reutilizar o executável upstream que tinha um extrator antigo. MIT; avisos das dependências Python coletados em Tools/Licenses/Python-packages.
- CPython 3.14.7, PyInstaller 6.22.3 e respectivas dependências: avisos próprios em Tools/Licenses. O Python é incorporado ao executável spotDL; o usuário final não precisa instalar Python.
- .NET 10 e Windows App SDK/WinUI: runtimes autocontidos distribuídos com os arquivos produzidos pelas ferramentas oficiais, preservando os avisos de licença que acompanham esses runtimes.
- Marcas do Caeser, YouTube e Spotify: ver BRAND-ASSETS.md na raiz. Não são SF Symbols e não foram redesenhadas.

Os executáveis externos são processos separados. O Caeser não injeta código nessas ferramentas, não usa chaves de contas do desenvolvedor e não distribui cookies ou credenciais.

Antes da release estável, conferir os avisos do pacote construído, o inventário de dependências e a correspondência entre fontes e binários. Uma versão de desenvolvimento e seus artefatos de CI não significam que essa revisão final já foi concluída.
