# Repository workflow

Work directly on `master`, as requested by the owner. Do not create feature or
download branches unless the user explicitly asks for one. Keep the current
tested APK and checksum in `builds/`; temporary builds and caches stay ignored.

Preserve release tags and existing APK download links. Historical APK commits are
merged into master so their fixed URLs remain reachable. Older reports and art
are available through the release tags linked in `docs/HISTORY.md`.

Before removing runtime art or geography, check legacy save layouts 0–2 as well
as the current woodland layout 3. Keep signing keys outside Git. For gameplay or
runtime asset changes, use `tools/verify.py` (add `--ui` when rendering or mobile
interaction is affected) with an isolated `XDG_DATA_HOME`.
