# Validação local do Mac 3.1.1 — 28/10/2026

Validação realizada antes da publicação autorizada pelo usuário. Código validado: `7d73421`; base: `origin/main` em `193c45a` (Mac 3.1.0). Os ajustes posteriores para publicação são apenas de documentação.

## Segurança e primeira abertura

- Download do DMG oficial 3.1.0 conferido: SHA-256 `7e43bca3f04fd4f27026c7143bd392a063e191c9f62b6284bc23c26d8c06b091`, igual ao asset publicado.
- Montagem somente para leitura, assinatura profunda válida e assinatura ad-hoc confirmadas; `spctl --assess` rejeita a distribuição. Não há Developer ID configurado nem notarização nesta edição. Integridade não é prova de ausência de malware.
- Nenhuma proteção global alterada, nenhuma quarentena removida e nenhum alerta de malware ignorado.
- Incluído guia HTML estático, sem scripts nem comandos, com a autorização individual documentada pela Apple e ressalvas para alertas de malware/adulteração.

## Novidades

- Suíte Swift reporta 43 testes, um de integração opcional não habilitado e zero falhas. Os sete novos testes cobrem primeira abertura, persistência entre sessões, atualização, downgrade, apresentação manual, preservação de dados, versão desconhecida/inválida e tamanho da janela.
- Build Debug e Release arm64 pelo projeto Xcode aprovados; versão 3.1.1, build 8, mesma identificação `com.example.Caeser`.
- Conferência visual real: janela de novidades com o ícone aprovado, três itens, texto legível e sem cortes; botão Continuar, Return e reabertura pelo menu funcionam. Após encerrar/reabrir, somente a janela principal aparece. A marca de versão criada pelo teste foi removida para não consumir a primeira abertura real do usuário.
- Janela não modal, notas locais, sem dependência de rede para exibir as novidades. Restauração automática desta janela desativada. Não há redesign da janela principal.
- Aplicada a skill Apple Design: hierarquia curta, tipografia do sistema, SF Symbols, controles nativos e janela independente para não bloquear o trabalho.

## Distribuição

- Ferramentas reutilizadas do cache da release 3.1.0, com manifesto idêntico ao pacote publicado. Sem atualização de ferramentas.
- Assinaturas, arquiteturas, bibliotecas internas, manifesto SHA-256, licenças, extratores, catálogos e runtimes aprovados pelo verificador do pacote, em ambiente isolado sem Homebrew/configuração do usuário.
- Download de áudio original servido em loopback e conversão MP3: sucesso, 10.751 bytes, caminho com espaços e acentos. Não é um teste de disponibilidade dos serviços externos.
- DMG final montado somente para leitura; assinatura profunda válida, versão/build e conteúdo dos dois guias conferidos contra os fontes.
- Instalador: **105.702.461 bytes**. SHA-256: `ee1c74a0152dcff785900f7a3a1fc37ca8be25fd6f50ab3193cab652d06730f1`.
- Windows sem alterações. Sem instalação por cima da cópia do usuário. A publicação posterior não altera o binário validado.

Limite: a 3.1.1 continua com assinatura local, sem Developer ID e sem notarização; o alerta de verificação da Apple pode continuar. Não foi testada a autorização manual em outra máquina nem executado um antivírus de terceiros.
