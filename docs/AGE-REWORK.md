# Tabara settlement ages

## Play experience

The Main hall advances the settlement through eight medieval tiers. Wood begins with rough beams and shingle roofs. Stone introduces low masonry, Iron adds dark straps and fittings, and Steel brings stronger trusses. Keep, Castle, Citadel and Crown deepen the fortifications through buttresses, battlements, towers and heraldry. Rural buildings keep their working silhouettes: a woodcutter should still read as a woodcutter at Crown. The age names after Iron are design choices.

A new settlement has a single timber yard at the northern woodland edge and one quarry by the southern limestone. The approach through the pass stays clear. A player builds each producer once and spends at its local panel to improve it. Rebuilding uses the same site. The existing Marketplace supplies gold. Loaded settlements keep the sites and producers they paid for.

## Implementation and playtest plan

| Stage | Work | Acceptance check |
| --- | --- | --- |
| Establish the opening | Play the current economy, map the Hall approach and check the two proposed yards against terrain and screen framing. | Both sites read as part of the landscape and remain reachable and selectable with touch. |
| Age progression | Put age advancement on the Main hall. Show the next Hall painting, price and research access before purchase. Keep Hall combat levels and preserve old purchases. | A paid advancement changes standing buildings, construction previews, icons and future construction. Reload restores the same age. |
| Workshop choices | Give arrow and cannon towers separate research lines. Arrow towers research damage, reach and firing cadence. Cannons research damage, blast radius and loading speed. Expose current and next values. | A purchase changes the selected stat in combat and applies to replacement towers. |
| Paint the settlement | Generate and inspect eight sets of building paintings, six research icons per age and dedicated resource yards. Align foundations, keep connected walls continuous and check small icons at phone size. | Compare Wood, Iron and Crown views of the same settlement, plus contact sheets for intermediate tiers. |
| Play and tune | Compare normal-cost campaigns with different spending orders. Record age and research timing against the 05:00, 10:00 and 15:00 bosses. Exercise movement, targeting, save/reload and rebuilding over extended play. | Record observed outcomes and distinguish paid campaigns from resource-granted fixtures used to see late art and test migration. |
| Deliver on Android | Test the signed update over v0.12, exercise the touch purchase flow and run the source/render suite. Publish a GitHub release and verify its downloadable APK. | Installable download, migration evidence and release notes describe the tested build. |

Seven hours of development and testing were requested. Time is measured from 16:59 Prague time on 20 November 2026. Concurrent workers, accelerated game clocks and separate campaign seeds do not add to elapsed time. The [verification record](QA.md) includes the measured duration, paid campaign results and Android update checks.

## Painted age sets

Each row in the [building sheet](screenshots/age-buildings.jpg) shows one age, from Wood through Crown. Its columns are Hall, woodcutter, quarry, Marketplace, arrow tower, cannon tower, Workshop and the wall catalogue icon. Connected walls use eight corresponding sets of wall materials. The [Workshop sheet](screenshots/age-workshop-icons.jpg) shows three arrow projects followed by three cannon projects for each age.

## Results

Stone opens Bow limbs and Burst shells. Iron opens Quick nocking and Loading crew. Later ages raise the rank ceiling so a player can specialize further. Advancing to Crown and killing the final Warlord are separate goals. Two runs from the same paid opening reached Crown by prioritizing production, while a successful defense held the final Warlord in Iron with mixed tower fire and walls. [Paid Crown runs](verification/settlement-ages/paid-late-strategies.json) · [Verification record](QA.md)
