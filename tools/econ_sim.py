#!/usr/bin/env python3
"""Shardfall economy sim (docs/research/economy_v1.md). Rev 4.

Deterministic: seed 42.
  python3 tools/econ_sim.py            V1 default: rev 2 five-tier ladder (+ current 7-tier comparison)
  python3 tools/econ_sim.py --ladder8  Parking lot (Phase 5): 8 tiers, variants, mutations, chase, per-tier pity
CURRENT values cite their repo file in the sheet; anything marked PROPOSED
is a sheet proposal, not live config.
"""
import random, statistics as st, sys

SEED = 42
PLAYERS = 1000
HOURS = 10

# ---- Income (PROPOSED unless noted) ----
WAVE_TOK = [1, 1, 2, 2, 5]                      # PROPOSED, Normal clear = 11
DIFFS = {  # mult, run minutes, level gate      # PROPOSED (gates N/H/NM current, Rootvault.luau)
    "normal":    (1.00, 5.0, 1),
    "medium":    (1.25, 5.5, 5),
    "hard":      (1.50, 6.0, 10),
    "nightmare": (2.00, 7.0, 15),
    "insane":    (3.00, 9.0, 20),
}
LEVEL_HOURS = {1: 0.0, 5: 0.37, 10: 2.58, 15: 7.77, 20: 16.79}  # docs/design/pacing.md
FAIL = 0.10
FIRST_CLEAR_DAY = 5
DAILY = 2 + 3 * 3 + 5 + 7
PLAY_MIN_PER_DAY = 120
STARTER_TOKENS = 10                              # CURRENT Schema.STARTER_TOKENS
FREE_ROLLS = 3                                   # PROPOSED
X10_COST = 9                                     # CURRENT RollConfig.cost(10)
BONUS_EVERY = 10                                 # CURRENT RollConfig.BONUS_EVERY
BAG_CAP = 100                                    # CURRENT Schema.INVENTORY_CAP
TABS = {"Weapons": 0.40, "Armor": 0.25, "Pets": 0.20, "Skills": 0.15}  # PROPOSED

ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]
RANK = {r: i for i, r in enumerate(ORDER)}

def half_up(x):
    return int(x + 0.5)

# ---- Rarity models ----
# pity: tier -> (hard cap, soft_from, soft_step absolute chance per roll past soft_from)
MODELS = {
    "current7": dict(  # CURRENT RarityConfig ONE_IN; pity Epic 50, Legendary 1000, no soft pity
        one_in={"Uncommon": 5, "Rare": 25, "Epic": 250, "Legendary": 2500, "Mythic": 25000, "Secret": 100000},
        pity={"Epic": (50, None, 0), "Legendary": (1000, None, 0)},
        pool={"Common": 12, "Uncommon": 10, "Rare": 8, "Epic": 6, "Legendary": 4, "Mythic": 2, "Secret": 1},
        extras=False,
    ),
    "proposed5": dict(  # PROPOSED V1 (rev 2): 5 tiers, Legendary hard pity 150, soft from 100 (+2%/roll)
        one_in={"Uncommon": 4, "Rare": 15, "Epic": 100, "Legendary": 1000},
        pity={"Epic": (50, None, 0), "Legendary": (150, 100, 0.02)},
        pool={"Common": 6, "Uncommon": 5, "Rare": 4, "Epic": 3, "Legendary": 2},
        extras=False,
    ),
    "proposed8": dict(  # PARKING LOT (Phase 5)  # PROPOSED rev 3: 8 tiers, per-tier pity with soft pity, variants, mutations, chase
        one_in={"Uncommon": 4, "Rare": 15, "Epic": 100, "Legendary": 1000, "Mythic": 20000,
                "Secret": 100000, "Divine": 500000},
        pity={"Epic": (50, 40, 0.03), "Legendary": (150, 100, 0.02), "Mythic": (3000, 2500, 0.002),
              "Secret": (15000, 12000, 0.0004), "Divine": (60000, 50000, 0.0001)},
        pool={"Common": 6, "Uncommon": 5, "Rare": 4, "Epic": 3, "Legendary": 2, "Mythic": 2, "Secret": 1, "Divine": 1},
        extras=True,
    ),
}
# Variants: independent roll, rarest first, at most one. (one_in, stat bonus, fragment mult)  PROPOSED
VARIANTS = [("Rainbow", 5000, 0.15, 10), ("Golden", 500, 0.10, 5), ("Shiny", 50, 0.05, 2)]
# Mutations: independent roll, at most one. PROPOSED
MUT_ELEMENT = 20      # 1-in-20: Ember / Frost / Void, +3% to that element's stat
MUT_TRAIT = 100       # 1-in-100: minor trait (+2-4%), checked first
SHARDHEART = 1_000_000  # flat 1-in-a-million special item
FRAG = {"Common": 1, "Uncommon": 3, "Rare": 10, "Epic": 40, "Legendary": 200, "Mythic": 1000,
        "Secret": 3000, "Divine": 10000}
MUT_FRAG_MULT = 1.5

