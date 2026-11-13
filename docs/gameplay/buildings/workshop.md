# Workshop

One per settlement. Cost 140 wood/100 stone/70 gold, base HP 750; construction
takes six game seconds. Preserve construction time; upgrade purchases have no timer.
Upgrades lists Wall, Arrow tower, Cannon tower, and Regeneration. Woodcutter and
Quarry upgrades move to those individual buildings. Regeneration is an upgrade
subject here, not a separate Regen tab. Purchase buttons read Upgrade.
Show concrete current/next effects, exact price, and only actionable unavailable
states. Remove generic "instant/all current and future" copy.
Regeneration level 0 is locked; level 100 heals 20% maximum HP/sec, with stronger
growth than v0.9. It heals completed standing buildings, never resurrects them.
Completed defense levels and Regeneration persist if Workshop is destroyed.
Workshop health upgrades are local under Building; Hall and Marketplace upgrades
are on their respective panels. Only defense levels and Regeneration are global.

Level-one upgrade price: 70 wood / 60 stone / 40 gold. Later upgrade
prices scale by 1.15^(current level - 1), rounded up per resource.
