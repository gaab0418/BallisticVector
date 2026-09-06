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
- **Mapa de Guerra Estratégico (`war_map.gd`)**: Uma interface inspirada em cartas náuticas/steampunk antigas onde o jogador escolhe qual base inimiga (Alpha, Bravo ou Charlie) quer atacar. Cada base possui 3 fases de dificuldade progressiva.
- **Loja de Munições Integrada**: Permite ao jogador comprar munições especializadas (Enferrujada ou Perfurante) utilizando o ouro adquirido em combate. O visual conta com cards detalhados, ícones recortados dinamicamente via `AtlasTexture` de mísseis reais e animações de feedback de compra.
- **Física Balística Customizada (`projectile.gd`)**: Não depende de corpos rígidos do motor para os projéteis. Os tiros seguem equações diferenciais discretas sob ação gravitacional customizada de acordo com o tipo da munição.
- **Mira Preditiva Integrada (`arena.gd`)**: O canhão calcula em tempo real a trajetória parabólica futura do tiro através de um loop de simulação rápida e desenha uma linha tracejada (`AimLine`) que é interrompida exatamente no ponto de colisão com os obstáculos terrestres.
- **IA Inimiga com Evasão Dinâmica (`airplane_enemy.gd`)**: Os aviões realizam patrulhas aéreas e bombardeiam o jogador, mas agora possuem sensores geométricos. Utilizando a API `Geometry2D` do Godot, os aviões detectam se a sua trajetória de voo colidirá com as montanhas e arremetem de volta para cima ou invertem a direção, evitando bater nos obstáculos.

---

## ⌨️ Controles

Durante o combate na **Arena**, o topo central da tela mostra as variáveis da parábola —
ângulo, força e gravidade — cada uma com a sua **engrenagem**. O jogador escolhe uma
engrenagem e a gira para alterar aquele valor, vendo a linha de mira responder na hora.

| Tecla / Ação | Função |
| :--- | :--- |
| **Seta Cima / Seta Baixo** | Escolhe qual engrenagem está selecionada (ângulo, força ou gravidade). |
| **Seta Esquerda / Seta Direita** | Gira a engrenagem selecionada, aumentando ou diminuindo o seu valor. Com o ângulo selecionado — o padrão — isto é a mira de sempre. |
| **Shift (Segurar)** | Gira a engrenagem 5x mais devagar, para acertar o número exato. |
| **Barra de Espaço** | Realiza o disparo do projétil ativo. |
| **Tecla Tab** | Alterna entre os tipos de munição disponíveis no inventário (Enferrujada / Perfurante). Cada munição traz a sua própria gravidade. |
| **Tecla H** ou botão **?** | Pausa o jogo e abre a tela de ajuda, com as teclas e a explicação da parábola. |
| **Esc** | Fecha a tela de ajuda. |

Ao lado das três engrenagens, a HUD calcula em tempo real o **alcance** e a **altura máxima**
do tiro pelas fórmulas do lançamento oblíquo (`R = v²·sen(2θ)/g` e `H = v²·sen²θ/(2g)`),
para que a criança veja a matemática reagir ao que ela está fazendo. Com o canhão apontado
para baixo os dois viram um traço, porque a fórmula só vale com o tiro subindo.

---

## ⚙️ Arquitetura de Áudio e Estado

- **`AudioManager` (Singleton Autoload)**: Gerencia de forma persistente todo o fluxo sonoro entre as trocas de cenas. Utiliza a conexão de sinal `finished` do Godot para implementar loops perfeitos e contínuos de trilha sonora, contornando limitações de runtime.
- **`Global` (Singleton Autoload)**: Mantém o registro do progresso de fases concluídas nas bases, o montante financeiro e o inventário de munições do jogador entre a Arena e o Mapa de Guerra.
- **Mapeamento de Recursos (`AmmoData`)**: Criação de dados de munições baseados em `Resource`, permitindo alterar física, dano, custo e cores diretamente pelo inspetor do editor de forma modular.

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
- **Interface & Ícones**: Packs visuais adaptados da Kenney UI (licença CC0).
- **Músicas e Efeitos**: Coleção de assets sonoros STEAMPUNK/Medieval licenciados para uso no projeto.
