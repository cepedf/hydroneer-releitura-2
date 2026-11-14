# Hydroneer 2 — A Herança (Releitura em Godot 4)

Releitura do Hydroneer com foco em **performance extrema** (zero entidades simuladas) e na visão completa do jogo: 5 terrenos (T1–T5), 7 minérios, 7 gemas, máquinas, forja, bigorna, vilarejo que evolui e história de herança do avô.

## Como baixar e rodar (passo a passo)

1. Abra a página do repositório no GitHub.
2. Clique no botão verde **`< > Code`** → **`Download ZIP`**.
3. Extraia o ZIP em uma pasta do seu PC (ex.: `C:\Jogos\hydroneer-releitura-2`).
4. Abra o **Godot 4.7.2** (a versão normal, não precisa da console).
5. Clique em **Import** e selecione o arquivo `project.godot` dentro da pasta extraída.
6. Clique em **Import & Edit**. Depois aperte **F5** (ou o botão ▶) para jogar.
7. **IMPORTANTE:** se você jogou a versão antiga, aperte **F9** dentro do jogo para apagar o save antigo e começar do zero (o terreno mudou de tamanho).

## Controles

| Tecla | Ação |
|---|---|
| WASD | Mover |
| Mouse | Olhar (primeira pessoa) |
| Shift | Correr |
| Espaço | Pular |
| **Clique esquerdo (segurar)** | Cavar terra com a pá / **Escovar** a bacia / Posicionar construção |
| **E** | Interagir (lago, bacia, drill, harvester, cadinho, forja, bigorna, polidora, prensa, mercador, quadro, estátua, veios) |
| **T** | Menu de construção / cancelar construção |
| **X** | Desmontar máquina próxima (devolve 50% do dinheiro) |
| **G** | Mover peça já colocada (Esc devolve ao lugar original) |
| **B** | Blueprint: capturar instalação num raio de 8m e carimbar em outro lugar |
| **M** | Mapa do vale com marcadores e viagem rápida |
| **(perto do caminhão)** | E: dirigir / sair · R: descarregar a caçamba no bolso |
| **H** | Diagnóstico da máquina mirada |
| **J** | Estatísticas da indústria e gargalos |
| F5 | Salvar |
| F9 | Apagar save e reiniciar |
| F10 | Teste de estresse (drills 100→500→1000, esteiras em linha 100→500, limpar) |
| Esc | Soltar/pegar o mouse / fechar menus / pausa |

## O ciclo inicial (igual ao Hydroneer)

1. Vá ao **lago** (a oeste do spawn) e aperte **E** para encher o balde de água.
2. **Segure o clique esquerdo** para cavar terra — cada cavada enche 1 carga no balde.
3. Vá até a **bacia** (perto do spawn) e aperte **E** para despejar a terra.
4. Aperte **E** de novo com o balde d'água para molhar a bacia.
5. **Mire na bacia e segure o clique esquerdo** para **escovar** — minérios e gemas aparecem!
6. Ande perto dos minérios para pegá-los, depois **E no Mercador** (no vilarejo, ao norte) para vender.

## Mecânicas

