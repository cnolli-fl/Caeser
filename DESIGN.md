# Ícone macOS ativo — formato Icon Composer

A moldura cinza relatada pelo usuário era a apresentação do ícone legado no macOS Tahoe. `CaeserApp.icon` define um fundo azul sólido opaco e inclui a arte anterior `CaeserIconLargeNote.png`, sem alterar a marca interna. O projeto passa a compilar esse pacote como ícone principal (`CFBundleIconName = CaeserApp`). Sombras e translucidez do grupo desativadas. O recorte final fica a cargo do macOS. Validado por compilação Xcode e prévia nativa no Finder: sem a moldura cinza grossa.

---

# Marca ativa — restaura nota anterior e limpa bordas do AppIcon

O usuário rejeitou as hastes grossas. Marca interna restaurada exatamente de `CaeserIconLargeNote.png`. O AppIcon usa `CaeserIconCleanEdges.png`, derivado da mesma nota anterior com limpeza do contorno e exterior transparente para remover franjas.

---

# Marca ativa — hastes mais grossas e bases redondas

`CaeserIconBoldNote.png` engrossa as duas hastes e arredonda mais as bases da nota branca. Mantém tamanho amplo, fundo azul e contorno macOS. Aplicado à marca interna e ao AppIcon.

---

# Marca ativa — nota maior e bases arredondadas

`CaeserIconLargeNote.png` aumenta a nota branca e arredonda as duas bases conforme a referência do usuário. Mantém hastes retas e o contorno macOS. Aplicado à marca interna e ao AppIcon.

---

# Marca ativa — formato macOS e nota mais reta

Correção do pedido: o usuário queria a nota musical mais quadradinha, não os cantos do fundo. `CaeserIconStraightNote.png` restaura o formato arredondado de ícone macOS e usa hastes finas e retas, junções mais definidas e nota branca sobre azul. Aplicado ao cabeçalho e ao AppIcon.

---

# Marca ativa — nota branca e cantos discretos

O usuário escolheu a nota branca e pediu um ícone menos arredondado. `CaeserIconWhiteSquare.png` usa cantos pequenos, aproximadamente 6% da largura, e substitui a marca interna e os tamanhos do AppIcon. O recorte do cabeçalho acompanha os cantos menores.

---

# Marca ativa — azul da interface

`CaeserIconRoyalBlue.png` mantém a nota branca e troca o fundo claro da marca pelo azul profundo da interface. Aplicado ao cabeçalho e a todos os tamanhos do ícone do aplicativo.

---

# Ajuste ativo — azul da referência

O usuário forneceu a amostra azul #0D2666. Fundo e formulário usam esse tom sólido, sem painel branco nem iluminação ciano. Campos e trilho em #244580, bordas #6086BB, texto auxiliar #CFDFF5 e ações #94D2FF. Aparência escura dos controles nativos permite texto claro. Mantém a nota branca sobre azul e o download em uma ação.

---

# Ajuste ativo — superfícies azuis contínuas

Pedido: remover o grande painel branco e ajustar novamente o tom de azul. Fundo e formulário compartilham #53ADE2; agrupamento por espaçamento e borda #287DB4, sem cartão branco. O campo de link e o trilho usam azul mais claro #85C9EF. Texto auxiliar #173D59 e ações #004775 preservam leitura sobre o azul. A nota musical azul e branca permanece.

---

# Ajuste ativo — azul-céu médio e nota musical

O usuário escolheu retornar ao símbolo musical original, em azul e branco e sem neon. `CaeserIconBlueWhite.png` substitui o mascote tanto no cabeçalho quanto nos tamanhos do AppIcon. Nota branca com profundidade suave, bloco azul arredondado e margem transparente.

O fundo passa a #86C6EA: azul-céu com presença, mantendo os formulários brancos e as ações azuis. Texto auxiliar #34495E para leitura sobre o céu azul e sobre branco. Aparência clara permanece restrita ao aplicativo.

---

# Revisão Aero claro — 26/10/2026

O usuário pediu um aplicativo claro, leve e alegre, com uma marca minimalista Frutiger Aero. A versão de teste usa aparência clara explícita somente dentro do Caeser, inclusive nos controles nativos e no histórico; não altera a preferência do macOS.

- Fundo azul-céu muito claro #E6F5FF; conteúdo branco #FFFFFF.
- Ações azul #0064B5; trilho #E1EFF9; borda #8EB6D0; iluminação aqua #63D5E9.
- Texto e controles preservam estilos semânticos do macOS. Ações sobre branco têm contraste de 6,02:1.
- Marca `CaeserIconAeroMinimal.png`: busto geométrico de cabeça circular e ombros, ciano claro sobre quadrado azul, sombreado suave. Substitui os bonecos de vidro excessivamente refletivos. Fonte usada pela logo interna e pelos dez tamanhos do AppIcon.
- Mantém o download em uma ação e os demais fluxos existentes.

As versões anteriores abaixo são registro histórico, não a especificação ativa.

---

# Experimento Ocean Blue — branch codex/ocean-blue

Direção solicitada: azul oceano vivo, limpo, com uma lembrança discreta de Frutiger Aero. Mantém a composição e os controles nativos. A seleção recebe um gradiente vertical azul com um reflexo fino; o fundo tem iluminação ciano discreta. A identidade experimental usa um bonequinho azul translúcido, inspirado na referência Frutiger Aero fornecida pelo usuário: cabeça esférica sem rosto, corpo arredondado e dois braços simples. Após testar a versão solta, o usuário pediu um quadrado como o ícone antigo. `CaeserMascotTileOcean.png` agora coloca o bonequinho claro sobre um bloco arredondado azul/turquesa, com reflexos simplificados e margem transparente externa; alimenta a logo interna e os tamanhos do AppIcon. As notas musicais anteriores permanecem guardadas como fontes históricas.

Paleta `OceanPalette`, compartilhada com as folhas:

| Papel | Claro | Escuro |
| --- | --- | --- |
| Fundo | #EDF6FC | #101E2B |
| Conteúdo | #FFFFFF | #172B3C |
| Ações | #0064B5 | #42AEFF |
| Trilho da seleção | #E1EDF6 | #102332 |
| Bordas | #9BBACF | #52778F |

O texto permanece semântico, com as adaptações de acessibilidade do macOS. Reduzir Transparência remove a iluminação ambiente; Aumentar Contraste reforça as bordas. A seleção usa branco sobre os extremos #056EBD e #004F99 (ambos acima de 4,5:1).

Ao iniciar um novo download válido, a fila é retomada automaticamente. Links inválidos e envios compostos apenas por duplicatas não retomam uma fila pausada. Abrir o aplicativo ainda não inicia downloads; pausa explícita continua deixando o item atual terminar. A ação passa a dizer “Baixar e continuar fila”, “Adicionar e baixar” ou “Baixar todos”, conforme o contexto.

Validação: compilação Debug arm64 concluída; suíte com 36 testes, sendo 35 aprovados e 1 teste de rede optativo não executado. A aparência escura foi conferida no aplicativo separado Caeser Ocean. O tema claro está implementado, mas ainda não foi conferido na interface ao vivo.

---

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
