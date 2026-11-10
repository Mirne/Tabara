# Preview snapshot

`frontier-preview.json` is a saved settlement from the normal-cost rendered
stability run (seed 1001), after its first 15-minute victory. The player bot paid
normal prices, gathered only nearby deposits, and performed at most one paid
action per second. No stress-fixture resources or enemy statistics are used.

`tests/record_preview.gd` restores this fixture into an isolated user-data profile
and runs a 30-second normal-cost warmup, then performs scripted camera moves and
ordinary paid construction/upgrade/dismantle actions. The game export excludes
all tests and fixtures; a new installed game still begins with only its hall
and starting supplies.

The helper waits for `/tmp/tabara-frontier-preview.start` so a recorder can attach
before the timed tour. Delete that flag before launching, then create it after
the recorder starts. Use a separate Godot user-data profile.
