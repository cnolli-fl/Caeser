# Fidelidade visual do port Windows

A tela continua sendo o Caeser 2.1.0 aprovado, não uma proposta de redesign. A referência é a [captura original](../docs/images/caeser-interface.png).

## Decisões implementadas

- Mesmo cabeçalho, formulário único, marca original de 68 × 68 unidades, título de 30, margem de 32, cartão com 24 internos e cantos de 20.
- Mesmo seletor de 40 unidades, duas metades iguais e destaque #7445C4, com movimento de até 280 ms, clique, arraste e teclado. A fonte de cor vem do código SwiftUI existente.
- As imagens são vinculadas aos mesmos arquivos do Mac. O ícone ICO só encapsula cinco PNGs já existentes; não há recriação de nenhuma logo.
- Tema claro/escuro segue o sistema. Alto contraste substitui os tons de marca pelas cores semânticas do Windows. A preferência de animações do Windows desliga o deslizamento.
- Logs ficam recolhidos; erros e progresso aparecem junto do formulário. A ação principal permanece no topo.
- Controles de janela, fonte, seleção de pasta e ícones de ações usam Windows. SF Symbols e fontes Apple não são incluídos.
- Esta implementação usa superfícies de conteúdo opacas; não apresenta uma imitação como Liquid Glass nativo.

## Tokens

| Papel | Claro | Escuro |
| --- | --- | --- |
| Fundo | #F5F5F5 | #202020 |
| Conteúdo | #FFFFFF | #222222 |
| Texto | #1C1C1E | #F2F2F7 |
| Texto secundário | #59595C | #B5B5BA |
| Seleção | #7445C4 | #7445C4 |
| Texto da seleção | #FFFFFF | #FFFFFF |

Tipografia do Windows, sem redistribuir fontes: título 30 bold, seção 17 semibold, corpo/controles 14, ajuda 13, registro Consolas 12. Contrastes de referência devem ser medidos no teste; não inferir conformidade de todos os controles a partir de uma captura.

## Aplicação da skill apple-design

Usada para preservar hierarquia e interação, não para impor convenções de macOS ao Windows:

- layout.md › Visual hierarchy: “Use progressive disclosure” — manter os detalhes recolhíveis.
- accessibility.md › Mobility: “Offer alternatives to gestures” — clique e teclado além do arraste.
- motion.md › Best practices: “Make motion optional” — consultar a preferência de animações do Windows.
- liquid-glass.md › Where the material belongs: “Don't use Liquid Glass in the content layer” — preservar a separação entre conteúdo e ações.
- typography.md › Using system fonts: “don’t embed system fonts” — usar a fonte da plataforma.

Foram lidas também as referências de acessibilidade, cor, layout, tipografia, design para macOS, tradução entre plataformas e auditoria de código. As convenções específicas de menu e botões do Mac não são requisitos do Windows.

## Verificação

O teste de interface abre o aplicativo no runner Windows, alterna YouTube/Spotify e claro/escuro e captura o XAML realmente renderizado. Envia cliques reais do mouse, incluindo hover, trocas rápidas durante animação e seleção por automação de acessibilidade. Testa também movimento reduzido, URL inválida, foco por teclado, contraste e limites horizontais dos controles. Isso não comprova sozinho leitura por Narrator, alto contraste ao vivo, arraste, todas as escalas DPI nem funcionamento em Windows 10; esses limites de validação precisam ser informados nas releases.

O crash de troca de origem foi reproduzido com entrada do mouse: a chave inexistente ControlSubtleFillColorSecondaryBrush era resolvida somente ao entrar no estado PointerOver. Ela foi substituída por SubtleFillColorSecondaryBrush, presente no tema oficial WinUI. A seleção usa RadioButton nativo com o mesmo visual, sem restaurar IsChecked dentro do evento Unchecked, e apenas mudanças reais notificam o formulário. Layout não emite eventos de seleção. A animação continua interrompível e pode ser desligada pela preferência do sistema.
