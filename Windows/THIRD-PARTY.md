# Componentes do pacote Windows

O código do Caeser usa a licença MIT na raiz do repositório. Essa licença não substitui as licenças de ferramentas, runtimes e marcas.

- yt-dlp 2026.08.19: executável oficial Windows x64, Unlicense e avisos de terceiros da mesma versão.
- Deno 2.9.8: executável oficial x64, licença MIT, avisos Node/Undici/WebGPU da mesma versão e coleção de avisos das dependências fixadas em Cargo.lock. Os arquivos de crates são verificados pelos hashes do lockfile, sem executar seu código. Os avisos do V8 são obtidos do commit exato usado por rusty_v8 150.4.0. O inventário inclui dependências de outras plataformas e de desenvolvimento como conjunto conservador; não é uma lista exata dos módulos carregados pelo executável.
- FFmpeg/FFprobe 9.0.2 e LAME 3.100: construídos a partir dos fontes verificados em tools.lock.json; LGPL, sem habilitar GPL ou nonfree. Os dois tarballs, o script de construção e o registro de configuração acompanham o pacote em Tools/Sources.
- spotDL 4.5.2: reconstruído no Windows com o yt-dlp atual fixado nas dependências compartilhadas, em vez de reutilizar o executável upstream que tinha um extrator antigo. MIT; as dependências mantêm licenças próprias, incluindo copyleft quando aplicável. Avisos em Tools/Licenses/Python-packages e distribuições-fonte das versões instaladas em Tools/Sources/Python-packages, verificadas com os hashes do PyPI. O arquivo sources.json registra origens e checksums.
- CPython 3.14.7, PyInstaller 6.22.3 e respectivas dependências: avisos próprios em Tools/Licenses. O Python é incorporado ao executável spotDL; o usuário final não precisa instalar Python.
- .NET 10 e Windows App SDK/WinUI: runtimes autocontidos distribuídos com os arquivos produzidos pelas ferramentas oficiais. Os avisos do SDK .NET e das versões resolvidas dos pacotes NuGet são copiados para Licenses/Runtime durante a construção.
- Marcas do Caeser, YouTube e Spotify: ver BRAND-ASSETS.md na raiz. Não são SF Symbols e não foram redesenhadas.

Os executáveis externos são processos separados. O Caeser não injeta código nessas ferramentas, não usa chaves de contas do desenvolvedor e não distribui cookies ou credenciais.

A construção falha se a coleta ou a verificação dos fontes exigidos falhar. Fontes de crates com expressões de licença copyleft reconhecidas pelo coletor também acompanham o pacote em Tools/Sources/Deno-dependencies. Os inventários são uma ajuda de rastreabilidade, não uma certificação jurídica nem uma afirmação de que todas as dependências usam MIT.
