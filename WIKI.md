# 🚀 Cosmic Ascendancy - The Official Wiki & Deep Dive

*Current Version: v1.0.0 (Unreleased)*

Welcome to the **Cosmic Ascendancy** official wiki! This document contains the full, exhaustive breakdown of the mod's mechanics, complete with hard statistics, generation rules, and crafting math.

---

## 📑 Table of Contents

- [🧬 Mod Identity & Narrative Concept](#-mod-identity--narrative-concept)
- [🌑 The Eclipse Crisis (Deep Dive)](#-the-eclipse-crisis-deep-dive)
- [🚨 The World-Eater Doomsday Event](#-the-world-eater-doomsday-event)
- [🏰 Eclipse Citadels](#-eclipse-citadels)
- [🗼 The Ascendancy Beacon](#-the-ascendancy-beacon)
- [🗺️ Dynamic Faction Expansion](#️-dynamic-faction-expansion)
- [🛠️ The Ascendancy Forge (Crafting & Math)](#️-the-ascendancy-forge-crafting--math)
- [🤝 Synergies & Integrations](#-synergies--integrations)

---

## 🧬 Mod Identity & Narrative Concept
<details>
<summary><b>Click to expand</b></summary>

### 📜 The Lore
Following the destruction of the Wormhole Guardian, a violent rupture tore across the subspace barrier. From this tear emerged an ancient, hyper-advanced adversary known only as **The Eclipse**. Driven by an unfathomable algorithmic directive to "sanitize" biological and chaotic synthetic life, The Eclipse immediately begins surging outward from the galactic core.

As the commander who broke the barrier, you receive a highly encrypted, ancient distress signal originating from the galactic rim. This signal will guide you to the **Ascendancy Forge**, the only facility capable of synthesizing weapons powerful enough to destroy the Eclipse.

### 📝 Design Philosophy
Cosmic Ascendancy is designed to solve Avorion's "late-game drought." Once you have Ogonite and Avorion ships, there is usually no further challenge. This mod provides an aggressively expanding, endgame-only crisis faction that forces you to optimize your fleets and defend your territory, backed by a fully narrative-driven, multi-stage questline.
</details>

---

## 🌑 The Eclipse Crisis (Deep Dive)
<details>
<summary><b>Click to expand</b></summary>

The Eclipse is not a standard AI faction. It does not trade, it cannot be reasoned with, and its reputation is permanently locked to `-100,000` (Hostile).

### 💥 Faction Stats & Traits
Eclipse vessels are exceptionally deadly due to their specialized "Void Shields" and highly coordinated AI logic:
- **Void Shields:** Incoming physical damage (Cannons, Bolters, Chainguns) is mitigated by **90%**. You *must* use high-tier Energy/Antimatter/Plasma weapons to strip their shields.
- **Armor Plating:** Base Hull HP is multiplied by `2.5x` relative to vanilla generated ships of the same volume.
- **Weaponry:** The Eclipse exclusively utilize massive EMP lasers and high-velocity Plasma Artillery, making them incredibly lethal against your own shields.
- **Aesthetics & Classes:** Eclipse ships are towering, jet-black monolithic structures accented by crimson energy fields. They fly Nullifiers (Pyramids), Obliterators (Monoliths), Harbingers (Obelisks), and 4 specialized combat classes: the Juggernaut (Dreadnought), Interceptor (Fighter), Harvester (Miner), and Defiler (Assault Frigate).

### 🌌 Ancient Eclipse Abilities
To make the faction feel uniquely terrifying, the Eclipse possess 5 devastating ancient mechanics distributed across their classes:
- **Dark Matter Blink (All Ships):** Upon taking 15% burst damage within 1 second, the ship will violently blink 5-10km away to escape, leaving behind a Void Rift (cooldown: 30s).
- **Ethereal Phase-Shift (Interceptors & Phantoms):** Slippery vanguards will instantly phase out of reality for 4 seconds upon shield break, becoming an invincible void-shadow to reposition.
- **Adaptive Resistance (Defilers & Artillery):** These heavy combatants analyze incoming fire; taking 5% Hull damage from a specific element (e.g., Plasma) triggers a 75% resistance to that element for 15 seconds!
- **Void Siphon Aura (Carriers, Cruisers, Dreadnoughts, Juggernauts):** Massive command ships constantly project a 3km devouring aura, draining 2% of the shield capacity of all nearby player ships per second to heal themselves.
- **Singularity Implosion (All Large Capital Ships):** Upon death, these gargantuan reactors collapse. After a 3-second warning, they violently detonate, dealing 50,000 true-damage to everything within 3km!

### ⚔️ Invasion Mechanics & Threat Escalation
The Eclipse dynamically targets sectors containing high player or AI faction value.
1.  **Scouting Phase:** Small, fast-moving Eclipse Interceptors arrive in a sector. If they are not destroyed within 5 minutes, they broadcast a beacon.
2.  **Assault Phase:** Once the beacon is active, a massive invasion fleet warps in (typically 1 Dreadnought, 3 Cruisers, and 5-8 Corvettes).
3.  **Eradication:** Eclipse fleets prioritize destroying Stations. Destroyed AI stations permanently drop local economic output, and destroyed Player stations are permanently lost!

### 📈 Adaptive Eclipse Scaling
The Eclipse adapt to the server's power level. The galaxy engine scans for the player with the highest Global Ascendancy Tier. For **each tier** that player has achieved, the entire Eclipse faction globally receives a **+50% multiplier** to their physical ship volume, hull, and shields.

### 🗡️ The Nemesis System
If an Eclipse Dread-Lord drops below 5% HP, it will retreat. It remembers the damage type that hurt it the most (Plasma, Physical, etc.). Upon returning, it will have a massive 90% resistance to that specific damage type.
</details>

---

## 🚨 The World-Eater Doomsday Event
<details>
<summary><b>Click to expand</b></summary>

A global crisis managed by the galaxy engine.

- **The Trigger:** Every 2-3 hours of active playtime, a random populated player sector is targeted. The timer **automatically pauses** if no players are online, protecting 24/7 dedicated servers from being wiped while the server is empty.
- **The Threat:** A World-Eater Juggernaut (5.9 kilometers long, `125x` Hull Mass, `-90%` Speed) spawns 15,000 km away. Unlike lesser Eclipse ships, the World-Eater relies purely on its colossal Hull and dynamic mechanics:
  - **⛓️ Anchor Pylon Tethers:** Upon spawning, the World-Eater summons 4 Eclipse Juggernauts. Until all 4 are destroyed, the boss remains **100% invincible**, visually tethered to them by massive purple lasers.
  - **Nemesis Protocol:** The boss dynamically scans incoming DPS. If it takes overwhelming burst damage, the Nemesis Protocol engages, reducing all incoming damage by 90% dynamically to prevent players from instantly deleting it.
  - **World-Breaker Laser:** The boss is armed with a colossal coaxial laser capable of obliterating anything caught in its 15km path.
  - **⚡ Quantum EMP:** Periodically targets a random player with a massive cyan glow. After 3 seconds, an EMP erupts, instantly stripping 100% of their shields and inflicting catastrophic energy damage.
  - **⚫ Gravity Anomaly:** Periodically spawns a dark purple Black Hole at a player's location. This actively pulls all player ships towards the center using physical constraints, crippling velocity and trapping you in the blast zone!
  - **💥 The 6-Phase Gauntlet:** As its massive hull is chipped away, it triggers global desperation mechanics:
    - **80% HP:** Spawns 5 Defiler Escorts.
    - **70% HP:** Emits a global EMP pulse, instantly stripping 50% of the shield capacity from all players in the sector.
    - **60% HP:** Deploys 4 Eclipse Assassin Hunter-Killers.
    - **50% HP:** Blinks randomly to a distant location and initiates emergency repairs, healing up to 10% of its Max Hull.
    - **35% HP:** Blinks again, unleashes a second global EMP, and enters an **Enraged state** (+50% Fire Rate, +50% Global Damage) and projects a 15km sector-wide Dark Matter Aura that continuously drains Hull integrity from all hostile ships caught within it!
- **The Outcome:** If not destroyed within 15 minutes, the sector is completely wiped (all stations/AI ships deleted, player ships set to 1 HP) and ownership transfers to The Eclipse.
- **💰 Loot:** Successfully destroying the World-Eater yields an enormous amount of **Ascendant Matter** and high-tier subsystems.

### 📡 The Summoning Beacon
If you are prepared to face the ultimate threat on your own terms, you can forcefully summon the World-Eater!
- **Raid Summoning:** Jettisoning an **Eclipse Datacore** from your cargo hold into space acts as a quantum beacon. If there are no other Eclipse ships currently in the sector, the datacore will violently collapse, tearing open a hyperspace rift and instantly summoning the **Eclipse World-Eater**!
</details>

---

## 🏰 Eclipse Citadels
<details>
<summary><b>Click to expand</b></summary>

When an invasion is overwhelmingly successful, the Eclipse will permanently occupy the sector and construct a **Citadel**.


### ⚔️ Eclipse Combat Classes & Abilities
- **Void Siphons:** Emitters projecting a massive **15km** radius field. If your shields drop to 0 within this field, the Siphon will aggressively drain your Hull (0.5% max hull per tick) to repair itself.
- **Singularity Collapse (Dreadnoughts/Carriers):** When their core detonates upon death, it triggers a massive **15km** implosion dealing 250,000 true damage. During its 3-second windup, the core creates a **Gravity Well** that physically sucks all nearby ships toward the epicenter.
- **Ethereal Phase Shifts (Phantoms/Interceptors):** Upon losing shields, they enter a 4-second invincible Phase Shift and actively **regenerate 25% of their Max Shields** while phased.
- **Adaptive Memory (Defilers):** Their adaptive armor grants compounding resistance to elemental damage types, but the memory **safely decays** if they aren't hit by that element for 3 seconds.

### ⚙️ Mechanics
- 🚫 **The Lockdown Matrix:** Citadels generate a sector-wide interdiction field. Ships cannot jump *out* of a Citadel sector unless the Citadel is destroyed.
- 💣 **Siege Scale:** Citadels have `250,000,000` base HP (scaling with difficulty) and are surrounded by 4 orbital defense platforms.
- 💰 **Loot & Rewards:** Destroying a Citadel guarantees a drop of 1-3 **Legendary** subsystems, massive quantities of Avorion ore, and unique crafting materials for the Ascendancy Forge.
- ⏳ **Suppression Field:** Destroying a Citadel dynamically halts all Eclipse invasions within a 15-sector radius. The suppression lasts for a base of 6 real-time hours, plus an additional 2 hours for every 10 sectors the Eclipse currently own.
</details>

---


## The World Eater (Endgame Raid Boss)
<details>
<summary><b>Click to expand</b></summary>

At the absolute climax of the Eclipse threat, you will face the **World Eater**—a colossal, 6-kilometer long Pyramid dreadnought built entirely of Avorion.

### Mechanics
- **Invulnerability Tethers:** Upon reaching **50%** and **25%** Hull, the World Eater becomes completely invulnerable and spawns heavily shielded Tethers in orbit. These Tethers rapidly regenerate the boss's shields. You must destroy all Tethers to drop the invulnerability phase.
- **Nemesis Protocol:** The World Eater dynamically analyzes incoming damage. Whichever damage type (Physical, Plasma, Antimatter, Electric) you rely on the most will trigger the Nemesis Protocol, granting the boss **90% absolute immunity** to that specific element. You must diversify your fleet's weaponry.
- **World-Breaker Laser:** The boss is equipped with a devastating axial laser specifically designed to siege. It deals astronomical damage and will instantly vaporize any space station it targets.
- **Dark Matter Aura (Enrage):** Upon dropping to **35% Hull**, the World Eater enters its Enrage phase, projecting a 15km sector-wide Dark Matter Aura that continuously drains Hull integrity from all hostile ships caught within it.
</details>

---

## 🗼 The Ascendancy Beacon
<details>
<summary><b>Click to expand</b></summary>

Players can construct the ultimate megastructure to anchor their empire: the **Ascendancy Beacon**.

### ⚙️ Mechanics
- 🌍 **Permanent Sector Simulation:** A sector containing an active Ascendancy Beacon is simulated 24/7, even if no players are online.
- ✨ **Global Buffs:** The beacon applies a permanent, massive stat multiplier to all ships in the player's fleet across the entire galaxy.
- 🔺 **Upgrades & Upkeep:** The beacon can be upgraded through 5 tiers, exponentially increasing the global stat buffs. However, higher tiers require massive, continuous upkeep costs of Credits, Avorion, and Ogonite.
- 💸 **Passive Real-Estate Income:** Beacons automatically tax all passing AI-controlled freighters. This passive income is dynamically scaled by the **War Heat** of the passing faction (factions actively at war will pay a `+50%` premium for safe passage through your heavily defended capital!).
- 🏦 **Treasury Payouts:** To prevent endless notification spam, the Beacon safely stores all collected tolls in its internal treasury and pays out a single lump-sum to your faction every 45 minutes (synced with the Upkeep cycle).
- 🏗️ **Construction:** Follows Avorion's standard station building mode. Players can select `Ascendancy Beacon` as an option if they have it unlocked and possess the required resources.
</details>

---

## 🗺️ Dynamic Faction Expansion
<details>
<summary><b>Click to expand</b></summary>

Vanilla Avorion features a static map. With Cosmic Ascendancy, **civilized AI factions** and **Pirates** will slowly and naturally expand their borders over time.
- 🗺️ **Organic Growth:** Civilized factions will trace outward from their home sectors to claim contiguous empty sectors, spawning new space stations and officially annexing the territory.
- 🏴‍☠️ **Pirate Bases:** Deep space is no longer permanently safe. Pirates will occasionally establish Smuggler's Hideouts and Pirate Shipyards in completely uncharted systems.
- 📰 **News Alerts:** All major territorial expansions are broadcast live via the Cosmic Chronicles News Network.
</details>

---

## 🛠️ The Ascendancy Forge (Crafting & Math)
<details>
<summary><b>Click to expand</b></summary>

To combat the Eclipse, players must locate and utilize the Ascendancy Forge to craft gear that pushes past Avorion's native limits.

### 🔓 Unlock Requirements
- The Forge is discovered at the climax of the main storyline.
- It requires the player to manually insert a **"Guardian Core"** (dropped by the Wormhole Guardian) into the primary reactor to power it on.

### 📈 Crafting Formula & Global Ascendancy
Crafting Ascendant-tier gear and decrypting datacores is extraordinarily expensive to balance its extreme power.

- **💰 Base Crafting Cost:** Scales up to `300,000,000` Credits, `3,000,000` Avorion, and 25-50 **Ascendant Matter**.
- 📈 **Global Ascendancy Matrix:** You can submit **Eclipse Datacores** (dropped by Eclipse Juggernauts) to the Forge. Decrypting a datacore permanently raises your Global Ascendancy Tier, granting a stacking `+15%` Shields, `+20%` Shield Recharge, and `+10%` Hyperspace Cooldown to all ships in your fleet!
- 🙏 **The Sacrifice System:** When initiating a craft, you must sacrifice existing **Legendary** or **Exotic** subsystems as Catalysts.
    - `1x Legendary` = **20%** success rate.
    - `1x Exotic` = **10%** success rate.
    - **Ascendant Scrap:** If you cannot reach 100% success rate, the Forge will automatically consume Ascendant Scrap from your ship's cargo hold to bridge the gap. Each Ascendant Scrap adds **+2%** to the success rate.
  - 💥 **War Heat Bonuses:** If *Cosmic War* is installed, your faction's War Heat is added as a massive multiplier to the weapon's damage (up to a **10.0x cap**) upon claiming it!
    - ⚔️ **New Subsystems:** The Forge can synthesize the **Ascendant Swarm Nexus** (massively boosts Production Capacity and Fighter Squadrons) and the **Ascendant Void-Drill** (boosts Transporter Range, Loot Range, and Generator Energy)!
    - 🦾 **Ascendant Neural Implants:** You can now craft and equip the legendary Ascendant Neural Implant subsystem, which transforms your ship into a biomechanical dreadnought (scaling massive stats like jump reach, fighters, and turrets while injecting extreme velocity).
    - 🧨 **Titan Coaxial Superweapons:** Players can forge the **Ascendant World-Breaker**, a massively devastating coaxial laser superweapon capable of 250,000 continuous damage.
  - 💔 **Failure:** If the craft fails, the sacrificed subsystems and raw materials are destroyed, but you receive **"Ascendant Scrap"** which is highly sought after and can be sold to underground tech brokers for massive profit.

### ✨ Ascendant Subsystem Stats
Ascendant subsystems are categorized as a new rarity tier (`Ascendant`) with custom purple/gold UI text. They are hardcoded to provide **50% greater baseline stats** than the maximum possible roll of a vanilla Legendary.

#### Example: The Ascendant Shield Booster
- *Vanilla Legendary Max:* `+60%` Shield Durability.
- *Ascendant Variant:* `+90%` Shield Durability, `+15%` Recharge Rate, and grants absolute immunity to EMP damage.

#### Example: The Ascendant Core Processor
- *Ascendant Variant:* `+15` Arbitrary Turrets, `+15` Armed Turrets, `+50%` Energy Generation.

### 🏭 Resource Procurement & Factory Overdrive
To fuel the Ascendancy Forge, you will need massive quantities of **Ascendant Matter**.
- **Loot Source:** Ascendant Matter is a highly condensed energy resource found only within the dark reactors of Eclipse vessels. Destroying normal Eclipse ships has a chance to drop small quantities, while obliterating the World-Eater guarantees massive yields.
  - **Factory Overdrive:** As a late-game economic sink, players can approach any factory they own and interact with it to feed it **50 Ascendant Matter**. This activates "Ascendant Overdrive", **tripling (3.0x)** the station's production capacity for 1 real-time hour!
</details>

---

## 🌌 The Dark Sector
<details>
<summary><b>Click to expand</b></summary>
Uncharted sectors inside the Galactic Core (distance to center < 150) now have a 20% chance to instantly spawn as horrifying, Dark Matter Fog-choked "Dark Sectors". These sectors are permanently suffocated in an atmospheric hazard and heavily guarded by Eclipse Citadels surrounded by massive Dreadnought fleets. Dive in if you dare!
</details>

---

## 🤝 Synergies & Integrations
<details>
<summary><b>Click to expand</b></summary>

Cosmic Ascendancy leverages the APIs of the other Cosmic mods to create a deeply cohesive, cross-mod experience.

### Cosmic Series Integration
- 📦 **Eclipse Contraband (Overhaul):** Eclipse Tech is highly valued by smugglers, offering a **3x payout** at Smuggler's Markets.
- 💀 **Corrupted Nodes (Chronicles):** Eclipse territories corrupt data caches, doubling their loot but spawning terrifying ambushes.
- ⚔️ **Relentless Expansion (War):** Eclipse AI is now inherently Imperialist and Vengeful. They will expand rapidly and refuse all ceasefires.
- 🌪️ **Hazard Immunity (Vault):** Eclipse Dreadnoughts are immune to Cosmic Vault weather hazards like Solar Flares and Ion Storms.
- 🗺️ **Dead Empire Filter (Vault):** The Eclipse Conquest Engine strictly filters out destroyed empires, preventing crusades from glitching.
- ✨ **Post-Boss Anomalies (Vault):** Upon destroying the Eclipse World-Eater, the game natively spawns a massive, persistent **Precursor Wreck** anomaly for exploration and salvaging.

### Rift DLC Interoperability
- **Rift Spillage:** Eclipse Invasions now have a **10% chance** to destabilize local space, tearing a massive subspace rift that drains sector shields. You must destroy the **Eclipse Rift Stabilizer** to close the tear and end the hazard.
</details>


### Dark Sectors
* Deep within the Galactic Core (distance < 150), un-generated sectors have a 20% chance of spawning as **Dark Sectors**.
* These sectors are encased in environmental **Dark Matter Fog** and feature Eclipse Citadels guarded by Juggernauts.

### Ascendant Neural Implants & Titan Weaponry
* **Ascendant Neural Implant:** A ship subsystem crafted at the Forge that massively scales ship stats (Jump Reach, Fighter Squadrons, Armed Turrets, Velocity). Simulates a heavily augmented captain.
* **Ascendant World-Breaker:** A Titan-Class Coaxial weapon dealing 250,000 base DPS, crafted at the Forge.
