# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Site: [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** é um assistente de escrita para macOS que transforma o que você digita, cola ou fala em um texto claro, sem sair do app que você já está usando.

Abra o popover de escrita com o atalho global e digite, cole ou dite no mesmo rascunho de origem editável. O ditado em tempo real fica dentro do Assistente de escrita, para que você revise a transcrição antes de decidir se vai transformá-la ou inseri-la. Em Macs com Apple Silicon, as novas instalações reconhecem a fala no próprio Mac, então sua voz nunca sai dele.

> Este documento é uma tradução do [README.md](README.md) em inglês. Em caso de divergência, vale a versão em inglês.

## Demonstração

Assista ao vídeo de demonstração: [Inklet no YouTube](https://www.youtube.com/watch?v=F5wmFruo0a4).

## Instalação

O GitHub Releases é o único canal de distribuição oficial do Inklet. Baixe o DMG mais recente, assinado e notarizado, em [GitHub Releases](https://github.com/wanming/Inklet/releases), abra-o e copie o Inklet para `/Applications`.

Você também pode usar o script de instalação abaixo. Ele baixa o DMG e o checksum mais recentes do GitHub Releases, verifica a estrutura do DMG, o checksum, a aceitação do Gatekeeper, o identificador do bundle, o Hardened Runtime, os entitlements efetivos e a assinatura do app, e depois copia o Inklet para `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Atualizações

O Inklet usa o GitHub Releases como única fonte de atualizações. As versões de produção consultam no GitHub os metadados públicos da versão estável mais recente cerca de uma vez a cada 24 horas. Uma atualização só é anunciada depois que essa versão tem um `Inklet.dmg` enviado; **Ver no GitHub** abre a página exata dessa versão. O Inklet nunca baixa nem instala atualizações automaticamente.

Use **Buscar atualizações…** no menu do app para verificar manualmente, tanto no app de produção quanto no Inklet Local. O Inklet Local nunca agenda verificações automáticas. Falhas nas verificações automáticas são silenciosas, enquanto uma verificação manual oferece **Tentar novamente**. Se escrita, ditado, ações de seleção, migração, uma janela modal ou um menu aberto deixarem o Inklet ocupado, o aviso automático de atualização espera até o app ficar ocioso.

Depois de atualizar, a primeira abertura da nova versão mostra uma vez uma janela curta de **Novidades**, quando o Inklet está ocioso e sem tirar o foco do app que você está usando. Ela não aparece em uma instalação nova nem enquanto o guia de boas-vindas está aberto. **Histórico de alterações**, no menu da barra de menus, lista todas as versões e destaca a que você está usando.

## Configuração inicial

1. Abra o Inklet pela pasta Aplicativos. Para uma compilação a partir do código-fonte, execute `scripts/run-local-app.sh` na raiz do repositório e use `/Applications/Inklet Local.app`.
2. Clique no ícone do Inklet na barra de menus e abra **Ajustes**.
3. Conceda a permissão de Acessibilidade quando o macOS pedir. O Inklet usa essa única permissão genérica para ler seleções, executar o método alternativo de cópia configurado, devolver o foco ao app anterior e colar os resultados confirmados. O Inklet fica em segundo plano enquanto os Ajustes do Sistema estão abertos e volta aos ajustes **Geral** quando você os fecha.
4. Em uma instalação nova, e uma vez depois de atualizar para esta versão, um guia de boas-vindas passa pelo idioma da interface (instalações novas seguem o idioma do sistema), Acessibilidade, o modelo de escrita, o microfone do Ditado em tempo real e os atalhos para abrir o Inklet e ditar. No Apple Silicon, ele sugere **Integrado** com o modelo recomendado e o baixa em segundo plano se você mantiver essa opção; o popover de escrita mostra o progresso e funciona offline quando o download termina. Para usar um provedor na nuvem, escolha-o em **Geral** e insira a chave de API dele. Com a OpenAI, o padrão em Macs Intel, uma única chave cobre escrita, ditado em tempo real, tradução da seleção e pronúncia. Com qualquer outro provedor, a escrita e a tradução da seleção usam esse provedor, enquanto a pronúncia, e o ditado quando você escolhe a OpenAI para ele, ainda precisam de uma chave de API da OpenAI no campo opcional separado. Para executar a escrita e a tradução no seu Mac sem nenhuma chave, escolha **Integrado** e baixe um modelo, ou escolha **Ollama** ou **LM Studio** se você já usa um deles (veja [Modelos locais](#modelos-locais)).
5. Configure o **Assistente de escrita** com o modelo, o atalho de escrita, os ajustes de geração e os modos de prompt que quiser usar. O **Ditado em tempo real** tem sua própria página nos Ajustes: ative ou desative, escolha **Neste Mac** ou **OpenAI** para o reconhecimento de fala e escolha o atalho de manter pressionado e o microfone. No Apple Silicon, as instalações novas usam **Neste Mac**, e o guia de boas-vindas baixa o modelo de fala quando você ativa o ditado nele; as configurações existentes continuam com a OpenAI até você mudar. Com a OpenAI, o **Ditado avançado** mostra apenas o modelo de recuperação; o endpoint de recuperação não é editável. O modelo em tempo real é fixado pelo Inklet.
6. Opcional: configure o **Assistente de seleção** com um idioma de tradução, o modo de **Seleção forçada**, a voz e a velocidade da pronúncia com IA, e ouça uma prévia da voz nos Ajustes.
7. Conceda a permissão de Microfone na primeira vez que mantiver pressionado o atalho de Ditado de forma válida. Abrir o Inklet, visitar os Ajustes ou pressionar o atalho de Ditado fora do editor de origem ativo não a solicita.

## Uso diário

Fluxo de texto:

1. Coloque o foco em qualquer campo de texto de outro app.
2. Pressione `Option+Space`.
3. Faça uma busca aproximada por um modo de prompt (por exemplo, `res` pode encontrar `Resumir`), use `Up` / `Down` para destacá-lo e pressione `Tab` ou `Enter` para confirmar o modo.
4. Digite ou cole o texto bruto.
5. Pressione `Enter` para transformá-lo. O resultado aparece conforme é gerado; pressione `Escape` para parar.
6. Pressione `Enter` de novo para inserir o resultado, ou pressione `Shift+Command+C` (ou clique no botão de copiar do resultado) para copiá-lo.

Fluxo de ditado:

1. **Abra o Assistente de escrita** com `Option+Space`.
2. **Confirme um modo de prompt**. O ditado não está disponível no seletor de modos nem no editor de resultado.
3. **Coloque o cursor no rascunho de origem ou selecione o texto a substituir.** O ditado é inserido no cursor ou substitui a seleção.
4. **Mantenha pressionado o atalho de Ditado configurado** (Option direita por padrão) e fale normalmente enquanto o rascunho é atualizado no lugar. Um toque curto não faz nada. Se a conexão em tempo real falhar, continue pressionando e falando enquanto o Inklet guarda uma gravação temporária de recuperação.
5. **Solte para finalizar** a transcrição. Com **Neste Mac**, a recuperação transcreve a gravação no seu Mac. Com a OpenAI, se a recuperação for necessária, o Inklet envia uma única solicitação para `https://api.openai.com/v1/audio/transcriptions` com a mesma chave de API da OpenAI já usada pelo ditado em tempo real. A gravação temporária fica local até a solicitação alternativa realmente começar, é enviada no máximo uma vez e é apagada quando a sessão termina.
6. Revise e edite o rascunho ditado. O ditado por si só não executa o modo de prompt nem insere texto em outro app.
7. **Pressione Return só quando estiver pronto** para executar o modo de prompt confirmado; pressione Return de novo apenas quando quiser inserir o resultado.

O atalho de Ditado só funciona no editor de origem e só ao ser mantido pressionado. Você pode trocar a tecla modificadora para Command direita, Option esquerda ou Command esquerda, ou desativar o ditado por completo, em **Ajustes** → **Ditado em tempo real**. Escape, perda de foco, fechar o popover ou abrir outra sessão de origem cancelam o ditado e restauram o rascunho original.

## O que ele faz

- Abre com um atalho global do macOS. O padrão é `Option+Space`.
- Transmite o ditado em tempo real para o editor de origem ativo do Assistente de escrita enquanto um atalho de tecla modificadora é mantido pressionado. O padrão é Option direita.
- Mostra as ações de seleção depois que você seleciona texto em outro app do Mac e faz uma breve pausa, com leitura da seleção no estilo do EasyDict, tradução rápida, um prompt de **Traduzir** personalizável, pronúncia com IA, resultados de tradução redimensionáveis que lembram o último tamanho e um cache local de 7 dias para traduções repetidas.
- Ignora textos selecionados com mais de 1.500 caracteres para evitar acionamentos acidentais ao selecionar uma página inteira.
- Reproduz diretamente o texto selecionado e, no resultado da tradução, pode reproduzir tanto o texto original quanto o traduzido.
- Permite escolher quais botões o menu de seleção mostra e em que ordem, em **Ajustes** › **Assistente de seleção** › **Botões do menu**. **Traduzir**, **Pronunciar** e qualquer modo de prompt podem ser um botão; até quatro aparecem ao mesmo tempo e o resto fica em **Mais**. Um botão de modo de prompt executa esse modo no texto selecionado e mostra o resultado no painel com controles de cópia e reprodução.
- Transforma texto com modos de prompt integrados:
  - Para inglês simples e correto (no seu idioma de escrita, escolhido em Ajustes › Geral; inglês por padrão)
  - Resumir (no seu idioma de tradução, que por padrão segue o idioma da interface)
  - Limpeza de voz
- Mostra o resultado no popover conforme é gerado e depois o insere no app que estava em foco ou o copia com o botão de copiar do resultado.
- Usa um único caminho de seleção, independente do app e que prioriza a Acessibilidade. As ações de seleção automáticas pedem primeiro a seleção à Acessibilidade do macOS e só usam o método alternativo configurado de área de transferência temporária quando a **Seleção forçada** permite. Cada leitura fica vinculada ao processo de origem capturado e é cancelada se esse processo terminar ou perder o foco.
- Mantém o `Command+C` simulado desativado por padrão. A cópia pelo menu continua sendo o método alternativo seguro da **Seleção forçada**; você pode ativar explicitamente a cópia simulada como alternativa avançada para apps sem um menu Copiar utilizável, mas ela pode interferir em jogos, áreas de trabalho remotas ou máquinas virtuais.
- Serializa as leituras temporárias da área de transferência e só restaura o estado anterior enquanto a mesma leitura ainda for dona do resultado de cópia observado; o conteúdo mais recente da área de transferência prevalece. O acionamento por cópia dupla é passivo: usa a cópia que o usuário já fez, sem disparar outra cópia sintética nem restaurar dados mais antigos da área de transferência. O clique direito continua nativo e nunca inicia uma leitura da seleção.
- Não usa código de seleção específico para navegadores nem pede permissão de Automação para navegadores. Chrome, Safari, Edge e apps nativos usam o mesmo caminho genérico.
- Permite editar os modos de prompt, o provedor, o modelo, o endpoint personalizado compatível com a OpenAI, o tempo limite, o atalho de escrita, o atalho de manter pressionado do Ditado, o microfone, o modelo de recuperação, o idioma de tradução da seleção, o prompt de **Traduzir** da seleção, os botões do menu de seleção, o modo de **Seleção forçada**, a permissão de cópia simulada, e a voz e a velocidade da pronúncia com IA.
- Mostra um **Histórico** local dos resultados de escrita e de seleção bem-sucedidos, com entradas duplicadas consecutivas agrupadas, texto de origem e de resultado selecionáveis, um controle para copiar o resultado e uma ação para limpar tudo. As entradas antigas de Voice continuam legíveis.
- Escreve e traduz com OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras ou qualquer endpoint personalizado compatível com a OpenAI, como um servidor de modelos local. A pronúncia sempre usa a OpenAI; o ditado usa o mecanismo de reconhecimento de fala escolhido em **Ditado em tempo real**.
- Executa a escrita e a tradução no seu Mac com o mecanismo integrado (Qwen3.5 4B ou Gemma 4 E4B, baixados uma única vez do Hugging Face) ou com um servidor local do Ollama ou do LM Studio. Não é preciso chave de API e o texto fica no seu Mac.
- Oferece a interface do app em inglês, chinês simplificado, chinês tradicional, japonês, coreano, espanhol, francês, alemão, português e italiano.
- Adapta os menus de seleção compactos e os controles com pouco espaço dos ajustes e da escrita aos rótulos traduzidos; trocar o idioma atualiza a interface aberta e preserva o conteúdo da escrita.

## Status atual

O Inklet é um MVP em estágio inicial. O repositório inclui atualmente:

- Um Swift Package para o app do macOS e o mecanismo principal de escrita.
- Um app de barra de menus com um popover de escrita e uma janela de ajustes.
- Adaptadores de provedores e armazenamento de configuração.
- Testes unitários do comportamento principal.
- Notas de testes manuais em [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Requisitos

- macOS 14 ou posterior.
- Toolchain do Swift 6.
- O Xcode completo é recomendado para o suporte a XCTest.
- Permissão de Acessibilidade para o Inklet, necessária para a leitura genérica da seleção, o método alternativo de cópia configurado, devolver o foco ao app anterior e colar o resultado gerado.
- Permissão de Microfone para o ditado em tempo real enquanto o atalho é mantido pressionado.
- Uma chave de API da OpenAI ou de outro provedor compatível, ou um modelo local. A pronúncia, e o ditado com o mecanismo da OpenAI, exigem uma chave de API da OpenAI.

## Modelos locais

O Inklet pode escrever e traduzir com um modelo que roda no seu Mac, então seu texto nunca sai dele e nenhuma chave de API é necessária.

- **Integrado** (só Apple Silicon e padrão em instalações novas): escolha **Integrado** como provedor, selecione um modelo e clique em **Baixar**. O Gemma 4 E4B (cerca de 4,6 GB) é o padrão em Macs com 16 GB de memória ou mais; o Qwen3.5 4B (cerca de 2,7 GB) é o recomendado para 8 GB. Em uma instalação nova, o guia de boas-vindas faz o download e, enquanto um modelo é baixado, o popover de escrita mostra o progresso, com um botão **Baixar** se o modelo ainda não estiver lá. Os downloads continuam depois de uma interrupção e são verificados com um SHA-256 fixado antes do uso. Quando você abre o popover de escrita com **Integrado** selecionado, o Inklet inicia o servidor llama.cpp incluído apenas no endereço de loopback e carrega o modelo, que geralmente já está pronto quando você envia o texto. Em Macs com 24 GB de memória ou mais, o modelo continua carregado e só é liberado quando o macOS fica com pouca memória; em Macs menores, o servidor o libera após cinco minutos ocioso.
- **Ditado neste Mac** (só Apple Silicon e padrão em instalações novas): o Ditado em tempo real reconhece a fala com o Qwen3-ASR 0.6B (cerca de 1 GB), que entende 30 idiomas e chinês misturado com inglês. Ele roda no mesmo mecanismo llama.cpp incluído, em um servidor separado, retranscreve o que você está dizendo cerca de a cada 0,6 segundo enquanto você fala e fixa cada frase em uma pausa. Em Macs com 16 GB de memória ou mais, o modelo de fala fica carregado enquanto o ditado está ativado; em Macs menores, ele é carregado quando o popover de escrita abre e liberado após cinco minutos ocioso. Desativar o ditado, ou escolher a OpenAI, o interrompe. Quando o Inklet ou o macOS usa chinês tradicional, o ditado em chinês é escrito com caracteres tradicionais.
- **Ollama**: instale o [Ollama](https://ollama.com), execute `ollama pull qwen3.5:4b` e escolha **Ollama**. O Inklet lista os modelos que o Ollama já baixou.
- **LM Studio**: inicie o servidor local do LM Studio na porta 1234, carregue um modelo e escolha **LM Studio**.

Os provedores locais têm pelo menos 120 segundos por solicitação para que a primeira solicitação consiga carregar o modelo. O Inklet pede aos servidores locais que pulem o "raciocínio" para que modelos de raciocínio pequenos respondam diretamente. As compilações a partir do código-fonte compilam o mecanismo integrado com `scripts/build-llama-server.sh`, que precisa do `cmake`; se ele estiver ausente, o app ainda funciona e a opção **Integrado** explica que o mecanismo não está incluído.

## Compilar e executar

Antes de cada compilação do bundle do app, aumente tanto `INKLET_VERSION` quanto `INKLET_BUILD_NUMBER` no arquivo `VERSION` da raiz. Normalmente, incremente a versão de patch; use incrementos menores ou maiores para mudanças maiores. O número de build precisa continuar sendo um inteiro positivo maior que qualquer número de build já usado, inclusive entre versões de marketing. Confira a `main` mais recente, as tags do Git, todas as versões do GitHub (incluindo rascunhos) e os worktrees ativos antes de escolhê-lo. O Inklet usa apenas esse número de build para decidir se uma atualização é mais nova.

Execute as compilações remotas do DMG no GitHub somente a partir da `main`, depois de mesclar e enviar as mudanças pretendidas e o `VERSION` atualizado. Dispare o `build-dmg.yml` com `--ref main`.

Para uma versão oficial, verifique se a compilação foi bem-sucedida e os arquivos finais, substitua a descrição provisória pelas mudanças em chinês e inglês desde a última versão estável publicada e publique como a versão estável mais recente. Um rascunho já verificado pode ser publicado sem recompilar nem mudar a versão.

O fluxo de trabalho do DMG verifica, antes de compilar, números de build reutilizados ou menores; ele não incrementa nenhum dos dois valores automaticamente. Veja [release version checks](scripts/README.md#release-version-checks) para a validação manual. Mudar a versão de um app empacotado exige recompilar, assinar, notarizar e gerar novamente os checksums; mudar só o título da versão ou o nome do arquivo não atualiza o app.

Na raiz do repositório:

```bash
swift build
scripts/run-local-app.sh
```

Use `scripts/run-local-app.sh` para os testes manuais do dia a dia a partir de qualquer worktree. Ele instala e abre a identidade estável `/Applications/Inklet Local.app`, para que as permissões de Acessibilidade e do Keychain do macOS sejam reaproveitadas entre compilações.

Executar os testes:

```bash
swift test
```

Se os testes falharem porque o `XCTest` não está disponível, instale o app Xcode completo em vez de apenas as Command Line Tools.

Verifique todos os idiomas da interface com `scripts/check-localization.sh`. Adicione `--snapshots` para gerar uma galeria HTML local de telas nativas sintéticas em `.build/localization-audit/`; o comando mostra o caminho. Pull requests e pushes para a `main` executam automaticamente todos os testes unitários e as verificações de localização. Veja [localization audit](docs/localization-audit.md) para a cobertura e as verificações manuais restantes.

## Atalhos de teclado

- `Option+Space`: abre o popover de escrita.
- `Right Option`: mantenha pressionado para ditar enquanto o editor de origem do Assistente de escrita está ativo. Troque a tecla modificadora ou desative o ditado em **Ajustes** → **Ditado em tempo real**; um toque curto continua sem efeito.
- `Up` / `Down` no lançador de modos: move o destaque pelos modos de prompt ordenados por correspondência aproximada.
- `Tab`, `Return` ou `Enter` do teclado numérico no lançador de modos: confirma o modo de prompt destacado e coloca o foco no editor de origem. Durante uma composição do método de entrada, Return continua confirmando o texto ou um candidato; Return com Command, Shift, Option ou Control não confirma um modo.
- `Enter` no editor: transforma o texto de origem, insere um resultado gerado pelo modo atual ou gera de novo, com o modo recém-confirmado, um resultado desatualizado de um modo anterior.
- `Command+Enter`: insere o texto original sem chamar o modelo.
- `Shift+Command+C`: copia o resultado visível sem fechar o popover.
- `Command+Up` / `Command+Down`: alterna entre os modos de prompt visíveis.
- `Escape`: volta um nível a cada toque, do resultado para o editor de origem, depois para o lançador de modos e então fecha o popover. Durante a transformação, para a geração, descarta o resultado parcial e permanece no editor.
- `Command+,`: abre os Ajustes enquanto o Inklet está ativo.

A busca não diferencia maiúsculas, minúsculas nem acentos e aceita correspondência de caracteres em ordem. Correspondências exatas e de prefixo recebem o maior peso; correspondências consecutivas, no início de palavras, mais cedo e mais próximas geralmente ficam mais acima.

Quando o lançador de modos abre, o último modo de prompt confirmado fica destacado se ainda estiver visível. Um clique destaca um modo; um clique duplo o confirma. Voltar ao lançador mantém o rascunho e o resultado atuais.

## Estrutura do repositório

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    QA manual e política de privacidade
```

## Notas de desenvolvimento

- Mantenha o comportamento dos provedores coberto por testes unitários focados.
- Use [docs/manual-test-checklist.md](docs/manual-test-checklist.md) antes de lançar mudanças visíveis para o usuário.
- Use `scripts/run-local-app.sh` em vez de um executável puro do SwiftPM ou `open dist/...` para os testes manuais do dia a dia, para que as permissões locais de Acessibilidade e do Keychain continuem ligadas a uma única identidade estável do app.
- Trate com cuidado os fluxos de área de transferência e de Acessibilidade; eles são centrais na experiência do app.
- O projeto ainda está na fase de MVP, então o README deve acompanhar o código, e não planos futuros.

## Armazenamento local e atualizações

As versões de produção e de QA local usam armazenamento separado por bundle e não compartilham ajustes, Histórico, cache de tradução, diagnósticos nem credenciais do Keychain:

- Application Support de produção: `~/Library/Application Support/com.tomwan.inklet/`
- Application Support local: `~/Library/Application Support/com.tomwan.inklet.local/`
- Preferências de produção: `~/Library/Preferences/com.tomwan.inklet.plist`
- Preferências locais: `~/Library/Preferences/com.tomwan.inklet.local.plist`
- Chaves de API dos provedores: `api-keys.json` na pasta de Application Support correspondente, legível apenas pela sua conta de usuário e excluído dos backups do Time Machine
- Serviços do Keychain usados por versões anteriores: `Inklet.ProviderAPIKey` (produção) e `Inklet.Local.ProviderAPIKey` (local)

As versões anteriores guardavam as chaves de API no Keychain. Na primeira vez que uma chave é necessária, o Inklet a copia do Keychain para `api-keys.json` e mantém o item do Keychain no lugar, para que voltar a uma versão anterior ainda a encontre. Alterar ou apagar uma chave nos Ajustes remove a cópia do Keychain.

Na primeira abertura depois de atualizar da antiga versão com sandbox, o Inklet copia automaticamente as preferências antigas reconhecidas, as chaves de API dos provedores para o serviço do Keychain correspondente e o Histórico para o armazenamento do bundle atual. Ele não apaga nem altera a origem antiga, então os dados antigos continuam disponíveis para reverter ou recuperar. O cache de tradução, que é descartável, não é migrado.

Se o macOS bloquear o acesso automático ao contêiner antigo correspondente, os Ajustes mantêm disponível a ação **Importar dados…**. A importação assistida valida exatamente a pasta `Data` antiga do bundle de produção ou local em execução, lê essa pasta apenas enquanto a permissão atual do painel de arquivos for válida e não salva um marcador de acesso permanente.

## Privacidade

- O Inklet envia as solicitações de escrita e de tradução da seleção para o provedor escolhido nos Ajustes, usando a chave de API desse provedor. A pronúncia sempre usa sua chave de API da OpenAI e a OpenAI. O ditado só usa a OpenAI quando você a escolhe como mecanismo de reconhecimento de fala.
- Com o reconhecimento de fala **Neste Mac**, o áudio do ditado e a gravação de recuperação são processados por um servidor no seu Mac e nunca saem dele.
- Com o reconhecimento de fala da OpenAI, enquanto você mantém pressionado o atalho de Ditado, o áudio do microfone ativo é transmitido diretamente para a transcrição do OpenAI Realtime. O Inklet também guarda uma gravação local temporária de recuperação. Ela fica local até a solicitação alternativa realmente começar, é enviada no máximo uma vez para `https://api.openai.com/v1/audio/transcriptions` usando a mesma chave de API da OpenAI já usada pelo ditado em tempo real e é apagada em qualquer forma de encerramento da sessão.
- Suas chaves de API são armazenadas localmente no seu Mac, uma por provedor.
- Com os provedores **Integrado**, Ollama ou LM Studio, as solicitações de escrita e tradução vão apenas para um servidor no seu Mac. Baixar um modelo integrado envia uma solicitação ao Hugging Face para o arquivo escolhido; ela não inclui seu texto, áudio, chaves de API nem ajustes.
- O Inklet usa a permissão de Acessibilidade para a leitura genérica da seleção, o método alternativo de cópia configurado, devolver o foco ao app anterior e colar texto.
- O Inklet usa a permissão de Microfone apenas durante um ditado válido mantido pressionado no editor de origem ativo do Assistente de escrita. Ao terminar o ditado, fica um rascunho editável e nada é inserido em outro app.
- O Inklet usa temporariamente a área de transferência para a inserção e para as leituras alternativas de **Seleção forçada** configuradas. Uma leitura de **Seleção forçada** só restaura a área de transferência anterior se o valor copiado temporariamente pelo Inklet ainda for o atual, e não sobrescreve uma alteração externa posterior da área de transferência.
- O Inklet salva localmente no Histórico o texto de origem e o resultado das ações de escrita e seleção bem-sucedidas até você limpá-lo nos Ajustes, pulando entradas duplicadas consecutivas. Um rascunho ditado sem processamento não cria entrada no Histórico; as entradas antigas de Voice continuam legíveis localmente.
- As ações de seleção capturam o app de origem e a posição da seleção, validam essa origem antes e durante a leitura e usam a Acessibilidade para ler a seleção atual. Se a Acessibilidade não retornar o texto selecionado, o modo de **Seleção forçada** configurado pode acionar rapidamente o Copiar do menu e ler o texto resultante da área de transferência pela transação protegida descrita acima. O `Command+C` simulado fica desativado por padrão e só é executado depois de uma ativação avançada explícita. Você pode desativar a **Seleção forçada** nos Ajustes. Esse caminho não envia Apple Events direcionados a navegadores nem pede permissão de Automação para navegadores. Pressionar `Command+C` duas vezes rapidamente depois de selecionar texto lê explicitamente a cópia que você já fez. O Inklet não salva texto apenas selecionado, a menos que uma ação bem-sucedida seja registrada no Histórico local.
- O Assistente de seleção guarda em cache local por 7 dias os resultados de tradução bem-sucedidos, usando chaves de cache com hash, para acelerar traduções repetidas.
- Quando não há tradução no cache local, a tradução do Assistente de seleção envia o texto selecionado e suas instruções personalizadas de **Traduzir** para o provedor escolhido; um botão de modo de prompt envia o texto selecionado e o prompt desse modo para o provedor escolhido; a pronúncia com IA envia o texto selecionado para a OpenAI.
- O Inklet busca o catálogo público de modelos em `models.dev` no máximo uma vez por dia. Essa solicitação não inclui seu texto, áudio, chaves de API nem ajustes do app.
- Não envie texto ou áudio privados para a OpenAI ou para o provedor escolhido a menos que você confie nas políticas de tratamento de dados deles.

## Feedback

Escolha **Enviar feedback…** no menu do Inklet na barra de menus, ou [abra uma issue](https://github.com/wanming/Inklet/issues/new/choose). Relatos de bugs e ideias de recursos são bem-vindos; nunca cole chaves de API ou texto privado em uma issue.

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md).

## Segurança

Veja [SECURITY.md](SECURITY.md) para relatar vulnerabilidades e para orientações sobre dados sensíveis.

## Licença

O Inklet é distribuído sob a [MIT License](LICENSE).
Os avisos de terceiros estão em [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
