---
name: Feature / task
about: A feature or implementation task
title: ""
labels: "type:feature"
---

## Context

Link the locked decision. Do not copy it.

## Task

Exact files and paths:

Config tables live in `src/ReplicatedStorage/Shared/Config/`. Rojo maps `src/ReplicatedStorage/Shared` to `ReplicatedStorage.Shared`. The roadmap name `src/shared/Config/` is not the folder on disk.

## Acceptance criteria

- [ ]

Required checks (from the repo):

- [ ] `selene src` (0 warnings; `selene tests` is not the gate)
- [ ] `stylua src tests` (tabs, column width 100)
- [ ] `lune run tests/run`
- [ ] `rojo build -o build/Shardfall.rbxlx` (coordination also uses `rojo build -o /tmp/Shardfall.rbxlx`)

## Notion spec link

## Labels to add

Default label is `type:feature`. Add the ones that apply:

- Priority: `priority:P0`, `priority:P1`, or `priority:P2`
- System: `system:gacha`, `system:gear`, `system:dungeon`, `system:rewards`, `system:saving`, or `system:ui`
- Owner: `owner:ghost`, `owner:echo`, `owner:prism`, `owner:coding-agent`, or `needs-kevin`
