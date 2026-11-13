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
| **E** | Interagir (lago, bacia, drill, harvester, cadinho, forja, bigorna, polidora, prensa, mercador, quadro) |
| **T** | Menu de construção / cancelar construção |
| **X** | Desmontar máquina próxima (devolve 50% do dinheiro) |
| F5 | Salvar |
| F9 | Apagar save e reiniciar |
| Esc | Soltar/pegar o mouse / fechar menus |

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
- **Máquinas:** Drill (cospe **terra**, precisa de água: balde por 30s ou **canos ligados ao lago** = água infinita), Harvester (puxa terra das drills num raio de 10m e libera minérios na caixa), Cadinho (funde 10 minérios → 1 barra, +10% de valor), Forja (aquece barras), Bigorna (Anel +15%, Adaga +25%, Espada +40% — **forja posicional**: punho de ferro + lâmina de ouro!), Polidora (lapida gemas brutas ×2.2), Prensa (combina gemas em jóia ×1.3), Bacia, Canos.
- **Encomendas:** quadro no vilarejo pede barras específicas por 1.6× do valor.
- **Artefatos:** 0.5% ao cavar, 2% ao escovar — easter eggs vendáveis.
- **Vilarejo:** as casinhas crescem conforme você avança nas missões.
- **Sem inventário, sem combate, sem fome/vida** — só dinheiro, minérios e boa paz. 🌄

## Performance (a razão de existir)

- Terreno = grade de alturas (PackedFloat32Array) em 100 chunks; só o chunk cavado é reconstruído.
- Água = simulação celular em janelas rotativas (1/6 do mapa por tick, 10Hz) com evaporação.
- Máquinas = dicionários de dados + spatial hash; só 1/4 delas é processada por frame; visuais somem a 60m de distância. Suporta até **20.000 máquinas**.
- Zero entidades simuladas (nada de nós por minério/processo como no Hydroneer original).

## Save

Salva em `user://savegame.json` automaticamente a cada 30s (versão 2 — save antigo é ignorado; use F9).

## Roadmap

- **M1 (atual):** ciclo inicial + máquinas + canos + forja/bigorna/polidora/prensa + 5 terrenos + missões principais + vilarejo + encomendas + save v2.
- **M2:** banco/empréstimos/reputação, eventos aleatórios (guerra), missões temporadas (rei/mago/papa).
- **M3:** veículos, detector de metais, bombas de sucção, registros nos canos, picareta/rastelo, árvore de habilidades.
- **M4:** música longa relaxante, polimento visual, artefatos especiais.
- **M5:** multiplayer.
