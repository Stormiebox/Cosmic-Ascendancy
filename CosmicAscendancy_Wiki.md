# Cosmic Ascendancy - Technical Wiki

This wiki details the exact formulas, math, and scaling used in the Cosmic Ascendancy mod.

## 1. Upkeep Formula

Upkeep occurs exactly every **45 Minutes**.
The cost scales quadratically based on the number of active beacons you own (up to 3):

* `Multiplier = (BeaconCount) ^ 2` (1x, 4x, or 9x scaling).
* **Base Credit Cost**: 10,000,000 * Multiplier
* **Base Ore Cost**: 500,000 * Multiplier
* **Ore Type**: Determined by distance to the Core:
  * Distance > 400: Iron
  * Distance > 300: Titanium
  * Distance > 200: Naonite
  * Distance > 100: Trinium
  * Distance > 50: Xanion
  * Distance < 50: Ogonite/Avorion

## 2. Upgrade Tier Costs

Upgrading a beacon requires flat costs:

* **Tier 2**: 50M Credits, 2M Iron
* **Tier 3**: 200M Credits, 5M Naonite
* **Tier 4**: 500M Credits, 10M Trinium
* **Tier 5**: 1B Credits, 20M Ogonite

## 3. Global Buff Multipliers

Your highest active Beacon Tier globally dictates your empire-wide buffs:

* **Tier 1**: +5% Damage, +10% Hull, +10% Shields
* **Tier 2**: +10% Damage, +25% Hull, +25% Shields
* **Tier 3**: +15% Damage, +50% Hull, +50% Shields
* **Tier 4**: +20% Damage, +75% Hull, +75% Shields
* **Tier 5**: +35% Damage, +125% Hull, +125% Shields

## 4. The Grand Toll

Whenever an AI ship enters the sector, they pay a toll:

* **Base Toll**: T1=10k, T2=50k, T3=100k, T4=250k, T5=500k.
* **Wartime Premium**: If the AI faction has War Heat > 0, the toll increases dynamically. `Toll = BaseToll * (1.0 + (Heat * 0.5))`. (Max +50% increase).

## 5. Capital Sieges

Sieges occur every `math.random(3, 6) * 3600` seconds of playtime.
**Attacker Generation:**

* 40% chance of spawning ships from the highest hostile War Faction (if you are at war).
* 30% chance of Xsotan.
* 30% chance of Pirates.

**Fleet Size:**

* `Standard Ships = 3 + (Tier * 2)`
* `Boss Ships (Dreadnoughts/Battleships) = math.max(0, Tier - 2)`

## 6. The Stellar Forge Formulas

**Cost Scaling:**

* `DistanceScale = math.max(1, 6 - (Distance / 100))`
* **Credit Cost** = 1,000,000,000 * DistanceScale
* **Ore Cost** = 10,000,000 * DistanceScale
* **Crafting Time** = Exactly 24 Playtime Hours (86,400 seconds).

**Weapon Output Stats:**
The generated weapon is always Max Tech (52) and Legendary (Rarity 5).

* Slot Cost = Forced to 1
* Max Range = Base * 2.0
* **Damage Multiplier**: `3.0 * DistanceBonus * WarHeatBonus`
  * `DistanceBonus = 1.0 + (math.max(0, 500 - Distance) / 250)` (Up to 3.0 at Core)
  * `WarHeatBonus = 1.0 + (Heat * 1.5)` (Up to 2.5 during max war)
  * *Total possible damage multiplier: 22.5x base damage.*

**Subsystem Output Stats (Living Relics):**
Subsystems forged here do not bake their stats permanently. Instead, they dynamically scan your ship's location and active war status to scale in real-time.
* **Relic Multiplier**: `DistanceBonus * WarHeatBonus` (Up to 7.5x base stats!)
  * `DistanceBonus = 1.0 + (math.max(0, 500 - Distance) / 250)` (Up to 3.0 at Core)
  * `WarHeatBonus = 1.0 + (Heat * 1.5)` (Up to 2.5 during max war)

**The 4 Relics**:
1. **War-Drive**: +10 Armed Turrets, +5 Arbitrary Turrets, +200% Energy, +50% Fire Rate (*Scales up to +75 Armed Turrets!*)
2. **Aegis Matrix**: +500% Shield Durability, +300% Shield Recharge (*Scales up to +3750% Shields!*)
3. **Slipstream Core**: +500% Velocity, +25 Jump Reach, -80% Hyperspace Cooldown
4. **Omni-Sensor**: +20 Radar, +15 Hidden Sectors, +1000% Cargo, +500% Loot Range


## The Eclipse (Endgame Expansion)
The core objective of *Cosmic Ascendancy* is to provide a true endgame that begins the moment the Xsotan Wormhole Guardian dies. The galaxy is no longer a static sandbox.

### The Awakening
Upon the destruction of the Guardian, a massive shockwave ripples through subspace. Players are given exactly 10 minutes of ominous warnings to prepare before the galaxy is permanently invaded.

### The Faction
**The Eclipse** is an ancient, merciless faction that utilizes pitch-black Avorion and glowing red geometric shapes. They do not negotiate.
*   **Nullifiers (Pyramids):** Scout/Fighter craft.
*   **Obliterators (Monoliths):** Massive Cruiser-class warships.
*   **Harbingers (Obelisks):** God-tier bosses possessing the same "Living Relic" modifiers as players (+3750% Shields, +500% Damage).

### Relentless Mechanics
The Eclipse does not stay in one place. They actively hunt players globally, periodically spawning massive invasion fleets directly into player-occupied sectors. Furthermore, any newly generated sector has a chance to be pre-conquered, housing an Eclipse Citadel.
Their weapons are forcibly overridden to Tech 52 (Max), with completely maxed stats. If *Cosmic Starfall* is installed, they will indiscriminately use those apocalyptic weapons against you.
