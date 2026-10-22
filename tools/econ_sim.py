#!/usr/bin/env python3
"""Shardfall economy sim (docs/research/economy_v1.md, section 9).

Deterministic: seed 42. Run: python3 tools/econ_sim.py
Inputs are copied from the sheet. CURRENT values cite their repo file in the
sheet; everything marked PROPOSED is a sheet proposal, not live config.
"""
import random, statistics as st

SEED = 42
PLAYERS = 1000
HOURS = 10

# ---- Income (PROPOSED unless noted) ----
WAVE_TOK = [1, 1, 2, 2, 5]                      # PROPOSED, Normal clear = 11
DIFFS = {  # mult, run minutes, level gate      # all PROPOSED except gates N/H/NM (Rootvault.luau)
    "normal":    (1.00, 5.0, 1),
    "medium":    (1.25, 5.5, 5),
    "hard":      (1.50, 6.0, 10),
    "nightmare": (2.00, 7.0, 15),
    "insane":    (3.00, 9.0, 20),
}
LEVEL_HOURS = {1: 0.0, 5: 0.37, 10: 2.58, 15: 7.77, 20: 16.79}  # docs/design/pacing.md
FAIL = 0.10                                      # PROPOSED share of failed runs
FIRST_CLEAR_DAY = 5                              # PROPOSED
DAILY = 2 + 3 * 3 + 5 + 7                        # PROPOSED login + 3 dailies + all-3 + weekly share
PLAY_MIN_PER_DAY = 120                           # sim assumption
STARTER_TOKENS = 10                              # CURRENT Schema.STARTER_TOKENS
FREE_ROLLS = 3                                   # PROPOSED
X10_COST = 9                                     # CURRENT RollConfig.cost(10)
BONUS_EVERY = 10                                 # CURRENT RollConfig.BONUS_EVERY
EPIC_PITY = 50                                   # CURRENT RollConfig.EPIC_PITY
BAG_CAP = 100                                    # CURRENT Schema.INVENTORY_CAP

TABS = {"Weapons": 0.40, "Armor": 0.25, "Pets": 0.20, "Skills": 0.15}  # PROPOSED spread

def half_up(x):
    return int(x + 0.5)

# ---- Rarity models ----
MODELS = {
    "current7": dict(  # CURRENT RarityConfig ONE_IN + LEGENDARY_PITY 1000, no soft pity
        ladder=[("Secret", 100000), ("Mythic", 25000), ("Legendary", 2500), ("Epic", 250), ("Rare", 25), ("Uncommon", 5)],
        leg_pity=1000, soft_from=None, soft_step=0.0,
        pool={"Common": 12, "Uncommon": 10, "Rare": 8, "Epic": 6, "Legendary": 4, "Mythic": 2, "Secret": 1},
        frag={"Common": 1, "Uncommon": 3, "Rare": 10, "Epic": 40, "Legendary": 200, "Mythic": 1000, "Secret": 1000},
    ),
    "proposed5": dict(  # PROPOSED 5 tiers, Legendary hard pity 150, soft pity from 100
        ladder=[("Legendary", 1000), ("Epic", 100), ("Rare", 15), ("Uncommon", 4)],
        leg_pity=150, soft_from=100, soft_step=0.02,
        pool={"Common": 6, "Uncommon": 5, "Rare": 4, "Epic": 3, "Legendary": 2},  # per tab
        frag={"Common": 1, "Uncommon": 3, "Rare": 10, "Epic": 40, "Legendary": 200},
    ),
}
RANK = {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4, "Mythic": 5, "Secret": 6}

def roll(rng, m, s):
    s["n"] += 1
    luck = 2 if s["n"] % BONUS_EVERY == 0 else 1
    pick = "Common"
    for r, n in m["ladder"]:
        p = min(1.0, luck / n)
        if r == "Legendary" and m["soft_from"] and s["sl"] + 1 > m["soft_from"]:
            p += (s["sl"] + 1 - m["soft_from"]) * m["soft_step"]
        if rng.random() < p:
            pick = r
            break
    floor = "Legendary" if s["sl"] + 1 >= m["leg_pity"] else ("Epic" if s["se"] + 1 >= EPIC_PITY else None)
    if floor and RANK[pick] < RANK[floor]:
        pick = floor
    if RANK[pick] >= 4:
        s["se"] = 0; s["sl"] = 0
    elif RANK[pick] >= 3:
        s["se"] = 0; s["sl"] += 1
    else:
        s["se"] += 1; s["sl"] += 1
    return pick

