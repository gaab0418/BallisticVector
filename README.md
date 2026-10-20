# 🚀 Ballistic Vector — PAC #1

**Ballistic Vector** é um jogo tático de combate e simulação balística 2D desenvolvido em **Godot 4.6** (utilizando o renderizador *GL Compatibility*). O jogo foi construído como parte do Projeto Acadêmico Curricular (PAC #1), com foco em *edutainment* (educação matemática) para auxiliar na visualização prática e intuitiva de **Funções Quadráticas** e mecânicas balísticas parabólicas.

---

## 🎮 O Jogo e Core Loop

O jogador assume o comando de um canhão de defesa terrestre com o objetivo de proteger seu território contra bombardeios de esquadrões de aviões inimigos e destruir o *bunker* inimigo (Boss) de cada fase.

```
[Mapa de Guerra] ── Seleciona Base (Alpha, Bravo, Charlie) ──> [Loja de Munições]
       ▲                                                                │
       │                                                                ▼
[Vitória na Campanha] <── Completar 3 Fases <── [Arena de Combate (Turnos Físicos)]
```

### Principais Funcionalidades Implementadas:
- **Mapa de Guerra Cartesiano (`war_map.gd`, `war_table.gd`)**: um pergaminho sobre a mesa de comando, desenhado em código, que é um **plano cartesiano** — grade, eixos x e y numerados e cada base numa ilha com coordenadas. As rotas entre as bases são arcos de parábola; ao conquistar uma base, um barquinho navega a rota até a próxima. Medalhas e bolinhas de fase mostram o progresso; ilhas bloqueadas ficam sob névoa e abrem em ordem (ou todas, no Modo Professor).
- **Loja de Munições Integrada**: Permite ao jogador comprar munições especializadas (Enferrujada ou Perfurante) utilizando o ouro adquirido em combate. O visual conta com cards padronizados, ícones de munição desenhados proceduralmente (`ammo_icon.gd`, que colore a ponta com a cor do `AmmoData`) e animações de feedback de compra.
- **Física Balística Customizada (`projectile.gd`)**: Não depende de corpos rígidos do motor para os projéteis. Os tiros seguem equações diferenciais discretas sob ação gravitacional customizada de acordo com o tipo da munição.
- **Parábola Visível (`trajectory_view.gd`, `ballistics.gd`)**: A trajetória é desenhada pela própria equação `y = ax² + bx + c`, com o **vértice** (altura máxima), a **raiz** (alcance) sobre uma **régua em metros** no chão, o ponto onde a bala bate numa montanha e a faixa onde ela pode cair. A física, a mira e a HUD usam a mesma escala (`Ballistics.PX_PER_METER = 50`), então o número do painel é o mesmo que a régua mostra.
- **Campanha de 5 Capítulos + Ilha Bônus (`campaign.gd`)**: cada base ensina uma ideia — Alpha (o ângulo), Bravo (a força), Charlie (a gravidade, na Lua, em Júpiter e em Marte), Delta (a translação, com o tanque andando), **Echo (o vértice e o delta)**: a linha `y = h` aparece no mundo e o jogo mostra se a parábola a cruza 2, 1 ou 0 vezes (Δ > 0, = 0, < 0) — e a **Ilha Invertida** (bônus): gravidade para cima, `a > 0`, parábola de boca para cima e vértice como ponto **mínimo**. Cada fase começa com um cartão de missão e vale até **3 estrelas** por desafios matemáticos (ângulos complementares, vértice numa faixa de altura, estourar um balão subindo e outro descendo…).
- **Inimigos e alvos variados**: aviões, balões amarrados com a altura escrita na corda, **bunkers** que só quebram com tiro caindo de cima (descida ≥ 40°), **tanques inimigos** que andam e revidam, e castelos que racham, soltam fumaça e pegam fogo a cada acerto.
- **Laboratório**: modo livre (menu principal), sem inimigos e com mira perfeita. Troque de mundo (Terra, Lua, Marte, Júpiter, Invertido), clique no céu para pôr um alvo e veja a **tabela de pontos (x, y)**: a altura medida na bala, metro a metro, ao lado da altura que a equação prevê.
- **Progresso salvo**: estrelas, bases, ouro e munição ficam em `user://progresso.cfg` (salvamento automático). O menu mostra "Continuar" e tem "Recomeçar campanha" com confirmação. Sem munição e sem ouro, o mapa entrega um **kit de emergência**.
- **Modo Professor**: no menu principal; libera todas as bases e já abre a "conta" da parábola (a, b, c, vértice e Bhaskara com os números da tela) para mostrar em aula.
- **IA Inimiga com Evasão Dinâmica (`airplane_enemy.gd`)**: Os aviões realizam patrulhas aéreas e bombardeiam o jogador, mas agora possuem sensores geométricos. Utilizando a API `Geometry2D` do Godot, os aviões detectam se a sua trajetória de voo colidirá com as montanhas e arremetem de volta para cima ou invertem a direção, evitando bater nos obstáculos.

---

## ⌨️ Controles

Durante o combate na **Arena**, o topo central da tela mostra a **equação da trajetória**
(`y = ax² + bx + c`) e as variáveis da parábola — ângulo, força e gravidade — cada uma com a sua
**engrenagem**. O jogador escolhe uma engrenagem e a gira para alterar aquele valor, vendo a curva,
a equação e os números responderem na hora. Embaixo de cada engrenagem, os chips "mexe no a b"
mostram quais coeficientes da equação ela altera, e esses coeficientes ganham destaque na equação.

| Tecla / Ação | Função |
| :--- | :--- |
| **Seta Esquerda / Seta Direita** | Escolhe qual engrenagem está selecionada, seguindo a ordem em que elas aparecem na HUD. |
| **Seta Cima / Seta Baixo** | Gira a engrenagem selecionada, aumentando ou diminuindo o seu valor. Com o ângulo selecionado — o padrão — a seta para cima levanta o canhão. |
| **Mouse (segurar e girar)** | Agarra a engrenagem e a gira como uma manivela: o valor acompanha o movimento circular do cursor em volta dela. Duas voltas percorrem a faixa inteira. |
| **Shift (Segurar)** | Gira a engrenagem 5x mais devagar, para acertar o número exato. |
| **Barra de Espaço** | Realiza o disparo do projétil ativo. |
| **Tecla Tab** | Alterna entre os tipos de munição disponíveis no inventário (Enferrujada / Perfurante). Na Terra cada munição traz a sua própria gravidade; num planeta, a gravidade é a do planeta. |
| **A / D** | Anda com o tanque dentro da faixa de manobra (só nas fases da Base Delta). |
| **Clique no céu** (Laboratório) | Põe um alvo: o painel mostra as coordenadas e a que distância a curva passa dele. |
| **Tecla F** ou botão **Ver conta** | Abre a "conta por trás da curva": de onde saem a, b, c, o vértice e a raiz (Bhaskara). |
| **Tecla H** ou botão **?** | Pausa o jogo e abre a ajuda, com as teclas, um diagrama da parábola e o efeito de cada engrenagem. |
| **Esc** | Abre o menu de pausa. Com a ajuda ou o menu já aberto, fecha o que estiver na frente. |
| **Botão de engrenagem** (canto superior esquerdo) | Abre o menu de pausa: continuar, ajustes de áudio, reiniciar a batalha ou voltar ao mapa de guerra. |

Ao lado das engrenagens, a HUD mostra a **altura máxima** (vértice, losango ◆) e o **alcance**
(raiz, bandeira) — os mesmos símbolos e cores desenhados na curva. A missão da fase aparece ao
entrar; depois fica recolhida no **botão de estrela** (canto superior direito, com o placar),
que reabre o cartão com o progresso de cada desafio. Com o canhão apontado para
baixo não há vértice à frente, e o painel diz "Levante o canhão para formar a parábola". A
imprecisão da munição aparece como uma faixa sobre a régua: "a bala pode cair aqui".

Menu, mapa, loja e modais também navegam por teclado (setas + Enter), com foco visível.

---

## ⚙️ Arquitetura de Áudio e Estado

- **`AudioManager` (Singleton Autoload)**: Gerencia de forma persistente todo o fluxo sonoro entre as trocas de cenas. Utiliza a conexão de sinal `finished` do Godot para implementar loops perfeitos e contínuos de trilha sonora, contornando limitações de runtime.
- **`Global` (Singleton Autoload)**: Mantém o registro do progresso de fases concluídas nas bases, o montante financeiro e o inventário de munições do jogador entre a Arena e o Mapa de Guerra.
- **Mapeamento de Recursos (`AmmoData`)**: Criação de dados de munições baseados em `Resource`, permitindo alterar física, dano, custo e cores diretamente pelo inspetor do editor de forma modular.

---

## 🎨 Sistema de Interface

Toda a UI compartilha um único sistema de estilo, em `scripts/ui/`:

- **`ui_tokens.gd`**: fonte única de cores, fontes, escala tipográfica e geometria. Nenhum literal de cor, de fonte ou de tamanho de fonte deve existir fora dele.
- **`ui_theme.gd`**: compila o `Theme` do jogo a partir dos tokens. O resultado é gravado em `assets/resources/ui_theme.tres` e registrado em `project.godot` como `gui/theme/custom`. **Ao mexer nos tokens, regenere:**

```bash
godot --headless --script res://tools/build_ui_theme.gd
```

> O tema precisa ser um recurso de projeto, e não algo aplicado pela árvore de nós, porque `CanvasLayer` **interrompe a herança de tema** — e menu, HUD e todos os modais deste jogo vivem em `CanvasLayer`.

- **`ui_frame.gd`**: moldura em pixel art (contorno escuro, anel de latão com bisel, cantos chanfrados, rebites e sombra dura), desenhada só com retângulos — nítida em qualquer filtro e escala.
- **`ui_button.gd`**, **`ui_panel.gd`**, **`ui_modal.gd`**: componentes reutilizáveis. O `UiModal` centraliza com `CenterContainer` (e não `PRESET_CENTER`, que não acompanha a resolução) e concentra a pausa deferida.
- **`arena_hud.gd`**, **`shop_panel.gd`**, **`pause_menu.gd`**: as telas montadas sobre esses componentes.

### Paleta e papéis de cor

A paleta vem dos próprios assets (céu crepuscular do `camp.jpg`, verde do tanque, pedra do castelo, papel do mapa). Três cores de destaque têm **um significado só** em todo o jogo, e nunca aparecem sozinhas — sempre com ícone, forma ou texto:

| Papel | Token | Uso |
| :--- | :--- | :--- |
| Âmbar | `EDITABLE` | O que o jogador pode mudar: engrenagens, foco, ação principal |
| Cor da mira do mundo | `WORLD_*.aim` | O que o jogo calculou na arena: curva, vértice, raiz e os resultados do painel — vermelho-alaranjado na Terra, azul na Lua, em Marte e em Júpiter (onde o céu pede contraste). Sempre a mesma no painel e na curva daquela fase. |
| Ciano | `CALCULATED` | Resultados calculados fora da arena (menus, ajuda) |
| Carmim | `DANGER` | Dano, perigo, ação destrutiva |

### Tipografia

- **VT323** (OFL) para texto, números e fórmulas — dígitos inequívocos (o 5 não vira S, o 8 não vira B) e "i" com pingo nítido em qualquer corpo.
- **Handjet** (OFL) apenas como fallback, para θ e setas.
- **Jersey 10** (OFL) para títulos e logotipo.

Os papéis de texto são variações do tema (`Label.theme_type_variation`): `TitleLabel`, `DisplayLabel`, `HeadingLabel`, `CaptionLabel`, `EditableLabel`, `ResultLabel`, `DangerLabel`, `OverlayLabel` e `InkLabel`. Ícones que as fontes não têm (vértice, raiz, estrela, cadeado, escudo…) são desenhados em código por `UiIcon`. Licenças em `CREDITS.md`.

### Matemática e conteúdo

- **`scripts/ballistics.gd`**: fonte única da escala (50 px = 1 m) e da conta do tiro — coeficientes, vértice (−b/2a), raiz (Bhaskara), faixa de queda e formatação de números em português.
- **`scripts/campaign.gd`**: capítulos, fases, lições, cenários e desafios das estrelas. As montanhas são listadas pelos picos e arredondadas por `Campaign.rounded()` (spline que passa pelos picos, então a altura não muda); desenho e colisão usam o mesmo contorno.

---

## 🧪 Testes Automáticos

`tools/tests/test_runner.gd` roda na CI depois do import e protege as garantias do jogo:
todo script compila, todo obstáculo é um polígono válido, **todo alvo de toda fase é
atingível** (e as metas de vértice são cumpríveis), a **bala real cai onde a HUD diz**,
cada tela abre e o save volta igual ao carregar. Para rodar localmente:

```bash
BV_SAVE_PATH=/tmp/teste.cfg godot --headless --script res://tools/tests/test_runner.gd
```

`BV_SAVE_PATH` troca o arquivo de progresso, para os testes nunca tocarem no save real.

---

## 🔄 CI/CD e Releases

Todo código entra por Pull Request e sobe por três branches. Cada uma tem a sua própria regra (rulesets em [`.github/rulesets/`](.github/rulesets/README.md)):

```
feature/* ──PR──▶ development ──PR──▶ staging ──PR──▶ main
                                         │               │
                                    push = tag       push = tag
                                    v0.7.0-rc.N      v0.7.0
                                    env: staging     env: production
```

| Branch | Para que serve | O que acontece no push |
| :--- | :--- | :--- |
| `development` | Integração do dia a dia. Recebe qualquer branch de trabalho. | Só o CI (lint, import e testes). |
| `staging` | Candidata a release, para validar antes de produção. | Valida, exporta Windows e Linux e publica uma **pre-release** `v<VERSION>-rc.<n>`. |
| `main` | Produção. | Valida, exporta e publica a **release** `v<VERSION>`, com aprovação no environment `production`. |

**Versão e tags.** A tag nunca é criada à mão: ela sai do arquivo [`VERSION`](VERSION) (`X.Y.Z`). Quem decide o número é você, ao editar o arquivo: correção vira `0.7.1`, funcionalidade nova vira `0.8.0`. A tag de `main` é imutável. Se `v<VERSION>` já existir, o PR para `main` falha no check **Gate de promoção**, antes do merge. Criar a tag com `git tag` também não funciona: o deploy só roda em push para `staging` e `main` e não geraria binários.

**Passo a passo de uma entrega:**
1. Crie `feature/...` a partir de `development` e abra o PR para `development`.
2. Para lançar, edite o `VERSION` num PR para `development` (pode ser o da própria feature).
3. Abra `development` → `staging`. Depois do merge, confira a pre-release `v<VERSION>-rc.<n>` e teste o build.
4. Abra `staging` → `main`. Depois do merge, aprove o deploy em `production` e a release `v<VERSION>` é publicada.

**Como fazer uma correção (ex.: `v0.7.1`):**
1. Crie a branch da correção a partir de `development`.
2. No mesmo PR da correção, mude o `VERSION` para `0.7.1`.
3. Faça o fluxo normal: PR para `development`, depois `staging` (sai `v0.7.1-rc.N`) e depois `main` (sai `v0.7.1`).

Não crie a tag com `git tag`: ela sai sozinha do `VERSION` no deploy.

**Regras que valem em `staging` e `main`:** PR obrigatório, 1 aprovação, checks `Lint e importacao` e `Gate de promocao` verdes, e **só merge commit** (squash faz `development` e `staging` divergirem a cada promoção). Para rodar o lint localmente antes do push, veja [`requirements-dev.txt`](requirements-dev.txt).

---

## 🛠️ Como Executar o Projeto

### Pré-requisitos
- **Godot Engine 4.6** ou superior (Standard Edition).

### Passos para Execução:
1. Clone o repositório ou faça o download da pasta do projeto.
2. Abra a **Godot Engine** e clique em **Importar** (Import).
3. Navegue até a pasta `BallisticVector` e selecione o arquivo `project.godot`.
4. Clique em **Importar & Editar** (Import & Edit).
5. Pressione **F5** (ou clique no botão Play no canto superior direito) para rodar o jogo. A cena padrão inicial configurada é o Menu de Boas Vindas (`menu_play.tscn`).

---

## 🎨 Créditos de Assets
Veja [`CREDITS.md`](CREDITS.md): fontes (OFL), ícones Kenney (CC0), arte procedural e áudio.
