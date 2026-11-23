# Caeser para Linux

Edição para Fedora 44 KDE Plasma em **x86_64 (Intel/AMD) ou aarch64 (ARM64)**, com a identidade Ocean do Mac e do Windows. Escolha o arquivo da arquitetura do seu computador. O pacote AppImage inclui a interface, yt-dlp, spotDL, FFmpeg e Deno. Links do Spotify são usados para identificar faixas e buscar o áudio no YouTube; o áudio não é baixado do Spotify.

## Usar o AppImage

Baixe o arquivo `.AppImage` na [release Linux 0.2.0](https://github.com/cnolli-fl/Caeser/releases/tag/linux-v0.2.0), clique com o botão direito no Dolphin, abra **Propriedades → Permissões**, marque **É executável** e abra o arquivo. Pelo terminal:

```bash
chmod +x Caeser-*-Linux-*.AppImage
./Caeser-*-Linux-*.AppImage
```

O AppImage não instala o Caeser no menu de aplicativos por conta própria. Para isso, use a integração de AppImages do seu sistema. Algumas instalações podem precisar do pacote `fuse-libs` (`sudo dnf install fuse-libs`).

Para salvar apenas um intervalo, ative **Cortar vídeo** ou **Cortar áudio** e informe, por exemplo, `1:20` e `1:50`. O Caeser salva o trecho em MP4 ou MP3. Use um link por vez. No Spotify, o corte usa a versão da faixa encontrada no YouTube. O intervalo fica salvo na fila e no histórico.

Os testes automáticos verificam a inicialização no Fedora 44 e confirmam o início e a duração de trechos MP3/MP4 gerados pelo AppImage em ambas as arquiteturas. Para reduzir as animações fora do KDE, inicie com `CAESER_REDUCE_MOTION=1`.

Os downloads e o histórico ficam no computador. A biblioteca é salva em `${XDG_DATA_HOME:-~/.local/share}/Caeser/library.json`. O Caeser não pede login do Spotify.

## Desenvolvimento

No Fedora 44, instale Python 3.12 ou 3.13 e as dependências do sistema para PySide6. Para gerar o AppImage, instale também `desktop-file-utils`. Crie um ambiente virtual e instale `Linux/requirements.txt` para desenvolver. A edição de desenvolvimento procura FFmpeg e Deno no `PATH`.

```bash
python3 -m venv Linux/.venv
Linux/.venv/bin/python -m pip install -r Linux/requirements.txt
Linux/.venv/bin/python Linux/launcher.py
```

O empacotamento deve rodar em Linux da mesma arquitetura do pacote desejado:

```bash
bash Linux/build-appimage.sh
```

O script instala dependências Python fixadas em um ambiente isolado, empacota a interface e os extratores no mesmo executável, copia FFmpeg e verifica o SHA-256 do arquivo oficial do Deno. O AppImage resultante e seu hash ficam em `Linux/dist/`. Não há binários de terceiros versionados no Git.

Licenças e fontes: veja [THIRD-PARTY.md](THIRD-PARTY.md). O AppImage inclui os avisos dos pacotes Python em `usr/share/doc/caeser/licenses/`.
