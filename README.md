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
| F10 | Teste de estresse (máquinas de teste) |
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
- **Máquinas:** Drill (cospe **terra**, precisa de água: balde por 30s ou **canos ligados ao lago** = água infinita), Harvester (puxa terra das drills num raio de 10m e libera minérios na caixa), Cadinho (funde 10 minérios → 1 barra, +10% de valor), Forja (aquece barras), Bigorna (Anel +15%, Adaga +25%, Espada +40% — **forja posicional**: punho de ferro + lâmina de ouro!), Polidora (lapida gemas brutas ×2.2), Prensa (combina gemas em joia ×1.3), Bacia, Canos, Esteiras, Filtros, Baús, Silos, Geradores e Cabos.
- **Eletricidade:** geradores T1–T5 alimentam polidora e prensa; ligue cabos (snap automático) e acompanhe a oferta/consumo no rótulo do gerador.
- **Lógica e sensores:** Sensor de contagem, Alarme com meta ajustável e Interruptor que liga/desliga máquinas num raio de 10m.
- **Veios de minério:** 30 afloramentos espalhados pelo vale (4–8 por zona); aperte E para minerar 3–8 minérios e espere 20s para recarregar. Compre o **Detector de Metais** ($1.200) para revelar o tipo de cada veio a até 12m.
- **Estátua do Legado:** no vilarejo; doe dinheiro para subir até 10 níveis e ganhar **+5% de bônus permanente por nível em todas as vendas**.
- **Ciclo dia/noite:** dia completo a cada 12 minutos — amanhecer, meio-dia, entardecer e noite com céu, sol, névoa e luz ambiente mudando de cor; os lampiões do vilarejo acendem sozinhos à noite. O horário é salvo.
- **Caminhão:** compre no Mercador ($2.500) e dirija com WASD (Shift acelera). A caçamba recolhe automaticamente os minérios pelo caminho; estacione a 15m do mercador para vender a carga inteira, ou aperte R perto dele para descarregar no bolso.
- **Monitor de desempenho:** FPS e contagem de máquinas sempre visíveis no canto da tela.
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

- **Novo minério/gema:** adicione uma entrada em `ORES`/`GEMS` e uma coluna de peso em `ORE_WEIGHTS`/`GEM_WEIGHTS` em `data.gd`. Tudo (rolagem, cores, preços, filtros) passa a funcionar automaticamente.
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

## Roadmap

- **Concluído:** ciclo inicial, todas as máquinas, eletricidade, lógica/sensores, construção avançada (mover/blueprint), eventos aleatórios, encomendas urgentes, banco, veios + detector, mapa com viagem rápida, estátua do legado, ciclo dia/noite, caminhão dirigível, monitor de FPS, estatísticas e documentação.
- **Futuro:** árvore de habilidades, multiplayer.
