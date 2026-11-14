# CHECKLIST 3 — UPGRADE VISUAL: DO PROCEDURAL ATUAL AO GRÁFICO DO HYDRONEER

Objetivo: transformar o visual atual (primitivas de código: cubos, cilindros e esferas) em um gráfico comparável ao do Hydroneer, mantendo tudo rodando em Godot 4.x Forward+ e sem quebrar o desempenho de end game.

Regra geral: cada fase só começa depois que a anterior estiver 100% marcada. Nada de polimento por cima de geometria quebrada.

---

## FASE A — GEOMETRIA BASE (a fundação: sem isso, nada do resto adianta)

### A1. Água contínua (prioridade máxima — é o pior defeito hoje)

- [ ] Substituir a malha de água por célula por UMA superfície contínua de todo o lago
- [ ] Eliminar os espaços visíveis entre as células de água (soldar vértices das bordas)
- [ ] Superfície única reagindo ao shader de ondas já existente
- [ ] Bordas do lago encontrando o terreno sem fresta (a água encosta na terra, não flutua)
- [ ] Água escavada/desviada pelo jogador continua funcionando com a malha contínua
- [ ] Profundidade visível: fundo do lago escurecendo gradualmente (água rasa clara, funda escura)
- [ ] Espuma estilizada na linha de costa (borda clara onde água encontra terra)
- [ ] Critério: não se vê NENHUMA junção, espaço ou quadrado isolado de água em zoom nenhum

### A2. Terreno com aparência de terra de verdade

- [ ] Paredes de escavação mostrando as camadas (superficial escura, intermediária marrom, funda rochosa) — hoje só a cor do topo
- [ ] Cor do solo variando com ruído (manchas mais claras/escuras, sem cara de plástico)
- [ ] Terra recém-escavada mais escura/úmida que o solo intocado
- [ ] Transição suave entre terra e rocha por profundidade
- [ ] Bordas de escavação com leve irregularidade (não buracos perfeitamente redondos)
- [ ] Critério: um buraco cavado parece um buraco de mina, não um corte de bolo

### A3. Alinhamento e encaixe geral

- [ ] Telhados das casas apoiados nas paredes (sem "voar")
- [ ] Cumeeira fechando o topo do telhado
- [ ] Chaminés atravessando o telhado, não flutuando ao lado
- [ ] Portas e janelas embutidas na parede (sem placa colada no ar)
- [ ] Máquinas montadas em terreno inclinado sem flutuar (base afunda no solo)
- [ ] Auditoria geral: nenhum objeto do mundo flutuando ou atravessando outro

---

## FASE B — REMODELAGEM (substituir cada primitiva por um objeto "de verdade" feito em código)

### B1. Ferramentas e itens de mão

- [ ] Balde ABERTO: parede cilíndrica em cima, interior fundo, asa de arco, borda reforçada — nunca cilindro cheio fechado
- [ ] Balde de água com superfície de líquido visível lá dentro
- [ ] Pá com cabo de madeira segmentado, encaixe metálico e pá com concavidade
- [ ] Escova com cerdas visíveis e madeira
- [ ] Minérios coletáveis como pedaços de rocha irregulares (esfera deformada com ruído), não esferas lisas
- [ ] Gemas como cristais facetados (prisma com pontas), não cubos

### B2. Máquinas (cada uma com forma reconhecível, não cubo com detalhe)

- [ ] Bacia: redonda/escavada, com borda e interior fundo
- [ ] Mercador: barraca de feira com toldo listrado em 2 cores, balcão de madeira, prateleira com produtos, placa pendurada
- [ ] Drill: torre de perfuração com treliça, cabeçote que desce, motor lateral, mangueiras
- [ ] Harvester: funil de entrada grande, correia de saída, chassi sobre esteiras/rodas
- [ ] Forja: forno abobadado com boca de fogo brilhando, chaminé de pedra, fole lateral
- [ ] Bigorna: forma de bigorna real (corpo + bico + base de tronco)
- [ ] Polidora: bancada com disco vertical e proteção
- [ ] Prensa: moldes visíveis, pistão central que desce
- [ ] Gerador: motor com escapamento, tanque de combustível, painel
- [ ] Baú: tampa aberta em ângulo, fechaduras, cantos de metal
- [ ] Silo: cilindro com tampa cônica e pernas de sustentação
- [ ] Canos: junções com flanges (anéis) nas extremidades, não cilindros lisos se encontrando
- [ ] Estátua do Legado: silhueta de figura humana em pedestal
- [ ] Critério: printada a silhueta de cada máquina, dá para adivinhar qual é sem ler o rótulo

### B3. Construções

