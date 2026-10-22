# Caeser 3.0.0 — validação das novas funções para Mac

Implementado em 22/10/2026 e aprovado pelo usuário no candidato local 2.2.0. Publicação autorizada como 3.0.0. Windows permanece na versão 1.1.2.

## Novidades

- Prévia automática após colar um link: título, autor, capa e duração quando disponíveis. Consultas antigas são canceladas ao mudar o link.
- Spotify: consulta metadados sem login; músicas individuais mostram a correspondência no YouTube e permitem abri-la no navegador. O download usa a mesma URL apresentada. Álbuns e playlists mostram os dados da coleção e procuram as correspondências durante o download.
- Fila serial: até 50 links por entrada e 100 pendentes, inclusive origens misturadas. Cada item conserva suas opções e pasta. Permite ordenar/remover os pendentes, cancelar o atual e pausar a fila após o atual terminar. Uma falha não bloqueia os seguintes.
- Fila e histórico persistentes; reabrir o app restaura os pendentes pausados e identifica os interrompidos. Os últimos 100 registros permitem mostrar a pasta/arquivo e repetir a tentativa. Limpar histórico não apaga arquivos.
- Preferências de formato, qualidade e destino por origem; compatibilidade com a pasta salva anteriormente.
- Consulta pública das releases do próprio repositório no início, ao voltar ao app e a cada seis horas. Só versões estáveis mais novas com instalador Mac válido são oferecidas. Releases Windows, fontes e pré-releases são ignoradas. Falhas de rede não interrompem downloads.
- Botão Atualizar aparece quando há atualização. Abre uma apresentação com novidades e download do instalador oficial; a instalação continua manual. Não substitui o app em execução. Versões antigas precisam instalar esta versão uma vez para ganhar o aviso.

## Design preservado

Aplicada a skill Apple Design: `layout.md › Visual hierarchy` recomenda “Use progressive disclosure”; a fila aparece somente com itens, histórico fica numa folha e logs continuam recolhidos. `liquid-glass.md › The two layers` orienta manter vidro nos controles: prévia e filas usam superfícies de conteúdo. Mantidos logo original, marcas oficiais, seletor animado violeta, cores semânticas, SF Symbols e tipografia do sistema.

Não foi criada outra paleta: continuam o violeta #7445C4 na seleção e as cores dinâmicas existentes. Marca de 30 pt, títulos de seção 17/15 pt, conteúdo 13 pt e apoio 12 pt. Controles pequenos têm região de 28 pt e rótulos acessíveis. Animações existentes respeitam Reduzir Movimento; novas linhas não têm animação decorativa.

```text
Caeser                      [Histórico] [Atualizar*] [Baixar]
  logo e apresentação originais
  Novo download
    YouTube | Spotify
    Link + Colar
    prévia contextual (se houver um link)
    opções e pasta originais
  Fila (se houver itens): progresso + pendentes + Pausar
  Detalhes e ferramentas recolhidos
```

*Atualizar aparece somente quando uma versão nova é encontrada. O mesmo fluxo funciona na largura mínima de 640 pt, com rolagem e quatro itens visíveis por padrão.

## Verificações realizadas

- 32 testes automatizados offline: validação e origens misturadas, MP3 de qualidade máxima, correspondência Spotify fixa, metadados incompletos, URLs de atualização, comparação numérica de versões, cancelamento, sequência após erro, pausa, remoção, duplicados, restauração, histórico e resposta de prévia atrasada.
- Um teste adicional de integração com ferramentas reais: servidor local com dois áudios AAC gerados; prévia real e dois downloads sequenciais convertidos para MP3, com caminhos finais e arquivos não vazios. Usa pasta com acento e preferências isoladas.
- Interface aberta no Mac: prévia real do vídeo público “Me at the zoo”; colagem de dois links locais, seleção de pasta e MP3, fila e conclusão visíveis. Histórico vazio conferido.
- Spotify real: `save --preload` identificou “Never Gonna Give You Up” e retornou uma URL correspondente do YouTube, sem baixar áudio e sem login.
- Corrigida dependência de empacotamento: o provedor do spotDL constrói `YTMusic(language="de")`. Preservado esse pequeno catálogo interno além de pt/en; o app permanece em português. Novo `--caeser-runtime-check` testa os construtores sem rede e faz parte da verificação de distribuição.

Para repetir o teste opcional de integração, sirva dois arquivos gerados em `/primeiro.m4a` e `/segundo.m4a` num servidor local e execute:

```sh
CAESER_INTEGRATION_TOOLS=/caminho/Tools \
CAESER_INTEGRATION_URL=http://127.0.0.1:PORTA \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter DesktopIntegrationTests
```

A verificação com uma release futura usa respostas simuladas nos testes, sem publicar versões falsas. O funcionamento completo de VoiceOver e todos os limites de coleções grandes/privadas não foram verificados ao vivo. Prévias e correspondências dependem da disponibilidade dos serviços; falhar a prévia não impede adicionar à fila.
