# Caeser — direção visual 2.1.0

Utilitário macOS em SwiftUI. A tela tem um trabalho: levar um link até um arquivo local com a origem e o andamento claros. A identidade permanece na nota musical original e em um único destaque violeta; o restante usa os componentes do Mac. A imagem neon enviada pelo usuário foi preservada tanto no ícone quanto no cabeçalho: a revisão melhora a apresentação, sem redesenhar a marca.

## Revisão e decisões

- **High, materiais:** quatro superfícies de conteúdo recebiam `glassEffect`. Substituídas por superfícies de conteúdo, mantendo `.glassProminent` na ação principal. Referência: `materials.md › Liquid Glass`, “Don't use Liquid Glass in the content layer”.
- **Medium, hierarquia:** registro técnico sempre aberto competia com o formulário. Passou a um `DisclosureGroup`. Referência: `layout.md › Visual hierarchy`, “Use progressive disclosure”.
- **Medium, aparência:** `.preferredColorScheme(.dark)` impedia seguir o sistema. Removida; cores semânticas e fundo adaptativo. Referência: `color.md › Best practices`.
- **Medium, ações:** baixar no rodapé da janela dificultava o acesso em janelas parcialmente fora da tela. Ação movida para a toolbar, com comandos equivalentes no menu Downloads. Referências: `layout.md › Desktop (macOS)` e `designing-for-macos.md › Best practices`.
- **Medium, texto:** explicações repetidas e o selo Áudio competiam com as escolhas do formulário. Removido o selo e reduzidos os textos do Spotify, mantendo explícita a origem no YouTube e a possibilidade de outra versão. Referência: `writing.md › Getting started`, “If you can use fewer words, do so.”
- **Medium, recuperação:** a ação principal agora indica Tentar novamente após um erro, desde que as ferramentas estejam disponíveis; símbolo e texto acompanham a cor de erro. Referências: `writing.md › Best practices`, “Be action oriented”, e `accessibility.md › Best practices`.
- **Medium, clareza da ação:** a toolbar ocultava o título e mostrava só a seta. O botão agora pede `.labelStyle(.titleAndIcon)` para manter Baixar, Baixar MP3, Tentar novamente ou Cancelar visíveis junto ao símbolo. Referência: `writing.md › Best practices`, “Active voice and clear labels help people navigate”.
- **Low, destino:** exibir só o nome final da pasta deixava destinos de mesmo nome ambíguos. O caminho abreviado fica visível; tooltip e VoiceOver mantêm o caminho completo. Julgamento de usabilidade desta revisão.
- **Preservar:** imagem e ícone originais do aplicativo, seleção nativa de pasta, SwiftUI e Liquid Glass nativo do macOS 26. Referência: `branding.md › Best practices`, “Express your brand with familiar components.”

## Sistema visual

As cores de superfície e texto usam NSColor/ShapeStyle semânticos; os valores abaixo são referências aproximadas para revisar as aparências, não substituem as cores dinâmicas do sistema.

| Papel | Claro | Escuro | Contraste de referência |
| --- | --- | --- | --- |
| Fundo | #F5F5F5 | #202020 | — |
| Superfície | #FFFFFF | #292929 | — |
| Texto | #1C1C1E | #F2F2F7 | 17.01:1 / 13.04:1 contra superfície |
| Texto secundário | #59595C | #B5B5BA | 6.98:1 / 7.12:1 contra superfície |
| Ação | roxo do sistema | roxo do sistema | fornecido pelo estilo nativo, sujeito a aparência e contraste |

Tipografia: SF do sistema, marca em SF Rounded 30 pt bold; título de seção `.title2`; controles e conteúdo `.body` (13 pt no Mac); ajuda `.callout` (12 pt); registro em SF Mono 12 pt. Conteúdo até 800 pt, margem 32 pt, espaçamento entre seções 26 pt, formulário com 24 pt internos. Símbolos SF com título acessível.

## Composição

Janela de 640 pt até larguras maiores; o formulário mantém uma coluna. A janela inicial mede 820 × 760 pt. Controles permanecem no topo, e só o registro fica mais alto quando aberto.

