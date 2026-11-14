# Pente Fino — Mecânicas (comparação com o Hydroneer)

Pesquisa: wiki oficial Bridgepour (Digsites), Fandom (Digsites), guias Steam (Ultimate Location Guide 2.0+), TechRaptor, GamesFuze, TposeGaming, Reddit e Namu.wiki.

## 1. Comparação mecânica

| Mecânica do Hydroneer | Nosso jogo | Status |
|---|---|---|
| Terrenos (claims) compráveis, cada um com profundidade/tier e densidade de recursos próprios | 5 zonas em faixas (Terras do Avô → Terra Sagrada) com bedrock e tabelas de minério por tier | ✔ alinhado |
| Terrenos trancados são propriedades demarcadas no mundo | Só havia um portão parcial; **agora: cerca de madeira em toda a divisa, com portão de barras que fecha o terreno trancado e abre quando comprado** | ✔ corrigido (P1) |
| Não dá para entrar/construir em terreno alheio | Dava para andar até dentro; **agora o player e o caminhão são barrados na cerca** (escorregam pela divisa) | ✔ corrigido (P1) |
| Cavar mais fundo = minérios melhores; ferramentas por profundidade | Tiers de pá/escova + bedrock por zona | ✔ alinhado |
| Tudo funciona por pressão de água (intake no rio → canos → máquinas) | `pipe_factor_at`: cano ligado ao lago = 100%, sem cano = 60%, seco = parado; esteira e harvester movidos à pressão | ✔ alinhado |
| Loop manual: pá → balde → bacia (pan) → água → escova → vender | Idêntico (pá, balde, bacia, escova, rastelo) | ✔ alinhado |
| Drill → harvester → correias → sorter → fundir/vender | drill → esteira → harvester → esteira → filtro/divisor → cadinho → forja → bigorna/polidora/prensa | ✔ alinhado (H7–H9) |
| **TNT / Mini nuke** para escavação pesada | Não existia | ✔ **adicionado: Dinamite** (P2) |
| Caminhões hidráulicos transportando carga | Caminhão com caçamba coletora | ✔ alinhado |
| Lógica: sensores, alarmes, interruptores | Sensor, alarme, interruptor | ✔ alinhado |
| Vender ouro/gemas/joias em lojas da cidade | Mercador (barraca) + banco com empréstimo/juros | ✔ alinhado (banco é nosso extra) |
| Multiplayer (2.0, via Remote Play) | Adiado por decisão do usuário | ⏸ adiado |

## 2. Mudanças desta rodada

### P1 — Cercas de propriedade privada
- Cada divisa de zona (x = -30, 0, 30, 55) ganhou **cerca de madeira contínua** (postes a cada 4,2 m + dois travessões) ao longo de todo o lado de mineração do mapa (z de -78 a 48).
- O corredor do vilarejo (z > 48) fica **sem cerca** — a cidade é pública.
- No vão do portão (z 16–24) há um **portão de 5 barras verticais**: fechado e vermelho "TRANCADO" enquanto a zona não é comprada; **as barras somem e o rótulo fica verde "ABERTO"** quando a zona é desbloqueada (missão/compra).
- **Bloqueio de passagem**: o player não atravessa a divisa para uma zona trancada (desliza pela cerca como parede); o caminhão também é barrado. O showroom (F11) é exceção.
- Cavar e construir em zona trancada continuam bloqueados (já existiam).

### P2 — Dinamite ($150, tecla V)
- Comprada no mercador ("Comprar Dinamite — $150").
- Uso: aponte o chão e aperte **V** → explosão abre **cratera de raio 3,6 m** (mais forte que qualquer pá), com 3 nuvens de poeira e **som de explosão procedural** (grave, com decaimento).
- Respeita zona trancada e bedrock. Contagem aparece no flash ("BUUM! ... N restantes").
- Salva no save (`pocket_dynamite`, retrocompatível).

## 3. Decisões conscientes
- A cerca é visual + bloqueio lógico de movimento (o jogo não usa física para o player), o que mantém o custo zero de FPS.
- Não implementamos Mini Nuke/TNT com física de propulsão de objetos — a dinamite cobre o papel de escavação pesada.
- O corredor do vilarejo permanece aberto de propósito: as missões exigem ir à cidade antes de comprar as terras.