def diff_at(t, profile):
    if profile != "ladder":
        return profile
    h = t / 60
    best = "normal"
    for d, (_, _, lvl) in DIFFS.items():
        if h >= LEVEL_HOURS[lvl]:
            best = d
    return best

def player(rng, m, profile):
    tokens = STARTER_TOKENS
    s = {"n": 0, "se": 0, "sl": 0}
    owned = set(); frag = 0; rolls = 0; first = {}; bag_block = None
    tabspend = {k: 0 for k in TABS}
    t = 0.0; lastday = -1; fc = False
    tabnames = list(TABS); weights = list(TABS.values())
    def do(n):
        nonlocal rolls, frag, bag_block
        tab = rng.choices(tabnames, weights)[0]
        tabspend[tab] += n
        for _ in range(n):
            r = roll(rng, m, s); rolls += 1
            first.setdefault(r, t)
            item = (tab, r, rng.randrange(m["pool"][r]))
            if item in owned:
                frag += m["frag"][r]          # PROPOSED: dupes auto-convert, never use a slot
            else:
                owned.add(item)
        if len(owned) > BAG_CAP - 10 and bag_block is None:
            bag_block = t
    do(FREE_ROLLS)
    while t < HOURS * 60:
        day = int(t // PLAY_MIN_PER_DAY)
        if day != lastday:
            tokens += DAILY; lastday = day; fc = True
        d = diff_at(t, profile); mult, mins, _ = DIFFS[d]
        waves = 5 if rng.random() > FAIL else rng.randint(0, 4)
        earned = half_up(sum(WAVE_TOK[:waves]) * mult)
        if waves == 5 and fc:
            earned += FIRST_CLEAR_DAY; fc = False
        tokens += earned
        t += mins if waves == 5 else mins * waves / 5 + 0.5
        while tokens >= X10_COST:
            tokens -= X10_COST; do(10)
    return rolls, first, frag, len(owned), bag_block, tabspend

def report(model, profile):
    rng = random.Random(SEED)
    m = MODELS[model]
    R, FR, BAG, BB = [], [], [], []
    F = {k: [] for k in m["pool"]}
    TS = {k: 0 for k in TABS}
    for _ in range(PLAYERS):
        r, f, fr, bag, bb, ts = player(rng, m, profile)
        R.append(r); FR.append(fr); BAG.append(bag); BB.append(bb)
        for k in F:
            F[k].append(f.get(k))
        for k in TS:
            TS[k] += ts[k]
    tot = sum(TS.values())
    print(f"== {model} / {profile}: {PLAYERS} players x {HOURS} h, seed {SEED}")
    print(f"rolls/10h median {st.median(R):.0f} (p10 {sorted(R)[100]}, p90 {sorted(R)[900]}); fragments/10h median {st.median(FR):.0f}")
    print(f"unique items in bag median {st.median(BAG):.0f} of {BAG_CAP}; players whose bag blocks x10: {sum(b is not None for b in BB)/10:.1f}%")
    print("tab share of rolls: " + ", ".join(f"{k} {TS[k]/tot*100:.0f}%" for k in TABS))
    for k in sorted(F, key=lambda x: RANK[x]):
        got = [x for x in F[k] if x is not None]
        if got:
            print(f"  {k}: {len(got)/PLAYERS*100:.1f}% reached, median first at {st.median(got):.0f} min, p90 {sorted(got)[int(len(got)*0.9)-1]:.0f} min")
        else:
            print(f"  {k}: 0% reached")

def per_minute():
    print("== tokens per minute (PROPOSED income / PROPOSED run length)")
    prev = 0
    for d, (mult, mins, lvl) in DIFFS.items():
        full = half_up(sum(WAVE_TOK) * mult)
        fail = half_up(sum(WAVE_TOK[:4]) * mult)
        tpm = full / mins
        assert tpm > prev, d
        prev = tpm
        print(f"{d:10s} gate L{lvl:<2d} x{mult:<4} {mins:>4} min  clear {full:>2}  fail-on-boss {fail:>2}  {tpm:.2f} tok/min  {full*10/9:.1f} rolls/run")

if __name__ == "__main__":
    per_minute()
    for model in ("proposed5", "current7"):
        for profile in ("normal", "ladder"):
            report(model, profile)