```text
compacta                         regular
┌ Caeser ─────────── [Baixar] ┐   ┌ Caeser ───────────────── [Baixar] ┐
│ ícone  Caeser              │   │    ícone  Caeser                   │
│ ┌ Novo download ─────────┐ │   │    ┌ Novo download ────────────┐   │
│ │ [YouTube | Spotify]   │ │   │    │ [ YouTube | Spotify ]     │   │
│ │ Link           Colar   │ │   │    │ Link                Colar │   │
│ │ [                    ]│ │   │    │ [                       ] │   │
│ │ opções / origem áudio │ │   │    │ opções / origem do áudio  │   │
│ │ Salvar em    Alterar… │ │   │    │ Salvar em         Alterar… │   │
│ └───────────────────────┘ │   │    └────────────────────────────┘   │
│ andamento / erro          │   │    andamento / erro                 │
│ ▸ Detalhes e ferramentas  │   │    ▸ Detalhes e ferramentas         │
└───────────────────────────┘   └─────────────────────────────────────┘
```

O seletor de origem tem dois segmentos iguais e 40 pt de altura. Um indicador roxo desliza entre YouTube e Spotify em aproximadamente 0,28 s; ao arrastar, acompanha o ponteiro sem atraso. Soltar ou cancelar o gesto devolve o indicador a uma seleção válida. Os botões permanecem acessíveis por teclado e anunciam a opção selecionada. A transição de conteúdo usa uma dissolução de 0,18 s. É uma escolha de interação solicitada pelo usuário; os demais controles continuam nativos.

Com Reduzir Movimento, mudanças de seleção e rolagem são imediatas. Reduzir Transparência remove a cor de fundo translúcida e o brilho ambiente. Aumento de Contraste reforça as bordas de separação. Os controles e a toolbar deixam o sistema adaptar o vidro.

A marca interna carrega o PNG original de 1254 × 1254 pixels por `NSImage`, com `Image.resizable()`, `.interpolation(.high)` e proporção preservada. O arquivo do recurso é uma cópia byte a byte de `CaeserIconOriginal.png`, não uma reconstrução em SVG. A exibição de 68 pt precisa de apenas 136 pixels em uma tela 2×; a fonte original já tem resolução de sobra. Não há ampliação artificial ou promessa de detalhes ausentes no original. O ícone do aplicativo permanece inalterado.

Os dois serviços usam suas marcas oficiais monocromáticas em PNG transparente, não SF Symbols genéricos. O seletor e a indicação Spotify → YouTube compartilham `SourceBrandIcon`, com área de alinhamento de 36 × 24 pt e cor acompanhando o texto. Após o usuário notar suavidade excessiva, os bitmaps grandes deram lugar a versões 1×, 2× e 3× desenhadas diretamente das curvas vetoriais no tamanho final. A imagem informa sua escala ao SwiftUI e não usa `resizable()`; assim, uma tela 2× recebe exatamente 72 × 48 pixels para o mesmo espaço de 36 × 24 pt. O círculo do Spotify tem até 24 pt de diâmetro, e o YouTube até 26 pt de largura, sem mudar seus cantos ou sua proporção. Referência: `icons.md › Best practices`, “Maintain visual consistency across all interface icons”; os PNGs seguem a preferência explícita do usuário, preservando as fontes vetoriais para regeneração. As fontes e a conversão estão em [BRAND-ASSETS.md](BRAND-ASSETS.md).

Referências da skill: `accessibility.md`, `layout.md`, `typography.md`, `color.md`, `designing-for-macos.md`, `text-fields.md`, `progress-indicators.md`, `materials.md`, `liquid-glass.md`, `buttons.md` e `code-audit.md`; nesta revisão incremental, `branding.md` e `writing.md`. Revisão de código não comprova, por si só, contraste do vidro em todas as situações nem funcionamento completo do VoiceOver.

## Verificação desta atualização

- Compilação do aplicativo com Xcode 26.6, para macOS arm64.
- 15 testes automatizados passando; incluem cancelamento de subprocessos, preservação de saída UTF-8, escolha da escala Retina e carregamento das marcas em 1×, 2× e 3×, com transparência, antialiasing e círculo sem deformação.
- Busca real a partir de um link público do Spotify e download completo via spotDL 4.5.2, sem login. MP3 com título, artista, álbum e capa; relatório de erros vazio.
- Aplicativo aberto e inspecionado na aparência escura: logo original, formulário, pasta de destino, títulos da ação principal e alternância para Spotify confirmados pela interface e pela árvore de acessibilidade. Um link inválido apresentou a orientação de correção e Tentar novamente, sem iniciar download; o campo foi limpo após o teste. A aparência clara, o VoiceOver completo e a experiência com playlists privadas ou grandes não foram confirmados ao vivo.
- Interface aprovada pelo usuário; atualização identificada como 2.1.0.
