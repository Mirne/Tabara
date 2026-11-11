# Preview snapshot

`frontier-preview.json` is a saved settlement from the normal-cost rendered
stability run (seed 1001), after its first 15-minute victory. The player bot paid
normal prices, gathered only nearby deposits, and performed at most one paid
action per second. No stress-fixture resources or enemy statistics are used.

The simulation tests restore this legacy snapshot to verify old-save compatibility,
including free building positions. Keep the fixture even though its obsolete video
recorder has been removed. Tests and fixtures are excluded from game exports; a
new installed game begins with only the hall and starting supplies.