- [ ] Casas com telhado de duas águas com beiral saliente (não placas rotacionadas)
- [ ] Portas com batente e maçaneta
- [ ] Janelas com moldura e cruzeta
- [ ] Variação entre casas: tamanho, cor e telhado diferentes
- [ ] Cerca com postes + 2 travessas (não blocos)
- [ ] Escada com degraus individuais visíveis
- [ ] Fundação/piso com borda de acabamento

### B4. Mundo

- [ ] Montanhas da borda com forma irregular (ruído no cone, não cones perfeitos)
- [ ] Nuvens em grupos de 2-3 quadros (não quadrados solitários)
- [ ] Árvores com 2-3 formatos de copa diferentes e troncos com curva
- [ ] Pedras com forma irregular deformada
- [ ] Caminhão: cabine + caçamba aberta + rodas com pneus pretos e aro

---

## FASE C — MATERIAIS E TEXTURAS PROCEDURAIS (o que separa "plástico" de "jogo bonito")

- [ ] Texturas de ruído geradas em código (FastNoiseLite renderizada em Image/ImageTexture) para: terra, pedra, madeira, metal
- [ ] Terra: albedo com manchas + roughness variável
- [ ] Madeira: veios (linhas de ruído esticado) em tábuas e vigas
- [ ] Metal: riscos leves + variação de brilho + cantos gastos
- [ ] Pedra: manchas e granulação
- [ ] Ferrugem: material de metal velho para máquinas antigas/estruturas
- [ ] Sistema de materiais compartilhados mantido (texturas geradas 1x e reutilizadas — nunca por instância)
- [ ] Critério: nenhuma superfície do jogo com cor chapada "plástica" a menos de 10m da câmera

---

## FASE D — ILUMINAÇÃO E ATMOSFERA (o toque final que o Hydroneer tem e nós não)

- [ ] Tonemapping ACES/Filmic (cores menos saturadas e mais "foto")
- [ ] Glow só em emissivos fortes (forja, sacradium, lampiões) — nunca na cena toda
- [ ] Sombras suaves (blur maior nas cascatas de sombra)
- [ ] Luz ambiente levemente azulada de dia, escura à noite (não cinza)
- [ ] Névoa de distância com cor casada com o horizonte do céu
- [ ] Poeira suspensa visível contra a luz (god rays simples perto do amanhecer)
- [ ] Água refletindo o céu (reflexo do sol como caminho brilhante na superfície)
- [ ] Interior de escavações profundas escurecendo de verdade (escuridão + necessidade de lampião/luz)
- [ ] Critério: uma screenshot do jogo sem legenda se confunde com uma screenshot do Hydroneer

---

## FASE E — INTERFACE NO ESTILO DO JOGO

- [ ] Painéis com textura de madeira (não cor chapada)
- [ ] Botões com relevo (borda clara em cima, escura embaixo)
- [ ] Ícones desenhados em código para o menu de construção (miniatura da máquina em vez de texto puro)
- [ ] Fonte com personalidade (arredondada/rústica)
- [ ] Cursor de mira estilizado (cruz/martelo, não ponto)
- [ ] Barra de escova e balde com visual de "medidor industrial"

---

## FASE F — ASSETS EXTERNOS (o degrau final para 90-95% — só quando A-E estiverem prontas)

- [ ] Definir fonte dos modelos: packs gratuitos (Kenney, Quaternius) e/ou modelagem própria no Blender
- [ ] Pipeline de importação glTF documentado e testado com 1 máquina piloto
- [ ] Materiais dos modelos mapeados para a biblioteca compartilhada
- [ ] LOD (3 níveis) para cada modelo grande
- [ ] Colisão simplificada separada da malha visual
- [ ] Substituir gradualmente: primeiro máquinas, depois construções, depois vegetação
- [ ] Teste de estresse F10 refeito com os modelos finais (100/500/1000)
- [ ] Critério: o jogo mantém FPS estável em end game com todos os modelos finais

---

## CRITÉRIOS DE ACEITAÇÃO DO CHECKLIST 3

O upgrade só é concluído quando:

- [ ] A água é uma superfície única, bonita e sem falhas
- [ ] Nenhum objeto do mundo flutua, atravessa ou "voa"
- [ ] Cada máquina tem silhueta própria reconhecível
- [ ] O balde abre, a bacia é funda, o mercador parece uma barraca
- [ ] Nenhuma superfície próxima parece plástico chapado
- [ ] A iluminação tem a "cara" do Hydroneer (quente, suave, com glow controlado)
- [ ] A interface parece parte do mesmo universo
- [ ] O desempenho de end game (F10 em 1000) não piorou com nenhuma dessas mudanças
- [ ] Escavações profundas continuam fluidas e bonitas

Ordem de execução: A → B → C → D → E → F.