- **7 minérios:** Ferro, Cobre, Prata, Ouro, Platina, Mithril e **Corium** (preto com magma pulsante).
- **7 gemas:** Ágata, Ametista, Esmeralda, Safira, Rubi, Diamante e **Lágrima Divina** (só no T5).
- **5 terrenos:** T1 do avô → T2 do Prefeito ($10.000) → T3 do Governador → T4 do Rei → **T5 Terra Sagrada** (missão principal). Portões trancados abrem conforme as missões.
- **Máquinas:** Drill (cospe **terra**, precisa de água: balde por 30s ou **canos ligados ao lago** = água infinita), Harvester (movido a água por canos como no original — rende mais com boa pressão; recebe terra de drill encostada, esteira/silo a 3,5m ou despejada com E), Cadinho (funde 10 minérios → 1 barra, +10% de valor), Forja (aquece barras), Bigorna (Anel +15%, Adaga +25%, Espada +40% — **forja posicional**: punho de ferro + lâmina de ouro!), Polidora (lapida gemas brutas ×2.2), Prensa (combina gemas em joia ×1.3), Bacia, Canos, Esteiras, Filtros, Baús, Silos, Geradores e Cabos.
- **Eletricidade:** geradores T1–T5 alimentam polidora e prensa; ligue cabos (snap automático) e acompanhe a oferta/consumo no rótulo do gerador.
- **Lógica e sensores:** Sensor de contagem, Alarme com meta ajustável e Interruptor que liga/desliga máquinas num raio de 10m.
- **Veios de minério:** 30 afloramentos espalhados pelo vale (4–8 por zona); aperte E para minerar 3–8 minérios e espere 20s para recarregar. Compre o **Detector de Metais** ($1.200) para revelar o tipo de cada veio a até 12m.
- **Estátua do Legado:** no vilarejo; doe dinheiro para subir até 10 níveis e ganhar **+5% de bônus permanente por nível em todas as vendas**.
- **Ciclo dia/noite:** dia completo a cada 12 minutos — amanhecer, meio-dia, entardecer e noite com céu, sol, névoa e luz ambiente mudando de cor; os lampiões do vilarejo acendem sozinhos à noite. O horário é salvo.
- **Caminhão:** compre no Mercador ($2.500) e dirija com WASD (Shift acelera). A caçamba recolhe automaticamente os minérios pelo caminho; estacione a 15m do mercador para vender a carga inteira, ou aperte R perto dele para descarregar no bolso.
- **Monitor de desempenho:** FPS e contagem de máquinas sempre visíveis no canto da tela.
- **Áudio espacial:** as máquinas ligadas mais próximas (até 6 ao mesmo tempo, num raio de 22m) emitem um zumbido mecânico posicional — dá para ouvir de onde vem o movimento da fábrica.
- **Acessibilidade e áudio configurável:** no menu de pausa — tamanho do texto do HUD (100/125/150%), volume de música e de efeitos separados (Mudo/Baixo/Normal/Alto), tudo salvo no save.
- **Créditos:** tela própria no menu de pausa e na tela de título.
- **Registro de erros:** falhas de save/save corrompido e resultados dos testes de estresse ficam registrados em `user://error_log.txt`.
- **Mapa e viagem rápida (M):** veja o vale inteiro com portões, vilarejo, lago, veios e sua posição; viaje de volta para o vilarejo, lago ou portões já desbloqueados.
- **Encomendas:** quadro no vilarejo pede barras específicas por 1.6× do valor; encomendas **urgentes** expiram em 120s.
- **Eventos aleatórios:** Veio Rico (rendimento em dobro), Chuva (bacias enchem sozinhas) e Alta do Mercado (+25% nas vendas).
- **Banco:** empréstimos com limite baseado nos seus ganhos, juros de 1%/min e desconto automático a cada 30s.
- **Artefatos:** 0.5% ao cavar, 2% ao escovar — easter eggs vendáveis.
- **Vilarejo:** as casinhas crescem conforme você avança nas missões.
- **Sem inventário, sem combate, sem fome/vida** — só dinheiro, minérios e boa paz. 🌄

## Performance (a razão de existir)

- Terreno = grade de alturas (PackedFloat32Array) em 100 chunks; só o chunk cavado é reconstruído.
- Água = simulação celular em janelas rotativas (1/6 do mapa por tick, 10Hz) com evaporação.
- Máquinas = dicionários de dados + spatial hash; só 1/4 delas é processada por frame; visuais somem a 60m de distância. Suporta até **20.000 máquinas**.
- Zero entidades simuladas (nada de nós por minério/processo como no Hydroneer original).

## Documentação técnica

### Estrutura de arquivos

```
project.godot        Configuração do projeto (Godot 4.x, Forward+)
scenes/main.tscn     Cena única do jogo (raiz com script main.gd)
scripts/main.gd      Orquestração: input, economia, missões, eventos, save/load, vilarejo, mapa
scripts/terrain.gd   Terreno deformável em chunks, camadas, água celular, minérios visuais
scripts/machines.gd  Todas as máquinas: dados, lógica em lote, visuais procedurais, redes (água/energia/correias)
scripts/player.gd    Controle em primeira pessoa, viewmodel da pá/balde
scripts/hud.gd       HUD, menus, intro, título, diagnóstico, estatísticas e mapa
scripts/sound.gd     Sons procedurais (AudioStreamGenerator)
scripts/data.gd      TODAS as tabelas de balanceamento (const)
```

### Como adicionar conteúdo (sem tocar na arquitetura)

- **Novo minério/gema:** adicione uma entrada em `ORES`/`GEMS` e uma coluna de peso em `ORE_WEIGHTS`/`GEM_WEIGHTS` em `data.gd`. Tudo (rolagem, cores, preços, filtros) passa a funcionar automaticamente. O **Sacradium** ($500, só na Terra Sagrada T5, brilho emitivo + aura de luz no minério e nos veios) segue exatamente esse padrão.
- **Nova máquina:** defina o preço em `data.gd`, adicione o ramo de lógica em `_update_machine`, o texto em `_status_text` e o visual em `_build_visual` (todas em `machines.gd`); registre no menu de construção (`open_build_menu`) e no custo (`_machine_cost`).
- **Nova receita:** as receitas são funções de conversão nos menus (cadinho, bigorna, polidora, prensa) — siga o padrão existente.
- **Novo terreno/zona:** acrescente entradas em `ZONE_NAMES`, `ZONE_X_BOUNDS`, `ZONE_BEDROCK` e nas tabelas de pesos.
- **Balanceamento:** todos os preços, taxas e capacidades vivem em `data.gd` como `const` — nenhum número mágico nos sistemas.

