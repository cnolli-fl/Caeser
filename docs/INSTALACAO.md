# Instalar o Caeser

Esta edição requer macOS 26 ou mais recente e um Mac com chip Apple (M1 ou posterior).
Não funciona em Windows, Linux nem em Macs Intel. Não depende de Rosetta.

## Instalação

1. Abra o arquivo `.dmg` e arraste Caeser para Aplicativos.
2. Ejete a imagem de disco e abra Caeser na pasta Aplicativos.
3. Cole um link, escolha a pasta de destino e baixe.

Se usar o `.zip`, descompacte e mova Caeser.app para Aplicativos. Não separe os
arquivos que ficam dentro de Caeser.app.

O instalador também contém **Como abrir o Caeser.html**: abra esse guia no navegador
se a primeira abertura for bloqueada. Ele não executa comandos nem altera o sistema.

yt-dlp, FFmpeg, FFprobe, Deno e o suporte ao Spotify já vêm incluídos. Não é preciso
instalar Homebrew, Python, Xcode, Spotify ou outras ferramentas para usar o app.
Internet continua necessária para obter os vídeos, músicas e metadados.

O aplicativo mantém apenas os arquivos de execução e os avisos necessários
dentro de Caeser.app. A interface usa português brasileiro. Um pequeno catálogo
inglês interno do parser de metadados e os textos originais das licenças são
preservados; não são opções de idioma da interface. Não remova bibliotecas de
Tools/Lib: são compartilhadas por FFmpeg e FFprobe.

## Primeira abertura e segurança

Esta é uma distribuição gratuita com assinatura local (ad-hoc), sem certificado
Developer ID e sem notarização da Apple. O macOS pode impedir a primeira abertura
porque não consegue verificar o desenvolvedor. A assinatura local verifica a
integridade do pacote, mas não comprova a identidade do autor perante a Apple.
Publicar outra versão com a mesma assinatura local não elimina esse alerta.

Somente se você confia na origem e no arquivo: após tentar abri-lo, consulte
Ajustes do Sistema > Privacidade e Segurança e a opção “Abrir Mesmo Assim”. Não
desative as proteções globais do macOS. Macs gerenciados por empresas ou escolas
podem não permitir essa autorização. Não ignore alertas de malware ou de arquivo
adulterado: nesses casos, não execute o app e confira a origem do download.

Orientação oficial: https://support.apple.com/pt-br/102445

## Novidades depois de atualizar

A partir da 3.1.1, a janela **O que mudou** aparece na primeira abertura de cada
versão nova, inclusive sem internet. Feche com **Continuar**, Command-W ou o botão
da janela. Não volta a aparecer automaticamente na mesma versão. Para consultar
depois, use **Caeser > Novidades desta versão…**. A janela é independente e não
bloqueia os downloads, nem modifica sua fila, histórico ou preferências existentes.

## Spotify

O link do Spotify serve para identificar as faixas. O áudio é procurado no YouTube
Music/YouTube e convertido em MP3; não é baixado diretamente dos servidores de
áudio do Spotify. Não é necessário login no fluxo padrão de links públicos.

## Atualizações e licenças

O menu **Caeser > Verificar atualizações…** avisa sobre releases novas para Mac.
A substituição do aplicativo continua manual: feche o Caeser e arraste a nova
cópia para Aplicativos. As ferramentas ficam dentro do pacote; `brew upgrade`
não atualiza as ferramentas desta edição.

As licenças acompanham Caeser.app, agrupadas em Contents/Resources/Tools/Licenses.zip;
basta descompactar esse arquivo para ler os textos originais.
Os fontes de FFmpeg/LAME e as receitas das ferramentas ficam em um ZIP separado
na [área de fontes de terceiros](https://github.com/cnolli-fl/Caeser/releases/tag/fontes-terceiros),
com o link correspondente nas notas de cada release.
Você não precisa baixar esse arquivo para usar o app. O código Swift do Caeser é MIT. Use os downloads conforme
as permissões do conteúdo e dos serviços; o app não contorna DRM.
