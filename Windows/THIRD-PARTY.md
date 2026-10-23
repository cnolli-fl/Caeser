# Componentes do pacote Windows

O código do Caeser usa a licença MIT na raiz do repositório. Essa licença não substitui as licenças de ferramentas, runtimes e marcas.

- yt-dlp 2026.08.19: módulo oficial fixado nas dependências Python, Unlicense e avisos de terceiros da mesma versão. Um pequeno encaminhador nativo compartilha o runtime do spotDL, sem incorporar uma segunda cópia do Python.
- Deno 2.9.8: executável oficial x64, licença MIT, avisos Node/Undici/WebGPU da mesma versão e coleção de avisos das dependências fixadas em Cargo.lock. Os arquivos de crates são verificados pelos hashes do lockfile, sem executar seu código. Os avisos do V8 são obtidos do commit exato usado por rusty_v8 150.4.0. O inventário inclui dependências de outras plataformas e de desenvolvimento como conjunto conservador; não é uma lista exata dos módulos carregados pelo executável.
- FFmpeg/FFprobe 9.0.2 e LAME 3.100: construídos a partir dos fontes verificados em tools.lock.json; LGPL, sem habilitar GPL ou nonfree. Os dois tarballs, o script de construção e o registro de configuração são distribuídos no arquivo de fontes de terceiros correspondente à versão.
- spotDL 4.5.2: reconstruído no Windows com o yt-dlp atual fixado nas dependências compartilhadas, em vez de reutilizar o executável upstream que tinha um extrator antigo. MIT; as dependências mantêm licenças próprias, incluindo copyleft quando aplicável. Avisos em Python-packages dentro de Documentacao/Ferramentas.zip e distribuições-fonte das versões instaladas em Sources/Python-packages no arquivo separado, verificadas com os hashes do PyPI. O arquivo sources.json registra origens e checksums. O frontend web não usado e catálogos de interface não necessários não integram o executável; os pequenos catálogos en/pt/de exigidos pelo parser permanecem.
- CPython 3.14.7, PyInstaller 6.22.3 e respectivas dependências: avisos próprios em Documentacao/Ferramentas.zip. O Python é incorporado ao executável spotDL; o usuário final não precisa instalar Python.
- .NET 10 e Windows App SDK/WinUI: runtimes autocontidos distribuídos com os arquivos produzidos pelas ferramentas oficiais. Os avisos do SDK .NET e das versões resolvidas dos pacotes NuGet são copiados para Documentacao/Runtime durante o empacotamento. Apenas WinUI, Foundation, InteractiveExperiences, DWrite e suas dependências são referenciados, sem os componentes de IA/ML, Search e Widgets do metapacote completo.
- Marcas do Caeser, YouTube e Spotify: ver BRAND-ASSETS.md na raiz. Não são SF Symbols e não foram redesenhadas.

Os executáveis externos são processos separados. O Caeser não injeta código nessas ferramentas, não usa chaves de contas do desenvolvedor e não distribui cookies ou credenciais.

A construção falha se a coleta ou a verificação dos fontes exigidos falhar. Fontes de crates com expressões de licença copyleft reconhecidas pelo coletor acompanham o arquivo separado em Sources/Deno-dependencies. Os inventários são uma ajuda de rastreabilidade, não uma certificação jurídica nem uma afirmação de que todas as dependências usam MIT.

## Organização da distribuição otimizada

O aplicativo inclui os binários em Aplicativo/Tools e os avisos completos em Documentacao. Os avisos das ferramentas são agrupados em Ferramentas.zip, acessível pelo Explorador, sem remover conteúdo. FFmpeg e FFprobe compartilham as bibliotecas DLL da mesma compilação, dentro de Tools. Os textos de licença mantêm seus idiomas originais; não são traduções da interface.

Os fontes e scripts são oferecidos no arquivo **Caeser-VERSAO-Windows-x64-Fontes-Terceiros.zip**, com a mesma versão dos executáveis e seu checksum, na área pública [Fontes de terceiros](https://github.com/cnolli-fl/Caeser/releases/tag/fontes-terceiros). As notas do instalador incluem link direto para o arquivo correspondente, sem custo adicional e sem exigir cadastro. Não publicar um instalador sem disponibilizar os fontes correspondentes. Eles não são necessários para executar o app, mas continuam fazendo parte da distribuição.
