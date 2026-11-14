# ESPECIFICAÇÃO — ESTEIRA IDÊNTICA AO HYDRONEER

Dados coletados da wiki oficial (Bridgepour), guias da comunidade Steam e guias de automação. Objetivo: nossa esteira com a mesma estética e a mesma forma de construção do jogo original.

---

## 1. COMO A ESTEIRA FUNCIONA NO HYDRONEER (dados de referência)

### 1.1 Regra de construção (o mais importante)

- A esteira **NÃO vem com cano** — ela deve ser **encaixada SOBRE um cano de água** (mesmo "cubo" de posicionamento do cano)
- Ordem correta de montagem: **cano → acessórios de cano → esteira → ganchos de esteira**. Fora de ordem, o encaixe falha
- Esteira **vertical** exige 2 cotovelos (um em cada extremidade) para continuar a linha
- Sem cano embaixo, a esteira não é colocada

### 1.2 Energia e velocidade

- A esteira é **movida pela pressão da água** do cano em que está montada
- **Pressão 0 = esteira parada**; pressão maior = correia mais rápida
- Se o cano de baixo secar (falta de água, válvula fechada, cano desconectado), a esteira para — e a linha inteira atrás dela empaca

### 1.3 Direção e fluxo

- **Seta verde** no fantasma de construção indica o sentido do fluxo (direção da água)
- Cano e esteira podem estar "apontando" lados diferentes — o que vale é estarem em contato
- Itens viajam fisicamente sobre a correia e **caem no fim da linha** — o jogador coloca bacia, carrinho, fundidora ou outra esteira embaixo da saída
- Itens caindo no momento do save congelam no ar ao carregar (bug conhecido do original — não vamos reproduzir)

### 1.4 Tipos de peça (loja Conveyor Nation, em Bridgepour)

| Peça | Função |
|---|---|
| Straight Conveyor | Reta padrão, encaixa em cano |
| Vertical Conveyor | Sobe/desce (com cotovelos) |
| Corner/Left-Right Conveyor | Curva de 90° |
| Splitter Conveyor Left/Right | Tem uma **bandeja**: itens colocados nela são desviados para o lado; o resto passa reto |
| Conveyor Hooks (acessórios) | Centraliser (centraliza itens), Gem Polisher (lapida gemas que passam), Merge hooks (juntam duas linhas) |

### 1.5 Estética

- Estrutura metálica escura com **trilhos laterais** (guarda-corpo) dos dois lados
- Correia escura contínua com **roletes/cilindros** nas extremidades
- Montada **por cima do cano** (o cano fica visível embaixo da estrutura)
- Itens visíveis andando sobre a correia
- Na loja, as esteiras ficam cobertas por toldos

---

## 2. NOSSA ESTEIRA HOJE (o que temos) × O QUE FALTA

| Aspecto | Hydroneer | Nosso jogo hoje |
|---|---|---|
| Encaixe | Sobre cano obrigatório | Em corrente (encaixa na drill/outra esteira), sem cano |
| Energia | Pressão da água do cano | Funciona sem água (só desliga por interruptor) |
| Velocidade | Proporcional à pressão | Fixa (2.5/s) |
| Direção | Seta verde no ghost, invertível | Ghost simples, direção do encaixe |
| Vertical | Sim, com cotovelos | Não existe |
| Splitter | Bandeja desvia itens para o lado | Filtro desvia por tipo para cadinho (parecido, mas diferente) |
| Visual | Trilhos + correia escura + roletes sobre o cano | Caixa + 2 trilhos amarelos + 2 cilindros |

---

## 3. PLANO DE IMPLEMENTAÇÃO (marcos E1–E7)

### E1 — Esteira montada sobre cano (mudança central)
- [ ] Ao construir esteira, exigir cano na célula (mesmo encaixe do cano)
- [ ] A esteira nasce montada ~0.4m acima do cano (cano visível embaixo)
- [ ] Compatibilidade com saves antigos: esteira sem cano continua funcionando em velocidade reduzida (60%), com aviso no diagnóstico ("monte sobre um cano para velocidade total")
- [ ] Diagnóstico (H) passa a mostrar: "sem cano embaixo" / "cano sem água"

### E2 — Velocidade pela pressão de água
- [ ] Velocidade da correia = base * fator da pressão do cano de baixo (0 = parada)
- [ ] Cano com válvula fechada para a esteira
- [ ] Status da máquina mostra a velocidade atual (%)
- [ ] Linha inteira sincroniza: esteira de trás só entrega se a da frente estiver movendo

### E3 — Direção com seta verde
- [ ] Ghost de construção ganha seta verde 3D indicando o sentido do fluxo
- [ ] Tecla para inverter o sentido da esteira depois de colocada (E nela abre menu "inverter")
- [ ] Seta também aparece no mapa? (opcional — não obrigatório)

### E4 — Esteira vertical
- [ ] Nova peça "esteira vertical" (sobe ou desce 1 nível de profundidade de escavação)
- [ ] Encaixa com cotovelo de cano em cada extremidade
- [ ] Útil para trazer terra do fundo do poço até a superfície (uso clássico do original)

### E5 — Splitter com bandeja
- [ ] Nova peça "divisor de esteira (esquerda/direita)": bandeja lateral — itens colocados nela caem para o lado
- [ ] Diferente do filtro: o divisor desvia o que VOCÊ põe na bandeja; o filtro desvia por tipo automaticamente
- [ ] Os dois podem coexistir (filtro para automação, divisor para controle manual)

### E6 — Visual idêntico (estética Hydroneer)
- [ ] Estrutura metálica escura em vez de caixa chapada
- [ ] Trilhos laterais mais altos e com pés de sustentação
- [ ] Correia escura contínua sobre roletes que giram quando a linha está ativa
- [ ] Montada sobre o cano visível embaixo
- [ ] Itens "andando" sobre a correia (posição de exibição acompanha o fluxo)
- [ ] Rololets param quando a esteira para (estado visual = estado lógico)

### E7 — Validação
- [ ] Teste F10 com 500+ esteiras em linha
- [ ] Save/load com linhas verticais, splitters e inversões
- [ ] Diagnóstico cobre todos os novos estados de falha

---

## 4. DECISÕES DE DESIGN (diferenças conscientes do original)

1. **Não reproduzir o bug de itens congelados no ar** no save/load
2. **Compatibilidade com saves antigos** mantida (o original quebra builds antigos a cada update; nós não)
3. **Filtro continua existindo** ao lado do splitter (no original o filtro é frágil e precisa de chave inglesa; o nosso não terá desgaste — decisão já tomada no checklist 1)
4. Ganchos (Centraliser/Gem Polisher/Merge) ficam para um marco futuro — dependem de itens físicos na correia, que não é nosso modelo (nós usamos quantidades)
