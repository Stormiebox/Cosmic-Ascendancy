# ⚙️ 🌌 Cosmic Ascendancy - Detailed Features & Deep Dive

*Current Version: v1.0.0 (Unreleased)*

Welcome to the **Cosmic Ascendancy** official wiki! This page contains the full, exhaustive breakdown of the mod's mechanics, complete with hard statistics, generation rules, and crafting math.

---

## 📑 Table of Contents

- [🧬 Mod Identity & Narrative Concept](#-mod-identity--narrative-concept)
- [🛡️ The Eclipse Crisis (Deep Dive)](#️-the-eclipse-crisis-deep-dive)
  - [Eclipse Faction Stats & Traits](#eclipse-faction-stats--traits)
  - [Invasion Mechanics & Threat Escalation](#invasion-mechanics--threat-escalation)
  - [Eclipse Citadels](#eclipse-citadels)
- [🏛️ The Ascendancy Beacon](#️-the-ascendancy-beacon)
- [🌍 Dynamic Faction Expansion](#-dynamic-faction-expansion)
- [⚙️ The Ascendancy Forge (Crafting & Math)](#️-the-ascendancy-forge-crafting--math)
  - [Unlock Requirements](#unlock-requirements)
  - [Crafting Formula & Sacrifice Mechanics](#crafting-formula--sacrifice-mechanics)
  - [Ascendant Subsystem Stats](#ascendant-subsystem-stats)
- [🔗 Cosmic Series Integration](#-cosmic-series-integration)

---

## 🧬 Mod Identity & Narrative Concept
<details>
<summary><b>Click to expand</b></summary>

### 🧬 The Lore
Following the destruction of the Wormhole Guardian, a violent rupture tore across the subspace barrier. From this tear emerged an ancient, hyper-advanced adversary known only as **The Eclipse**. Driven by an unfathomable algorithmic directive to "sanitize" biological and chaotic synthetic life, The Eclipse immediately begins surging outward from the galactic core.

As the commander who broke the barrier, you receive a highly encrypted, ancient distress signal originating from the galactic rim. This signal will guide you to the **Ascendancy Forge**, the only facility capable of synthesizing weapons powerful enough to destroy the Eclipse.

### Design Philosophy
Cosmic Ascendancy is designed to solve Avorion's "late-game drought." Once you have Ogonite and Avorion ships, there is usually no further challenge. This mod provides an aggressively expanding, endgame-only crisis faction that forces you to optimize your fleets and defend your territory, backed by a fully narrative-driven, multi-stage questline.
</details>

---

## 🛡️ The Eclipse Crisis (Deep Dive)
<details>
<summary><b>Click to expand</b></summary>

The Eclipse is not a standard AI faction. It does not trade, it cannot be reasoned with, and its reputation is permanently locked to `-100,000`.

### 💥 Eclipse Faction Stats & Traits
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

### 📡 The Summoning Beacon
If you are prepared to face the ultimate threat on your own terms, you can forcefully summon the World-Eater!
- **Raid Summoning:** Jettisoning an **Eclipse Datacore** from your cargo hold into space acts as a quantum beacon. If there are no other Eclipse ships currently in the sector, the datacore will violently collapse, tearing open a hyperspace rift and instantly summoning the **Eclipse World-Eater**!

### Invasion Mechanics & Threat Escalation
The Eclipse dynamically targets sectors containing high player or AI faction value.
- **Scouting Phase:** Small, fast-moving Eclipse Interceptors will arrive in a sector. If they are not destroyed within 5 minutes, they broadcast a beacon.
- **Assault Phase:** Once the beacon is active, a massive invasion fleet will warp in.
  - *Fleet Composition:* 1 Dreadnought, 3 Cruisers, 5-8 Corvettes.
- **Eradication:** Eclipse fleets prioritize destroying Stations. If they destroy an AI faction station, the sector's local economic output drops permanently. If they destroy a Player station, the player obviously loses that asset.


### 🚨 The World-Eater Doomsday Event
A global crisis managed by the galaxy engine.
- **The Trigger:** Every 2-3 hours of active playtime, a random populated player sector is targeted (or triggered manually via Datacore Jettisoning). The World Eater timer **automatically pauses** if no players are online, protecting 24/7 dedicated servers from being wiped while the server is empty.
- **The Threat:** A World-Eater Juggernaut (5x scaled volume/125x Hull Mass, -90% Speed) spawns 15,000 km away. Unlike lesser Eclipse ships, the World-Eater relies purely on its colossal Hull and dynamic mechanics:
  - **Anchor Pylon Tethers:** Upon spawning, the World-Eater summons 4 Eclipse Juggernauts. Until all 4 are destroyed, the boss remains 100% invincible, visually tethered to them by massive purple lasers.
  - **Quantum EMP:** Periodically targets a random player with a massive cyan glow. After 3 seconds, an EMP erupts, instantly stripping 100% of their shields and inflicting catastrophic energy damage.
  - **Gravity Anomaly:** Periodically spawns a dark purple Black Hole at a player's location. This actively pulls all player ships towards the center using physical constraints, inflicting crushing hull damage over time!
  - **The 6-Phase Gauntlet:** As its massive hull is chipped away, it triggers global desperation mechanics:
    - **80% HP:** Spawns 5 Defiler Escorts.
    - **70% HP:** Emits a global EMP pulse, instantly stripping 50% of the shield capacity from all players in the sector.
    - **60% HP:** Deploys 4 Eclipse Assassin Hunter-Killers.
    - **50% HP:** Blinks randomly to a distant location and initiates emergency repairs, healing up to 10% of its Max Hull.
    - **35% HP:** Blinks again, unleashes a second global EMP, and enters an Enraged state (+50% Fire Rate, +50% Global Damage) until destroyed!
- **The Outcome:** If not destroyed within 15 minutes, the sector is completely wiped (all stations/AI ships deleted, player ships set to 1 HP) and ownership transfers to The Eclipse.

### 📈 Adaptive Eclipse Scaling
The Eclipse adapt to the server's power level. The galaxy engine scans for the player with the highest Global Ascendancy Tier. For **each tier** that player has achieved, the entire Eclipse faction globally receives a **+50% multiplier** to their physical ship volume, hull, and shields.

### 💥 Eclipse Citadels
When an invasion is overwhelmingly successful, the Eclipse will permanently occupy the sector and construct a **Citadel**.
- **The Lockdown Matrix:** Citadels generate a sector-wide interdiction field. Ships cannot jump *out* of a Citadel sector unless the Citadel is destroyed.
- **Siege Mechanics:** Citadels have `250,000,000` base HP (scaling with difficulty) and are surrounded by 4 orbital defense platforms.
- **Loot:** Destroying a Citadel guarantees a drop of 1-3 **Legendary** subsystems and massive quantities of Avorion ore, alongside unique crafting materials for the Ascendancy Forge.
- **Suppression Field:** Destroying a Citadel dynamically halts all Eclipse invasions within a 15-sector radius. The suppression lasts for a base of 6 real-time hours, plus an additional 2 hours for every 10 sectors the Eclipse currently own.
</details>

---


---

## ⚙️ The World Eater Event
<details>
<summary><b>Click to expand</b></summary>

Once the Eclipse are fully awakened, the galaxy is never truly safe. The Eclipse will periodically unleash their Doomsday Weapon: **The World Eater**.

- **Global Timer:** Every 2 to 3 real-time hours, the World Eater charges its primary weapon system. This timer **automatically pauses** if there are zero players online to protect empty dedicated servers.
- **Targeting:** It will lock onto a random known sector belonging to an active player.
- **The Countdown:** A 15-minute Doomsday countdown initiates. The server will broadcast a global GNN warning every 5 minutes, providing the exact coordinates of the impending strike.
- **Doomsday Execution:** If players fail to arrive in the sector and destroy the World Eater boss within the 15-minute window, the Doomsday weapon fires. The sector is completely erased, and the World Eater retreats.
- **Loot:** Successfully destroying the World Eater yields an enormous amount of **Ascendant Matter** (required for Forge Overdrive) and high-tier subsystems.
</details>

## 🏛️ The Ascendancy Beacon
<details>
<summary><b>Click to expand</b></summary>

Players can construct the ultimate megastructure: **The Ascendancy Beacon**.

### Purpose & Functionality
- **Permanent Sector Simulation:** A sector containing an active Ascendancy Beacon is simulated 24/7, even if no players are online.
- **Global Buffs:** The beacon applies a permanent, massive stat multiplier to all ships in the player's fleet across the entire galaxy.
- **Upgrades:** The beacon can be upgraded through 5 tiers, exponentially increasing the global stat buffs but requiring massive, continuous upkeep costs of Credits, Avorion, and Ogonite.
- **Passive Real-Estate Income:** Beacons automatically tax all passing AI-controlled freighters. This passive income is dynamically scaled by the War Heat of the passing faction (factions actively at war will pay a 50% premium for safe passage through your heavily defended capital!).
- **Treasury Payouts:** To prevent endless notification spam from freighters constantly passing through your capital, the Beacon safely stores all collected tolls in its internal treasury and pays out a single lump-sum to your faction every 45 minutes (synced with the Upkeep cycle).
- **Default Design:** Will follow Avorion standard mode of building a station. Allowing players to select `Ascendancy Beacon` as an option if they have it unlocked plus resources.

</details>

---

## ⚙️ The Ascendancy Forge (Crafting & Math)
<details>
<summary><b>Click to expand</b></summary>

To combat the Eclipse, players must locate and utilize the Ascendancy Forge to craft gear that pushes past Avorion's native limits.

### Unlock Requirements
- The Forge is discovered at the climax of the main storyline.
- It requires the player to manually insert a "Guardian Core" (dropped by the Wormhole Guardian) into the primary reactor to power it on.

### Crafting Formula & Global Ascendancy
Crafting Ascendant-tier gear and decrypting datacores is extraordinarily expensive to balance its extreme power.

- **Weapon Crafting Cost:** Scales based on distance to the core. Averages 1 Billion Credits and 100-500 **Ascendant Matter** (dropped by Eclipse Harvesters).
- **The Global Ascendancy Matrix:** Players can decrypt **Eclipse Datacores** (guaranteed drops from Eclipse Juggernauts).
  - *Benefits:* Each decryption permanently raises the player's Global Ascendancy Tier.
  - *Stats:* Each tier natively grants all player ships +15% Shield Capacity, +20% Shield Recharge, and +10% Faster Hyperspace Cooldown.
- **The Sacrifice System:** When initiating a craft, the Forge requires a Catalyst. You must sacrifice existing **Legendary** or **Exotic** subsystems.
  - *Math:* Sacrificing 1 Legendary grants a 20% success rate. Sacrificing 1 Exotic grants a 10% success rate. Sacrificing 5 Legendaries guarantees a 100% success rate.
  - *Failure:* If the craft fails, the sacrificed subsystems and raw materials are destroyed, but you are given "Ascendant Scrap" which is highly sought after and can be sold to underground tech brokers for massive profit.

### ⚙️ Ascendant Subsystem Stats
Ascendant subsystems are categorized as a new rarity tier (`Ascendant`) with custom purple/gold UI text. They are hardcoded to provide **50% greater baseline stats** than the maximum possible roll of a vanilla Legendary.

**Example: The Ascendant Shield Booster**
- *Vanilla Legendary Max:* +60% Shield Durability.
- *Ascendant Variant:* +90% Shield Durability, +15% Recharge Rate, and grants absolute immunity to EMP damage.

**Example: The Ascendant Core Processor**
- *Ascendant Variant:* +15 Arbitrary Turrets, +15 Armed Turrets, +50% Energy Generation.

### 🏭 Resource Procurement & Factory Overdrive
To fuel the Ascendancy Forge, you will need massive quantities of **Ascendant Matter**.
- **Eclipse Drops:** Ascendant Matter is a highly condensed energy resource found only within the dark reactors of Eclipse vessels. Destroying normal Eclipse ships has a chance to drop small quantities, while obliterating the World-Eater guarantees massive yields of Ascendant Matter.
- **Ascendant Overdrive:** As a late-game economic sink, players can approach any factory they own and interact with it to feed it 50 Ascendant Matter. This activates "Ascendant Overdrive", tripling (3.0x) the station's production capacity for 1 real-time hour!
</details>

---

## 🔗 Cosmic Series Integration
<details>
<summary><b>Click to expand</b></summary>

Cosmic Ascendancy leverages the APIs of the other Cosmic mods to create a deeply cohesive experience.

### 📰 Cosmic Chronicles (GNN)
When the Eclipse invades a sector, the Galactic News Network will immediately broadcast an emergency alert, warning the player of the exact coordinates.
When an Eclipse Citadel is established or destroyed, it heavily impacts the faction stock market indices for that region.

### ⚔️ Cosmic War
If the Eclipse invades a sector owned by a warring AI faction, those factions will temporarily suspend their War Heat generation and attempt to defend the sector together before resuming hostilities.

### 📖 Cosmic Codex (New in Audit 3.0!)
All deep lore regarding the Eclipse origins, detailed crafting recipes for the Ascendancy Forge, and real-time tracking of known Citadel locations are fully integrated into the in-game **Cosmic Codex**. The Codex updates dynamically as you progress through the main storyline!

### 🌌 Cosmic Vault
- **Dead Empire Filter:** The Eclipse Conquest Engine natively utilizes `FactionEradicationUtility` to strictly filter out destroyed empires, preventing crusades from glitching and targeting wiped out factions.
- **Post-Boss Anomalies:** Upon destroying the Eclipse World-Eater (Oblivion Engine), the game natively invokes `CosmicVaultAnomalies` to spawn a massive, persistent `PrecursorWreck` anomaly for exploration and salvaging.

### 🔒 Network Safety & Anti-Cheat (New in Audit 3.0!)
- **Math.Random Fix:** The Eclipse spawn engine natively utilizes Avorion's strict `random():getInt()` generation sequence to guarantee 100% synchronization on Multiplayer Dedicated Servers.
- **Callable Validation:** The Ascendancy Forge UI has been fully hardened. Malicious clients cannot spoof "free" crafting calls; the server actively verifies inventory requirements before processing the craft.
</details>


---

### Ascendancy Beacon & Codex
The Cosmic Codex has been radically expanded to properly categorize the Eclipse Crisis.
**The Ascendancy Beacon:**
A late-game construct that applies permanent, galaxy-wide stat multipliers to the player's fleet. Sector instances containing a beacon are simulated 24/7 without requiring the player to be online.

## The Nemesis System
If an Eclipse Dread-Lord drops below 5% HP, it will retreat. It remembers the damage type that hurt it the most (Plasma, Physical, etc.). Upon returning, it will have a massive 90% resistance to that specific damage type.

## Ascendant Gateways
Players can construct Ascendant Gateways to automate defense. If hostiles are detected, the gateway summons a powerful Ascendant fleet to protect the sector (2-hour cooldown).
