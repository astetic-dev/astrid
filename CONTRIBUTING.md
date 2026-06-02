# Contributing

Thanks for your interest in extending Astrid. It's designed to be built on — the data model is deliberately open so new card types, specialist personas, UIs, and integrations plug in without rework.

## The shape of the project

- **The schemas are the contract.** Everything in `reference/schemas/` defines what a card is. Tooling and any companion read against these. Change a schema thoughtfully: additive (new optional fields) where possible; bump `schema_version` on a breaking change.
- **The docs are the spec.** `reference/data-model.md` is the source of truth for the card graph, id formats, relationships, and the terminal-status table. If you change behavior, update it there.
- **Astrid's character lives in** `identity.md`, `spirit.md`, and `rules.md`. Keep additions consistent with the spirit's hard lines (no manipulation, no adversaries, truth over leverage).

## Adding a card type

1. Add `reference/schemas/<type>-card-v1.schema.json` (Draft 2020-12, `additionalProperties: false`, an `id` pattern, a `schema_version` const).
2. Decide its id format and folder, and add both to `reference/data-model.md` (id table, folder layout, relationships, terminal-status table).
3. Teach `scripts/rebuild-index.ps1` to index it (the `$otherTypes` table) and `scripts/validate-cards.ps1` to validate it (the `$types` table).
4. If it should appear on the dashboard, extend the Project register in `scripts/generate-dashboard.ps1`.
5. Add a worked instance to `sample-workspace/` and re-run the three scripts.

## Building a UI or renderer (most-wanted)

The shipped `dashboard.html` is one read-only renderer — not *the* UI. Building a better one is the most welcome contribution there is. A few ground rules keep it interoperable:

- **Read and write the schemas, nothing else.** Treat `reference/schemas/` as the API. A UI that creates or edits cards must produce files that pass `validate-cards.ps1`.
- **The card files are the source of truth.** `_index/` is a disposable, derived cache (rebuilt by `rebuild-index.ps1`) — read it for speed, never treat it as authoritative, and don't hand-edit it.
- **Keep ids and links valid.** Filenames match the card `id`; cross-references must match the target type's id pattern (see `reference/data-model.md`).
- Anything goes for the rest — web app, TUI, mobile, an Obsidian/Notion sync, an inline editor. Link your project back in a PR or discussion and we'll list it.

## Validating your change

From a workspace root (the sample is fine):

```powershell
pwsh -File scripts/rebuild-index.ps1 -Root .
pwsh -File scripts/validate-cards.ps1 -Root .     # install ajv-cli for full validation: npm i -g ajv-cli
pwsh -File scripts/generate-dashboard.ps1 -Root .
```

A PR should leave the sample workspace valid (all cards pass) and the dashboard building cleanly.

## Style

- Match the existing prose register in the docs (plain, concrete, no filler).
- Keep the tooling dependency-free where it can be (PowerShell only; Node/ajv strictly optional).
- Keep it light. The whole project exists in the narrow band between "nothing is tracked" and "maintaining the tracker is its own job." New fields and ceremony must earn their place.

## License

By contributing you agree your contributions are licensed under the project's [MIT License](LICENSE).