def base_roll(rng, m, s):
    s["n"] += 1
    luck = 2 if s["n"] % BONUS_EVERY == 0 else 1
    pick = "Common"
    for r in reversed(ORDER):
        if r not in m["one_in"]:
            continue
        p = min(1.0, luck / m["one_in"][r])
        if r in m["pity"]:
            cap, soft, step = m["pity"][r]
            c = s[r] + 1
            if soft and c > soft:
                p += (c - soft) * step
        if rng.random() < p:
            pick = r
            break
    # hard floors: highest due tier wins
    for r in reversed(ORDER):
        if r in m["pity"] and s[r] + 1 >= m["pity"][r][0]:
            if RANK[pick] < RANK[r]:
                pick = r
            break
    # reset counters at or below the granted tier; others advance
    for r in m["pity"]:
        s[r] = 0 if RANK[pick] >= RANK[r] else s[r] + 1
    return pick

def extra_rolls(rng):
    variant = None
    for name, n, _, _ in VARIANTS:
        if rng.random() < 1 / n:
            variant = name
            break
    mutation = None
    if rng.random() < 1 / MUT_TRAIT:
        mutation = "trait"
    elif rng.random() < 1 / MUT_ELEMENT:
        mutation = rng.choice(["Ember", "Frost", "Void"])
    return variant, mutation

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
    s = {"n": 0}
    for r in m["pity"]:
        s[r] = 0
    owned = set(); frag = 0; first = {}; bag_block = None; chase = False
    tabnames = list(TABS); weights = list(TABS.values())
    t = 0.0; lastday = -1; fc = False
    def do(n):
        nonlocal frag, bag_block, chase
        tab = rng.choices(tabnames, weights)[0]
        for _ in range(n):
            r = base_roll(rng, m, s)
            first.setdefault(r, t)
            variant = mutation = None
            if m["extras"]:
                variant, mutation = extra_rolls(rng)
                if variant:
                    first.setdefault(variant, t)
                if mutation:
                    first.setdefault("Mutation", t)
                is_chase = (r == "Divine" or (variant == "Rainbow" and RANK[r] >= RANK["Mythic"])
                            or rng.random() < 1 / SHARDHEART)
                if is_chase:
                    chase = True
                    first.setdefault("Chase", t)
            key = (tab, r, rng.randrange(m["pool"][r]), variant)   # mutation does not take a slot
            if key in owned:
                mult = next((v[3] for v in VARIANTS if v[0] == variant), 1)
                frag += FRAG[r] * mult * (MUT_FRAG_MULT if mutation else 1)
            else:
                owned.add(key)
        # PROPOSED slot rule: one bag slot per base item; variants live in the collection log
        if len({k[:3] for k in owned}) > BAG_CAP - 10 and bag_block is None:
            bag_block = t
    do(FREE_ROLLS)
    while t < HOURS * 60:
        day = int(t // PLAY_MIN_PER_DAY)
        if day != lastday:
            tokens += DAILY; lastday = day; fc = True
        mult, mins, _ = DIFFS[diff_at(t, profile)]
        waves = 5 if rng.random() > FAIL else rng.randint(0, 4)
        earned = half_up(sum(WAVE_TOK[:waves]) * mult)
        if waves == 5 and fc:
            earned += FIRST_CLEAR_DAY; fc = False
        tokens += earned
        t += mins if waves == 5 else mins * waves / 5 + 0.5
        while tokens >= X10_COST:
            tokens -= X10_COST; do(10)
    return s["n"], first, frag, owned, bag_block, chase

def report(model, profile):
    rng = random.Random(SEED)
    m = MODELS[model]
    keys = [r for r in ORDER if r in m["pool"]]
    if m["extras"]:
        keys += ["Shiny", "Golden", "Rainbow", "Mutation", "Chase"]
    R, FR, BAG, BB, CH = [], [], [], [], 0
    base_slots = []
    F = {k: [] for k in keys}
    for _ in range(PLAYERS):
        n, f, fr, owned, bb, chase = player(rng, m, profile)
        R.append(n); FR.append(fr); BAG.append(len(owned)); BB.append(bb); CH += chase
        base_slots.append(len({(a, b, c) for a, b, c, _ in owned}))
        for k in keys:
            F[k].append(f.get(k))
    print(f"== {model} / {profile}: {PLAYERS} players x {HOURS} h, seed {SEED}")
    print(f"rolls/10h median {st.median(R):.0f}; fragments/10h median {st.median(FR):.0f}")
    print(f"bag slots used (1 per base item) median {st.median(base_slots):.0f} of {BAG_CAP}; "
          f"collection entries (item+variant) median {st.median(BAG):.0f}; players whose bag blocks x10: {sum(b is not None for b in BB)/PLAYERS*100:.1f}%")
    if m["extras"]:
        print(f"players with a chase pull in {HOURS} h: {CH/PLAYERS*100:.1f}%")
    for k in keys:
        got = sorted(x for x in F[k] if x is not None)
        if got:
            print(f"  {k}: {len(got)/PLAYERS*100:.1f}% reached, median first at {st.median(got):.0f} min")
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
    models = ("proposed8",) if "--ladder8" in sys.argv else ("proposed5", "current7")
    for model in models:
        for profile in ("normal", "ladder"):
            report(model, profile)
