# Repository workflow

Before implementing any gameplay, UI, economy, enemy, or rendering change, read
`docs/gameplay/NOTES.md`, `docs/gameplay/INDEX.md`, and the Markdown specification
for every affected building/NPC. Update those specifications from the owner's
explicit requests before changing code. Read them again before implementation.
Do not invent economy changes, cooldowns, balance adjustments, upgrade effects,
or tutorial copy. Preserve unspecified behavior. Ask when requested behavior is
ambiguous; record the owner's answer. Do not add filler tooltips or repeat
instructions about where upgrades/Regeneration live. Show actual current/next
stats, prices, and actionable errors instead. These are persistent owner rules.

Work directly on `main`, as requested by the owner. Do not create feature or
download branches unless the user explicitly asks for one. Keep the current
tested APK and checksum in `builds/`; temporary builds and caches stay ignored.

Preserve release tags and existing APK download links. Historical APK commits are
merged into main so their fixed URLs remain reachable. Older reports and art
are available through the release tags linked in `docs/HISTORY.md`.

Before removing runtime art or geography, check legacy save layouts 0–4 as well
as the current off-path resource layout 5. Keep signing keys outside Git. For gameplay or
runtime asset changes, use `tools/verify.py` (add `--ui` when rendering or mobile
interaction is affected) with an isolated `XDG_DATA_HOME`.
