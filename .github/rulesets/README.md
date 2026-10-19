# Rulesets e ambientes

As rulesets abaixo **nao se aplicam sozinhas**: o GitHub so as le por
Settings -> Rules -> Rulesets -> New ruleset -> Import a ruleset (um arquivo
por vez).

| Arquivo | Protege | Resumo |
|---|---|---|
| `development.json` | `development` | PR obrigatorio, CI + gate verdes, 0 aprovacoes, squash ou merge |
| `staging.json` | `staging` | PR obrigatorio, 1 aprovacao, CI + gate, so merge commit |
| `main.json` | `main` | igual a staging |
| `tags.json` | tags `v*` | impede apagar ou mover uma release publicada |

Admins do repositorio podem contornar apenas via PR (`bypass_mode: pull_request`).
Isso evita ficar travado quando so ha uma pessoa para aprovar; remova o bloco
`bypass_actors` se quiser regra sem excecao.

Merge commit em staging/main e proposital: com squash, `development` e
`staging` divergem a cada promocao e o proximo PR volta cheio de conflito.

## Environments

Crie em Settings -> Environments: `staging` e `production`. O `deploy.yml`
escolhe um deles pela branch. Em `production`, ative *Required reviewers* e
restrinja *Deployment branches* a `main` (em `staging`, a `staging`).

## Versao

`VERSION` na raiz define a base da tag. Staging gera `v<VERSION>-rc.<run>`;
main gera `v<VERSION>` e falha se ela ja existir, entao incremente
`VERSION` no PR de staging -> main.
