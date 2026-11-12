# Hydroneer Releitura

Releitura do Hydroneer feita no **Godot 4**, com o mesmo espírito do original
(escavar, achar ouro, lavar, vender, comprar máquinas) mas com arquitetura
pensada para **performance**: é a resposta ao problema clássico do jogo original,
em que o FPS caía de 150 para 2 porque cada item era uma entidade física separada.

## Como rodar (sem saber programar)

1. Baixe o **Godot 4.3+** (gratuito, sem instalação): https://godotengine.org/download
2. Abra o Godot → **Import** → selecione a pasta `project.godot` deste projeto.
3. Clique em **Play** (F5). Pronto, o jogo abre.

## Controles

| Tecla | Ação |
|---|---|
| WASD | Mover |
| Shift | Correr |
| Espaço | Pular |
| Mouse | Girar câmera |
| Clique esquerdo (segurar) | Cavar |
| E (perto da loja) | Vender pepitas |
| B | Abrir/fechar a loja de upgrades |
| F5 | Salvar |
| F9 | Apagar save e recomeçar |
| Esc | Soltar/prender o mouse |

## O loop de jogo

1. **Cave** o terreno (segure o clique esquerdo). Quanto mais fundo, mais ouro.
2. As **pepitas** aparecem na escavação — ande perto delas para coletar.
3. **Água dobra o ouro**: cave perto da água ou ligue a água ao seu buraco
   (cave uma vala da FONTE D'ÁGUA até a sua cava, igualzinho ao Hydroneer).
4. **Venda** na barraca da loja (E) e compre **upgrades** (B):
   - Pá de Ferro / Pá de Diamante — cavam mais largo, fundo e rápido
   - Balde Grande / Carreta — mais capacidade
   - Bomba d'Água — água onde você cavar
   - Ímã de Pepitas — coleta automática em 7m
   - Esteira de Venda — venda automática
5. **Objetivos** guiados com recompensas (canteiro superior esquerdo).
6. O jogo **salva sozinho** a cada 30s (e no F5).

## Por que isso roda melhor que o original

- **Terreno é uma grade de alturas** (um único mesh): cavar só mexe números e
  remonta a malha, não cria/destrói milhares de objetos.
- **Água é uma simulação em grade** processada em janelas rotativas
  (1/6 das células por tick) — custo constante, sem física de partículas.
- **Pepitas são meshes simples sem física** (coleta por distância), com teto de
  400 ativas — o custo não explode como no original.
- **Sem colisores por bloco**: o chão é uma função de altura analítica.

## Próximos passos (roadmap)

- Maquinário do original: dragas, calhas, crivos e esteiras construíveis
- Mais camadas de profundidade com minérios raros (prata, esmeralda, diamante)
- Modo "claim" com lotes compráveis e expansão de terreno
- Trilhas sonoras/sons (passos, água, "clink" do ouro)
- Exportar para Windows/Linux (Godot faz isso em 1 clique)

## Estrutura do código

```
project.godot          configuração do projeto
scenes/main.tscn       cena principal (tudo é montado por código)
scripts/main.gd        economia, upgrades, objetivos, save/load, mundo
scripts/terrain.gd     terreno escavável + simulação de água
scripts/player.gd      movimento, câmera e mira de escavação
scripts/hud.gd         HUD, loja e avisos
```
