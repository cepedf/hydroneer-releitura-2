# Harvester — como funciona no Hydroneer real

Especificação levantada a partir das fontes oficiais/comunidade, no mesmo modelo de `ESTEIRA_HYDRONEER.md`. Objetivo: fazer o nosso Harvester funcionar como o do jogo original.

## 1. Dados de referência (pesquisa)

- **Wiki Bridgepour** (bridgepour.com/database/harvester): "Tier N harvester. **Breaks dirt chunks into resources. Bigger yield with better water pressure. Gets damaged from unfiltered water.**" Tiers: T1 Forged Iron, T2 Cloutium, T3 Corestone (T2+ forjados no Icehelm).
- **Fandom wiki**: "Powered by water. **Place dirt chunks in the top**. Ores and uncut gems **exit via the front slot**. **Water is input on the back or side via pipes.**"
- **TechRaptor** (guia): "**Place a Harvester directly underneath the Drill's output** — this will automatically convert the Dirt clumps into Resources."
- **Reddit** (r/Hydroneer): "Dirt chunks extracted by a drill can be processed by a harvester at any depth and are still treated as the tier they were extracted from" — a terra preserva o tier de origem.
- **Namu.wiki**: o harvester funciona como o drill — **alimentado por água na entrada via canos**; "Clear All Soil Chunks" no menu ESC quando a terra acumula.
- **Bridgepour Tier One guide**: "grab your Harvester and **attach it to the last straight pipe**... place a **pan in front of the harvester**, otherwise it'll make a mess" — a saída é física, pela frente.

### Resumo do comportamento real

1. **Movido a ÁGUA**: entrada de água por canos (atrás ou lateral). Sem água = parado.
2. **Rendimento escala com a pressão**: melhor pressão nos canos = mais rápido processa.
3. **Alimentação**: terra no topo (manual, jogando os chunks) ou direto na saída da drill (acoplado embaixo dela).
4. **Saída**: minérios e gemas brutos saem pelo slot frontal (fisicamente, no chão/panela na frente).
5. **Dano**: água sem filtro danifica a máquina com o tempo.

## 2. Nosso jogo hoje × Hydroneer

| Aspecto | Hydroneer | Nosso jogo hoje | Ação |
|---|---|---|---|
| Energia | Água por canos, obrigatória | **Não usa água** — funciona seco | H1: água obrigatória via `pipe_factor_at` |
| Rendimento | Escala com a pressão | Fixo (`rate` do tier) | H1/H4: `budget = rate * fator * dt` |
| Alimentação por drill | Acoplado direto na saída da drill | Puxa de qualquer drill a **10m** (telecinese) | H2: drill a 2,6m (igual esteira) |
| Alimentação manual | Joga terra no topo | Impossível | H3: despejar balde nele (E) |
| Saída | Slot frontal físico | Caixa interna ou esteira | **Decisão**: manter caixa/esteira (evita spam de pickups); documentado |
| Dano por água suja | Sim | Não | **Decisão**: não implementar (mesma postura da esteira E) |
| Tier da terra | Preserva o tier de origem | Preserva (roll pela zona) | Já correto |

## 3. Marcos

- [x] **H1 — Água obrigatória**: `factor = pipe_factor_at(m["pos"])` no branch do harvester; `budget = rate * factor * dt`; `factor <= 0.05` → parado (`active = false`), como a esteira. Sem cano nenhum = 0.6 (compat com saves antigos: harvester continua funcionando a 60%, igual à esteira E1).
- [x] **H2 — Alimentação correta**: drill a **2,6m** (encostada na saída, como no Hydroneer), esteira a 3,5m, silo a 3,5m. `PULL_RADIUS` de 10m removido.
- [x] **H3 — Entrada manual**: apertar E mirando no harvester com terra no balde despeja a terra nele (cap 40 + 20×tier), flash de confirmação.
- [x] **H4 — Rendimento pela pressão**: coberto pelo `factor` no budget; gemas continuam 5%.
- [x] **H5 — Diagnóstico (H)**: mostra estado da água (conectada 100% / cano seco / sem cano 60%) e "Recebendo terra: OK/parado" com as distâncias novas.
- [x] **H6 — Validação**: F10 (stress), save/load (nenhum campo novo — o fator é calculado em tempo real), showroom (visual não muda).

## 4. Decisões conscientes

1. **Sem dano por água suja**: no Hydroneer água sem filtro danifica o harvester. Não temos sistema de durabilidade de máquinas; adicionar agora criaria uma espiral de punição sem contraparte (não temos filtro de água para canos). Fica documentado para o futuro.
2. **Saída em caixa/esteira em vez de slot frontal físico**: o slot frontal spawna pickups no chão — com nossa escala de automação (F10: milhares de itens) isso viraria spam de nós físicos. A caixa interna + esteira na saída cumprem o mesmo papel de fluxo com custo zero de física.
3. **Compat com saves**: harvester salvo sem cano por perto roda a 60% (mesma regra da esteira E1), então nenhuma build antiga quebra.
4. **Cap de terra manual**: 40 + 20×tier (mesma fórmula do drill) — o harvester consome rápido, o cap só evita acúmulo infinito.
