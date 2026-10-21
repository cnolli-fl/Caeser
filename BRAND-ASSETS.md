# Marcas de YouTube e Spotify

Os ícones identificam as opções de origem. Não fazem parte da marca ou do ícone do Caeser e não indicam afiliação, certificação ou endosso dos serviços.

## Fontes oficiais

- **YouTube:** [YouTube Icon](https://brand.youtube/youtube-icon/), pacote [Core YouTube icon](https://www.gstatic.com/marketing-cms/78/29/3e68a1414bb28d0b7e47b44c3c91/youtube-icon.zip), consultado em 21/10/2026. A fonte agora é o PDF vetorial oficial `YouTube_Icon/Print/03 White/yt_icon_white_cymk.pdf`, preservado em `Design/BrandSources/YouTubeMark.pdf`. A caixa ArtBox fornecida pelo próprio arquivo delimita a marca, sem cortar suas curvas.
- **Spotify:** [Design & Branding Guidelines](https://developer.spotify.com/documentation/design#using-our-logo), pacote oficial [Download Icon](https://developer.spotify.com/images/guidelines/design/2024-spotify-logo-icon.zip), consultado em 21/10/2026. A fonte é `Primary_Logo_White_RGB.svg`, convertido para `Design/BrandSources/SpotifyMark.pdf` com `rsvg-convert -f pdf`, sem rasterizar ou alterar os caminhos e proporções.

Os PNGs ficam em `Sources/VideoDownloader/Resources` e são incluídos tanto no projeto Xcode quanto no pacote Swift. Não dependem de carregamento pela rede durante o uso. As fontes vetoriais e o gerador são materiais de desenvolvimento; não acrescentam ferramentas externas ao app.

## Apresentação

`SourceBrandIcon` reserva 36 × 24 pt. As curvas originais são desenhadas diretamente pelo Core Graphics em três PNGs transparentes para cada marca: 36 × 24 px (1×), 72 × 48 px (2×) e 108 × 72 px (3×). O círculo do Spotify ocupa até 24 × 24 pt; o YouTube ocupa até 26 pt de largura, mantendo sua proporção. Apenas o excesso de margens transparentes é normalizado; não há deformação, redesenho, glow, sharpening ou alteração dos cantos das marcas.

O app lê `displayScale`, escolhe o PNG correspondente e informa sua escala ao SwiftUI. A imagem não usa `resizable()` nem precisa reduzir um bitmap de mais de 1000 pixels durante a exibição. `interpolation(.none)` evita uma segunda filtragem desses pixels já preparados no tamanho final; o antialiasing das curvas é feito na exportação. A imagem-template acompanha a cor do texto: branco no segmento roxo ou na aparência escura, e escuro nos fundos claros. Os nomes permanecem visíveis ao lado, inclusive para acessibilidade; SF Symbols continuam sendo usados para ações como baixar, colar e escolher pasta.

Para regenerar os seis PNGs, execute na raiz do projeto, com o Swift do Xcode:

```bash
swift Scripts/GenerateBrandIcons.swift
```

O gerador usa apenas Core Graphics e ImageIO, já fornecidos pelo macOS. O teste verifica as dimensões das três escalas, transparência, bordas com antialiasing e proporção circular do Spotify.

A licença do código do Caeser não transfere direitos sobre essas marcas. Consulte as diretrizes dos respectivos titulares antes de distribuir os materiais.