### Formato do save (`user://savegame.json`, versão 2)

- Progressão: dinheiro, tiers de pá/escova, missões, encomendas, vilarejo, zonas desbloqueadas, dívida, estátua, tempo de jogo.
- Máquinas: array de arrays `[tipo, tier, x, y, z, terra, água, timer, caixa, gemas, yaw, prev_x, prev_z, carga, filtro, orebox, aberto, estoque, contagem, meta, minério_do_veio]`.
- Mundo: alturas do terreno e água por célula (somente os dados modificáveis), canos e cabos por posição.
- Autosave a cada 30s; F9 apaga e reinicia.

### Princípios de arquitetura

1. **Lógica separada da representação:** minérios são quantidades em dicionários; a parte visual é opcional e descartável.
2. **Simulação em lote:** máquinas são processadas por índice rotativo (1/4 por frame) com correção de delta; a produção é matemática, não física.
3. **Redes independentes:** água (BFS por canos), energia (BFS por cabos), correias (cadeia por `prev`) e lógica (sensores por proximidade) têm sistemas próprios.
4. **Dados como tabela:** itens, máquinas e zonas são entradas de dicionário — adicionar conteúdo não altera sistemas centrais.
5. **Persistência total:** terreno, construções, redes, estoques e progressão sobrevivem entre sessões.

### Cenas de teste visual (F11) e de estresse (F10)

- **F11 — Showroom visual:** plataforma suspensa com uma unidade de cada máquina (19 tipos, com tiers de energia/perfuração/colheita), todos os 7 minérios, todas as 7 gemas (com emissão) e 8 amostras de materiais (terra, areia, pedra, madeira, ferro, aço, cobre, água translúcida), tudo rotulado. Serve para conferir paleta, silhuetas e coerência visual de uma só vez (seções 1.3 e 21 da especificação visual). F11 de novo devolve o jogador ao ponto anterior; nada do showroom é salvo.
- **F10 — Teste de estresse:** spawna 100/500/1000 drills e depois 100/500 esteiras em linha (simuladas de verdade) para validar desempenho de end game (seção 19.5 do checklist funcional).
- **Teste de iluminação:** o ciclo dia/noite (12 min por dia) cobre amanhecer, meio-dia, entardecer, noite com lampiões e transições — basta deixar o jogo rodando.

### Padrões para assets externos (quando o projeto sair do procedural)

O jogo hoje é 100% procedural (meshes e materiais criados em código). Quando houver modelos 3D reais, seguir:

- **Escala:** 1 unidade Godot = 1 metro; jogador com 1,7 m; portas com 2,2 m de altura.
- **Orientação:** frente da máquina para +Z local; pivô na base do objeto; rotação só no eixo Y (o jogo usa `yaw`).
- **Exportação:** glTF 2.0 (.glb), um arquivo por máquina/construção, sem escalas ou rotações aplicadas no nó raiz.
- **Materiais:** nomes padronizados (`mat_ferro`, `mat_madeira_clara`...) e reaproveitados via biblioteca compartilhada — nunca material único por peça.
- **LOD:** 3 níveis (próximo/intermediário/distante) para máquinas grandes e vegetação; colisão sempre em geometria simplificada (BoxShape/CylinderShape), nunca a malha visual.
- **Animações:** estados ligada/trabalhando/ociosa/falha como animações nomeadas, controladas pela lógica da máquina (nunca a animação manda na produção).
- **Partes móveis:** separadas como nós filhos nomeados (`spinner`, `bit`, `pistao`) — o código atual já anima nós com esses papéis.

## Roadmap

