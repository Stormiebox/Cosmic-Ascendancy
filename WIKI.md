# 🚀 Cosmic Ascendancy - The Official Wiki & Deep Dive

*Current Version: v1.8.0*

Welcome to the **Cosmic Ascendancy** official wiki. This document is the full, exhaustive breakdown of the mod's mechanics: hard statistics, generation rules, and crafting math.

---

## 📑 Table of Contents

- [🧬 Mod Identity & Narrative Concept](#-mod-identity--narrative-concept)
- [📖 The Ascendant Campaign](#-the-ascendant-campaign)
- [🌑 The Eclipse Crisis (Deep Dive)](#-the-eclipse-crisis-deep-dive)
- [🎵 The Choir & Endgame Additions](#-the-choir--endgame-additions)
- [🚨 The World-Eater Doomsday Event](#-the-world-eater-doomsday-event)
- [🏰 Eclipse Citadels](#-eclipse-citadels)
- [🗼 The Ascendancy Beacon](#-the-ascendancy-beacon)
- [🗺️ Dynamic Faction Expansion](#-dynamic-faction-expansion)
- [🌌 The Dark Sector](#-the-dark-sector)
- [🛠️ The Ascendancy Forge (Crafting & Math)](#-the-ascendancy-forge-crafting--math)
- [🤝 Synergies & Integrations](#-synergies--integrations)
- [💻 Player Commands](#-player-commands)

---

## 🧬 Mod Identity & Narrative Concept
<details>
<summary><b>Click to expand</b></summary>

### 📜 The Lore
Following the destruction of the Wormhole Guardian, a violent rupture tears across the subspace barrier. From it emerges an ancient, hyper-advanced adversary known only as **The Eclipse**. Driven by an algorithmic directive to sanitize biological and chaotic synthetic life, The Eclipse surges outward from the galactic core.

As the commander who broke the barrier, you receive a highly encrypted distress signal from the galactic rim. It leads to the **Ascendancy Forge**, the only facility capable of synthesizing weapons strong enough to fight back.

### 📝 Design Philosophy
Cosmic Ascendancy solves Avorion's late-game drought. Once you have Ogonite and Avorion ships, there is usually no further challenge. This mod adds an aggressively expanding, endgame-only crisis faction that forces you to optimize your fleets and defend your territory, driven by a multi-stage questline.
</details>

---

## 📖 The Ascendant Campaign
<details>
<summary><b>Click to expand</b></summary>

Defeating the Wormhole Guardian and unleashing The Eclipse triggers a scripted encounter with **Aegis, The Ascendant Envoy**, a fully voiced AI construct that drives the mod's narrative.

- **Priority Mail Dispatch:** Rather than teleporting to your location, Aegis dispatches an urgent in-game Priority Mail with secure rendezvous coordinates.
- **Isolated Rendezvous & Boss Spawns:** Every Aegis debrief and major story boss (Vanguard, Citadel Prototype, World-Eater) spawns in a safely isolated, "Empty" sector, so a world-ending fight can't land on top of a friendly AI faction's capital. The search radius is clamped between 5 and 30 jumps and respects the Galactic Barrier. Aegis herself is invincible and non-dockable.
- **5-Mission Campaign, Plus an Intro:** An initial contact stage (Aegis reaching out after the Guardian's death) leads into a 5-part campaign: The Seal is Broken, The Vanguard, Forging the Defense, The Citadel Threat, and The World-Eater. Together they cover the lore behind The Eclipse, the location of the Ascendancy Forge, and the escalating Citadel and World-Eater threats.
- **Dynamic Reward Payouts:** The dialogue tree tracks your mission-phase flags to prevent sequence breaking. Debriefing a major objective with Aegis pays out credits (scaling from 2.5M up to 25M) and high-tier subsystem or turret drops (up to Exotic and Legendary rarity) directly into your inventory.
- **Multiplayer Sector Scaling:** On a multiplayer server, Aegis doesn't despawn the instant one player accepts a mission. A dedicated despawn script keeps her in the rendezvous sector until the last player leaves, so an entire alliance can each talk to her, receive their own rewards, and pick up the quest independently.
</details>

---

## 🌑 The Eclipse Crisis (Deep Dive)
<details>
<summary><b>Click to expand</b></summary>

The Eclipse is not a standard AI faction. It does not trade, it cannot be reasoned with, and its reputation is permanently locked to `-100,000` (Hostile).

### 💥 Faction Stats & Traits
Eclipse vessels are lethal thanks to specialized Void Shields and coordinated AI behavior:
- **Void Shields:** Incoming physical damage (Cannons, Bolters, Chainguns) is reduced by **80%**. High-tier Energy, Antimatter, or Plasma weapons are the reliable way through their shields.
- **Armor Plating:** Base Hull HP is `2.5x` a vanilla-generated ship of the same volume.
- **Weaponry:** The Eclipse fields massive EMP lasers and high-velocity Plasma Artillery, both punishing against player shields.
- **Aesthetics & Classes:** Eclipse ships are towering, jet-black monolithic structures accented by crimson energy fields: Nullifiers (Pyramids), Obliterators (Monoliths), Harbingers (Obelisks), and four specialized combat classes: the Juggernaut (Dreadnought), Interceptor (Fighter), Harvester (Miner), and Defiler (Assault Frigate).

### 🌌 Ancient Eclipse Abilities
Five class-specific mechanics set the Eclipse apart from a generic AI faction:
- **Dark Matter Blink (All Ships):** After taking 15% burst damage within one second, the ship blinks 5-10km away to escape, leaving a Void Rift behind (45-second cooldown).
- **Ethereal Phase-Shift (Interceptors & Phantoms):** Upon shield break, these vanguards phase out of reality for 4 seconds, becoming an invincible void-shadow while they reposition and regenerate 25% of their max shields.
- **Adaptive Resistance (Defilers & Artillery):** These heavy combatants track incoming damage by element. Taking 5% Hull damage from one damage type in a short window triggers 15 seconds of resistance to that type, healing back 50% of what they take, decaying if they aren't hit by that element again within 3 seconds.
- **Void Siphon Aura (Carriers, Cruisers, Dreadnoughts, Juggernauts, Harbingers, and the World-Eater):** These command-class ships project a 10km draining field, pulling 1% of nearby ships' max shields (or 0.5% max hull once shields are down) per half-second tick and converting a quarter of everything drained into self-heal.
- **Singularity Implosion (the same command-class ships listed above):** On death, their reactor collapses. After a 3-second windup that pulls nearby ships toward the epicenter, it detonates for 15% of every non-allied target's max hull as true damage within 15km.

### ⚔️ Invasion Mechanics & Threat Escalation
The Eclipse dynamically targets sectors with high player or AI faction value.
1.  **Personal Ambushes:** Every 25-45 minutes, there is a 40% chance an elite Eclipse strike team personally ambushes the player's current sector.
2.  **Scouting Phase:** Small, fast Eclipse Interceptors arrive first. Left alive for 5 minutes, they broadcast a beacon.
3.  **Assault Phase:** Once the beacon is active, a full invasion fleet warps in (typically 1 Dreadnought, 3 Cruisers, and 5-8 Corvettes).
4.  **Eradication:** Eclipse fleets prioritize destroying stations. Destroyed AI stations permanently reduce local economic output; destroyed player stations are gone for good.

### 🌌 Territorial Conquest
The Eclipse's first foothold always appears near the galactic core, the same point their rupture tore open. From there, territory spreads outward toward the rim: 70% of expansion steps bias outward from the core relative to the sector they're spreading from (with perpendicular jitter so the frontier isn't a perfect ring), and the remaining 30% is fully random, filling in behind the advancing edge. Each conquered sector rolls a 40% chance of **Conquest** (a contested siege, if Cosmic War is installed) against a 60% chance of outright **Annihilation** (a total wipe).

### 📈 Adaptive Eclipse Scaling
The Eclipse adapts to the server's power level. The engine scans for the player with the highest Global Ascendancy Tier. For each tier that player has reached, the entire Eclipse faction globally gains a **+50% multiplier** to physical ship volume, hull, and shields.

### 🗡️ The Nemesis System
An Eclipse Dread-Lord that drops below 5% HP retreats, remembering whichever damage type hurt it most (Plasma, Physical, and so on). It returns with a 90% resistance to that specific damage type.

### 🎯 Hunt the Dread-Lord
A retreating Nemesis isn't gone for good. It relocates to a nearby sector to recover, healed back to a meaningful fraction of its hull rather than the sliver it fled with. The moment any player enters that sector, the wounded Dread-Lord materializes there for a rematch, adaptive resistance and all. Destroying it this time pays out a bounty and closes the hunt. Its last known coordinates are always visible via `/eclipsestatus`.

### 👑 The Fallen Empire
Once the Eclipse conquers or annihilates **75 sectors** unchecked, it consolidates into a **Fallen Empire** and stops expanding at random. Instead, it launches deliberate Crusades:
- 🏛️ **Faction Capitals:** Its primary Crusade target is AI faction homeworlds, hunted down systematically to eradicate rival empires.
- ⚔️ **Player & Alliance Territory:** A Fallen Empire also occasionally targets a player's or alliance's own sectors, but only ones with an actual station on them, on a dedicated 40-minute cooldown separate from the AI-faction Crusade cadence (needed because threat re-accumulates fast at a high conquered-sector count, roughly every 5-6 minutes once well past 75). It also excludes whichever player or alliance was targeted last time, so consecutive Crusades rotate rather than singling out the same target. A targeted sector goes through the same 40% Conquest / 60% Annihilation roll as any other Crusade target; player- and alliance-owned entities are never deleted by an Annihilation roll, so the worst case is the sector turning hostile (Dark Matter Fog plus an Eclipse garrison) until it's cleared back out.

### 🧬 Remnant Escalation
A galaxy that keeps clearing World-Eaters and Citadels doesn't stay at the same difficulty forever. Every confirmed kill builds toward a **Remnant Tier**, up to Tier 5 (a World-Eater kill counts for three times a Citadel kill). Each tier adds a modest Shield, Hull, and Damage bump to every future World-Eater and Citadel, and shrinks the World-Eater's 3-5 hour spawn window by up to 75 minutes at the maximum tier. Escalating a tier is announced galaxy-wide and via the Galactic News Network. Current tier and kill counts are always visible via `/eclipsestatus`.
</details>

---

## 🎵 The Choir & Endgame Additions
<details>
<summary><b>Click to expand</b></summary>

Six mechanics layered on top of the systems above, all reachable through the Eclipse's existing
awakening chain -- no new setup required on an existing save.

### 🗡️ Eclipse Remembers
Every Eclipse ship you personally destroy raises your own kill score. The higher it climbs, the
more the Eclipse targets you specifically: Personal Ambush chance rises from a 40% base up to 85%,
and the escort fleet gains up to 4 additional heavy-class ships. This is what's actually behind
the "Every 25-45 minutes, 40% chance" framing elsewhere in this document -- that's the floor, not
the whole picture.

### 🎼 The Choir
Ambient rumors about the Eclipse escalate as the crisis does -- new dialogue lines register the
moment the Eclipse first wakes, fully awakens, and becomes a Fallen Empire, rather than all being
available from the start. A one-shot audio stinger also plays the first time you personally cross
into Eclipse-held territory in a session.

### 🥷 The Silent Choir
A rare, named horror -- a lone Phantom-class hunter -- occasionally stalks a single online player
across the galaxy: sighted at the edge of sensors, a whisper, then gone. After the third sighting,
it stops vanishing and commits to a real fight. Its last known coordinates are always visible via
`/eclipsestatus`.

### 🛡️ The Ascendant Ward
A craftable item at the Ascendancy Forge (10 Ascendant Matter + 20 Ascendant Scrap, instant craft)
that suppresses the Eclipse's own hunting behavior against you specifically for 30 minutes: Personal
Ambush rolls, Silent Choir targeting, and the Void Siphon aura's targeting of your ships. It does
not grant blanket invisibility -- vanilla AI faction hostility is untouched.

### 📡 Distress Beacon
When a Fallen Empire Crusade targets a player's or alliance's own sector, every online member of
that faction receives a Priority Mail with the target coordinates -- a real chance to converge and
defend before the consequence lands.

### 🖥️ The Eclipse: Command Interface
A standalone UI window, opened by interacting with your own ship, showing everything
`/eclipsestatus` reports plus your personal kill score, Ward status, and Silent Choir sighting
info -- across four tabs (Overview / Territory / Threats / Personal), refreshed live while open.

### 🏰 Capital Sieges
Once you've built an Ascendancy Beacon, it draws attention: every 3 to 6 hours, a siege fleet
(Pirates, Xsotan, or a hostile War Faction if Cosmic War is installed) invades your capital sector
to destroy it. Defend it and you're paid out in loot and credits; lose it and your Beacon's global
buffs collapse along with the structure itself.
</details>

---

## 🚨 The World-Eater Doomsday Event
<details>
<summary><b>Click to expand</b></summary>

A global crisis managed by the galaxy engine.

- **The Trigger:** Every 3-5 hours of active playtime, a random populated player sector is targeted. The timer automatically pauses if no players are online, protecting 24/7 dedicated servers from being wiped while the server sits empty.
- **Multiplayer/Alliance Scaling:** A solo fight is tuned exactly as designed. Every additional defender present in the sector at spawn raises Shield Durability, Hull Durability, and damage on a diminishing-returns curve, on top of its existing base multipliers and its separate Ascendancy-Tier-based Adaptive Scaling -- a duo fight scales almost exactly like before, an 8-player raid faces a real but no-longer-runaway increase, and even a huge dedicated-server raid keeps facing growing difficulty rather than hitting a wall. This runs identically across all three ways to encounter the boss: the natural Doomsday Event, the player-summoned Raid (below), and the scripted campaign encounter in story mission 5 -- a full alliance playing the campaign together faces a boss tuned for their numbers too, not one sized for a single defender.
- **The Threat:** A World-Eater Juggernaut (5.9 kilometers long, `125x` Hull Mass, `-90%` Speed) spawns 15,000 km away. Unlike lesser Eclipse ships, it relies purely on its colossal Hull and dynamic mechanics.
  - **⛓️ Anchor Pylon Tethers:** On spawn, the World-Eater summons 4 Eclipse Juggernauts. Until all 4 are destroyed, the boss is **100% invincible**, visually tethered to them by purple lasers. It regains the same invincibility twice more during the fight: 2 additional Anchor Pylons spawn at 50% Hull and again at 25% Hull, and the boss stays invincible each time until those fresh tethers are also destroyed.
  - **Nemesis Protocol:** The boss scans incoming DPS. Overwhelming burst damage engages the Nemesis Protocol, cutting all incoming damage by 90% to prevent an instant kill.
  - **World-Breaker Laser:** A colossal coaxial laser that obliterates anything caught in its 15km path, dealing 100% max shields and 50% max hull damage.
  - **⚡ Quantum EMP:** Periodically targets a random player with a cyan glow. After 3 seconds, an EMP erupts, stripping 100% of their shields and inflicting 25% max hull damage.
  - **⚫ Gravity Anomaly:** Periodically spawns a dark purple black hole at a player's location, pulling all nearby ships toward the center, draining 5% of max hull per second while trapped in the blast zone.
  - **💥 The 6-Phase Gauntlet:** As its hull is chipped away, the boss triggers escalating desperation mechanics:
    - **80% HP:** Spawns 5 Defiler Escorts.
    - **70% HP:** Emits a global EMP pulse, stripping 50% of the shield capacity from every player in the sector.
    - **60% HP:** Deploys 4 Eclipse Assassin Hunter-Killers.
    - **50% HP:** Blinks to a distant point in the sector, heals up to 5% of its Max Hull, and spawns 2 Auxiliary Anchor Pylons (regaining invincibility, see above).
    - **35% HP:** Blinks again, unleashes a second global EMP, and enters an **Enraged state** (+50% Fire Rate, +50% global damage), projecting a 15km sector-wide Dark Matter Aura that continuously drains hull integrity from every hostile ship inside it.
    - **25% HP:** Spawns 2 more Auxiliary Anchor Pylons, regaining invincibility a final time.
- **The Outcome:** If not destroyed within 20 minutes, the sector is completely wiped (all stations and AI ships deleted, player ships reduced to 1 HP) and ownership transfers to The Eclipse.
- **💰 Loot:** Destroying the World-Eater yields a large amount of Ascendant Matter and high-tier subsystems.
- **🕊️ The Grace Period:** After a World-Eater event concludes, whether the boss is destroyed or the sector is annihilated, the entire galaxy gets a **10 real-time hour Grace Period**. The Doomsday clock is completely paused, letting players rebuild without fear of an immediate second strike.

### 📡 The Summoning Beacon
If you'd rather face the ultimate threat on your own terms, you can summon it directly.
- **Raid Summoning:** Jettisoning an **Eclipse Datacore** from your cargo hold into space acts as a quantum beacon. If no other Eclipse ships are currently in the sector, the datacore collapses, tearing open a hyperspace rift and summoning the **Eclipse World-Eater** on the spot.
</details>

---

## 🏰 Eclipse Citadels
<details>
<summary><b>Click to expand</b></summary>

When an invasion overwhelmingly succeeds, the Eclipse permanently occupies the sector and constructs a **Citadel**. Its garrison and orbital escorts are drawn from the same combat classes described above, so the abilities below are the same mechanics documented in the Eclipse Crisis Deep Dive, not separate ones.

### ⚔️ Eclipse Combat Classes & Abilities
- **Void Siphons (Carriers, Cruisers, Dreadnoughts, Juggernauts, Harbingers):** A 10km draining field. Ships caught inside it have their shields drained first, then their hull once shields are down, healing the Siphon for a share of what it drains.
- **Singularity Collapse (Dreadnoughts/Carriers):** Their core detonates on death, stripping 15% of max hull as true damage to everything within 15km. During the 3-second windup, the core acts as a Gravity Well, pulling nearby ships toward the epicenter.
- **Ethereal Phase Shifts (Phantoms/Interceptors):** Upon losing shields, they enter a 4-second invincible Phase Shift and regenerate 25% of their max shields while phased.
- **Adaptive Memory (Defilers):** Their adaptive armor grants compounding resistance to elemental damage types, decaying if they aren't hit by that element for 3 seconds.

### ⚙️ Mechanics
- 🚫 **The Lockdown Matrix:** Citadels generate a sector-wide interdiction field. Ships can't jump out of a Citadel sector until the Citadel is destroyed.
- 💣 **Siege Scale:** Citadels have `200,000,000` base HP (scaling with difficulty) and are surrounded by 4 orbital defense platforms.
- 💰 **Loot & Rewards:** Destroying a Citadel guarantees 1-3 Legendary subsystems, large quantities of Avorion ore, and unique crafting materials for the Ascendancy Forge.
- ⏳ **Suppression Field:** Destroying a Citadel halts all Eclipse invasions galaxy-wide for a base of 6 real-time hours, plus 2 more hours for every 10 sectors the Eclipse currently holds.
- 🕊️ **Territorial Liberation:** Beyond pausing the advance, the Citadel's own sector and any Eclipse-held territory within a 15-sector radius of it are reclaimed outright, rolling their frontier back rather than just buying time.
</details>

---

## 🗼 The Ascendancy Beacon
<details>
<summary><b>Click to expand</b></summary>

Players can construct the ultimate megastructure to anchor their empire: the **Ascendancy Beacon**.

### ⚙️ Mechanics
- 🌍 **Permanent Sector Simulation:** A sector containing an active Ascendancy Beacon is simulated 24/7, even with no players online.
- ✨ **Global Buffs:** The Beacon applies a permanent stat multiplier to every ship in the player's fleet, galaxy-wide.
- 🔺 **Upgrades & Upkeep:** The Beacon upgrades through 5 tiers, each raising the global stat buffs. Higher tiers require continuous upkeep in Credits, Avorion, and Ogonite.
- 🛡️ **Sanctuary Field (Tier 3+):** Once upgraded to Tier 3 or higher, the Beacon actively repels Eclipse conquest and annihilation attempts within a radius of it: 5 sectors at Tier 3, 8 at Tier 4, and 12 at Tier 5. It stays in effect for as long as the Beacon remains active at that tier, even while its own sector is unloaded.
- 💸 **Passive Real-Estate Income:** Beacons automatically tax passing AI-controlled freighters. The toll scales with the passing faction's War Heat; factions actively at war pay a `+50%` premium for safe passage through your capital.
- 🏦 **Treasury Payouts:** To avoid notification spam, the Beacon stores all collected tolls internally and pays out a single lump sum to your faction every 45 minutes, synced with the upkeep cycle.
- 🏗️ **Construction:** Follows Avorion's standard station-building mode. Select `Ascendancy Beacon` if you have it unlocked and the required resources.
</details>

---

## 🗺️ Dynamic Faction Expansion
<details>
<summary><b>Click to expand</b></summary>

Vanilla Avorion features a static map. With Cosmic Ascendancy, **civilized AI factions** and **Pirates** slowly and naturally expand their borders over time.
- 🗺️ **Organic Growth:** Civilized factions trace outward from their home sectors to claim contiguous empty sectors, spawning new stations and annexing the territory.
- 🏴‍☠️ **Pirate Bases:** Deep space is no longer permanently safe. Pirates occasionally establish Smuggler's Hideouts and Pirate Shipyards in uncharted systems.
- 📰 **News Alerts:** Major territorial expansions broadcast live via the Cosmic Chronicles News Network.
- ⚡ **Zero-Stutter Performance:** Territory expansion and station generation are queued in the background and materialize instantly when a player jumps into the sector, avoiding the lag spikes that traditional background sector loading causes.
</details>

---

## 🌌 The Dark Sector
<details>
<summary><b>Click to expand</b></summary>

Once the Eclipse is awake, discovering an un-generated sector inside the Galactic Core triggers a probability roll to spawn a **Dark Sector**. The chance scales aggressively toward the core:
- **5-15%** in the outer galaxy
- **25%** inside the mid-core (distance to center ≤ 150)
- **50%** in the deep inner-core (distance to center ≤ 75)

Dark Sectors are permanently choked in Dark Matter Fog and heavily guarded, with up to 3 Eclipse Citadels surrounded by Dreadnought fleets. Dive in if you dare.
</details>

---

## 🛠️ The Ascendancy Forge (Crafting & Math)
<details>
<summary><b>Click to expand</b></summary>

To fight the Eclipse, players must locate and use the Ascendancy Forge to craft gear that pushes past Avorion's native limits.

### 🔓 Unlock Requirements
- The Forge is discovered at the climax of the main storyline.
- Decrypt your first **Eclipse Datacore** at the Forge to power it on. The same action that raises your Global Ascendancy Tier permanently unlocks Forge access for your account, so no separate activation step exists.

### 📈 Crafting Formula & Global Ascendancy
Crafting Ascendant-tier gear and decrypting datacores is extraordinarily expensive, to balance its extreme power.

- **💰 Base Crafting Cost:** Scales up to `300,000,000` Credits, `3,000,000` Avorion, and 25-50 Ascendant Matter.
- ⏱️ **Crafting Time:** 24 real-time hours per weapon or subsystem, processed asynchronously so it continues while you're offline or the server restarts.
- 📈 **Global Ascendancy Matrix:** Submit **Eclipse Datacores** (dropped by Eclipse Juggernauts) to the Forge. Each decrypted datacore permanently raises your Global Ascendancy Tier, stacking `+15%` Shields, `+20%` Shield Recharge, and `+10%` Hyperspace Cooldown across your entire fleet.
- 🙏 **The Sacrifice System:** Initiating a craft requires sacrificing existing Legendary or Exotic subsystems as catalysts.
  - `1x Legendary` = **20%** success rate.
  - `1x Exotic` = **10%** success rate.
  - **Ascendant Scrap:** Short of 100% success rate, the Forge automatically consumes Ascendant Scrap from your cargo hold to bridge the gap. Each unit adds **+2%** to the success rate.
- 💥 **War Heat Bonuses:** If *Cosmic War* is installed, your faction's War Heat is added as a multiplier to the weapon's damage on claiming it, capped at **10.0x**.
- 💔 **Failure:** A failed craft destroys the sacrificed subsystems and raw materials, but yields Ascendant Scrap, which can be sold to underground tech brokers or fed back into a future attempt.

### ⚔️ New Subsystems
- **Ascendant Swarm Nexus:** Boosts Production Capacity and fighter squadron count.
- **Ascendant Void-Drill:** Boosts Transporter Range, Loot Range, and Generator Energy. Its immense power draw occasionally vents harmless plasma bursts every 60-120 seconds as VFX.
- **Ascendant Neural Implant:** Wires the captain directly into the ship's core processors, scaling jump reach, fighter squadrons, and turret slots while injecting extreme velocity.
- **Ascendant World-Breaker:** A Titan-Class coaxial superweapon capable of 250,000 continuous damage.

### ✨ Ascendant Subsystem Stats
Ascendant subsystems form a new rarity tier (`Ascendant`) with purple/gold UI text, hardcoded to provide 50% greater baseline stats than the maximum possible roll of a vanilla Legendary.

#### Example: The Ascendant Shield Booster
- *Vanilla Legendary Max:* `+60%` Shield Durability.
- *Ascendant Variant:* `+90%` Shield Durability, `+15%` Recharge Rate, and immunity to EMP damage.

#### Example: The Ascendant Core Processor
- *Ascendant Variant:* `+15` Arbitrary Turrets, `+15` Armed Turrets, `+50%` Energy Generation.

### 🏭 Resource Procurement & Factory Overdrive
The Forge runs on **Ascendant Matter**, a condensed energy resource found only in the dark reactors of Eclipse vessels. Destroying normal Eclipse ships has a chance to drop small quantities; obliterating the World-Eater guarantees a large yield.
- **Factory Overdrive:** Feed any factory you own 50 Ascendant Matter to trigger "Ascendant Overdrive": a `3.0x` production capacity multiplier for 1 real-time hour.
</details>

---

## 🤝 Synergies & Integrations
<details>
<summary><b>Click to expand</b></summary>

Cosmic Ascendancy is built to require only **Cosmic Vault**, but it recognizes the other Cosmic mods when they're present and deepens the experience with them installed.

### Cosmic Series Integration
- 📦 **Eclipse Contraband (Overhaul):** Eclipse Tech pays out **3x** at Smuggler's Markets.
- 💀 **Corrupted Nodes (Chronicles):** Eclipse territories corrupt data caches, doubling their loot but spawning ambushes.
- ⚔️ **Relentless Expansion (War):** Eclipse AI is inherently Imperialist and Vengeful, expanding rapidly and refusing all ceasefires.
- 🌪️ **Hazard Immunity (Vault):** Eclipse Dreadnoughts are immune to Cosmic Vault weather hazards like Solar Flares and Ion Storms.
- 🗺️ **Dead Empire Filter (Vault):** The Eclipse Conquest Engine filters out destroyed empires, preventing Crusades from targeting factions that no longer exist.
- ✨ **Post-Boss Anomalies (Vault):** Destroying the Eclipse World-Eater spawns a persistent Precursor Wreck anomaly for exploration and salvaging.

### Rift DLC Interoperability
- **Rift Spillage:** Eclipse Invasions have a 10% chance to destabilize local space, tearing a subspace rift that drains sector shields. Destroy the **Eclipse Rift Stabilizer** to close the tear and end the hazard.
</details>

---

## 💻 Player Commands
<details>
<summary><b>Click to expand</b></summary>

Cosmic Ascendancy adds global chat commands that any player, not just admins, can use to track the Eclipse Crisis.

### `/eclipsestatus`
Typing this into chat queries the server and privately prints a full Eclipse Threat Dashboard:
- **Eclipse Holdings & Expansion Threat:** Total sectors conquered or annihilated, and how close the Eclipse is (as a percentage) to its next expansion attempt.
- **Fallen Empire Status:** Whether the Eclipse has become a Fallen Empire, and if so, the coordinates, target kind, and timing of its last Crusade.
- **Nemesis Signature:** The last known coordinates of a currently-fleeing, wounded Eclipse Dread-Lord, if one exists.
- **Remnant Escalation:** The current Remnant Tier and confirmed World-Eater/Citadel kill counts.
- **Citadel Suppression Field:** Remaining time on the invasion suppression caused by destroying an Eclipse Citadel.
- **World-Eater Grace Period:** Remaining time on the Doomsday pause after a World-Eater event.
</details>