- **Concluído:** ciclo inicial, todas as máquinas, eletricidade, lógica/sensores, construção avançada (mover/blueprint), eventos aleatórios, encomendas urgentes, banco, veios + detector, mapa com viagem rápida, estátua do legado, ciclo dia/noite, caminhão dirigível, áudio espacial, acessibilidade/volumes, créditos, log de erros, monitor de FPS, estatísticas e documentação.
- **Identidade visual (checklist 2, parte 1):** montanhas na borda do mundo, nuvens em movimento contínuo, sol e lua visíveis seguindo o ciclo do dia, água com shader de ondas animadas, vegetação procedural (grama instanciada via MultiMesh, flores, pedras) que se assenta no terreno escavado, balanço de árvores ao vento, poeira de escavação, fumaça na forja, 4 perfis de qualidade gráfica (Baixa/Média/Alta/Ultra: sombras, glow, SSAO, MSAA) no menu de pausa com persistência, e cache compartilhado de materiais das máquinas (menos draw calls e menos memória).
- **Conteúdo:** **Sacradium** — minério sagrado, o mais valioso do jogo ($500; barra a $5.500), encontrado apenas nos veios da Terra Sagrada (T5), com brilho emitivo dourado e aura de luz própria tanto no minério coletado quanto no veio no chão.
- **Identidade visual (checklist 2, parte 2):** interface com tema rústico-industrial (painéis e botões em tons de madeira/ocre com bordas, estados de hover/seleção/bloqueio), mãos em primeira pessoa segurando pá e balde, balanço de câmera ao caminhar/correr, roda da polidora e ventoinha do gerador girando quando ativas (paradas a 40m de distância — LOD de animação), caixas de passagem nos postes de energia, casas do vilarejo com fundação de pedra, cumeeira, variação de cor e barris/caixas decorativos, e showroom visual (F11) com todas as máquinas, minérios, gemas e materiais para conferência de fidelidade.
- **Esteira estilo Hydroneer (E1–E7):** correia montada SOBRE canos de água (mesmo encaixe do original), velocidade movida pela pressão da água (parada sem água; 60% sem cano embaixo — saves antigos continuam funcionando), seta verde de direção no fantasma e na correia com inversão de sentido (E na esteira), esteira vertical que sobe/desce escavações, divisor com bandeja lateral que desvia o que você põe nela para um cadinho/baú do lado, e visual idêntico ao original: estrutura de aço escuro, trilhos laterais, correia escura contínua e roletes que giram conforme a velocidade (e param quando a linha para). Especificação completa em `ESTEIRA_HYDRONEER.md`.
- **Checklist 3 (gráficos estilo Hydroneer) — fases A–E concluídas:** A) água contínua com vértices soldados, cores por profundidade e espuma na costa; terreno com camadas, encostas úmidas e bordas de escavação irregulares; casas com telhado de duas águas apoiado, chaminé e janelas com moldura. B) remodelagem total: bacia redonda escavada, balde aberto com líquido visível, pá com concha, escova de mão, minérios como rochas irregulares, gemas facetadas, bau com tampa aberta, silo com tampa cônica, bigorna real, forja abobadada com boca de fogo, drill em treliça, harvester com funil, polidora com disco e proteção, prensa com pistão, gerador detalhado, flanges nos canos, mercador como barraca de feira, estátua humana, montanhas com ruído, nuvens em grupos, árvores variadas e caminhão com caçamba aberta. C) texturas procedurais (grunge, madeira, metal, ferrugem, terra) geradas em código e aplicadas via triplanar. D) tonemapping ACES, glow só em emissivos, sombras suaves, névoa casada com o horizonte e volumetric fog em Alta/Ultra. E) painéis de madeira, botões com relevo, ícones desenhados em código, crosshair em cruz e medidores industriais. Detalhes em `CHECKLIST_3_GRAFICO.md`.
- **Fase G — polimento máximo:** normal maps procedurais (Sobel) em TODOS os materiais e no terreno (fim do plástico chapado), nuvens volumétricas de esferas sombreadas, grama dobrada + 60 arbustos + copas de outono, caminhos de terra e cerca com portão no vilarejo, 6 lampiões com luz real à noite, rebites sextavados em harvester/forja/gerador, água com fresnel e specular do sol, e vagalumes emissivos sobre o lago à noite.
- **Harvester estilo Hydroneer (H1–H6):** movido a ÁGUA como no original — precisa de canos ligados ao lago (atrás ou lateral), fica PARADO sem água e rende proporcional à pressão (100% com cano conectado, 60% encostado sem conexão — saves antigos continuam funcionando); alimentação realista: drill acoplada direto na saída (2,6m, como o "directly underneath the Drill's output" do guia), esteira/silo a 3,5m, ou entrada manual (E com balde de terra = jogar terra no topo); diagnóstico (H) mostra o estado da água e da alimentação; **cadeia completa com ligações explícitas**: drill → esteira (entrada, flash de ligação) → harvester → esteira nova (saída, como nas drills, nunca a mesma esteira da entrada) → filtro/divisor → cadinho/baú. Especificação completa em `HARVESTER_HYDRONEER.md`.
- **Futuro:** árvore de habilidades, multiplayer.
