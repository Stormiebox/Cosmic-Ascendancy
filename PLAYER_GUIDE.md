# ⚔️ Cosmic War: A Player's Guide to a Living Conflict

In the vast universe of Avorion, empires rise and fall, but have you ever felt like the wars between them lack impact? **Cosmic War** was built to change that by transforming the static, unpredictable faction battles of the base game into a deeply simulated, escalating geopolitical sandbox.

Here is a plain-English breakdown of exactly how Cosmic War works behind the scenes, and how it differs from the base game.

---

## ⚔️ The Vanilla Way: Static "On or Off" Wars

To understand why Cosmic War is special, you first need to understand how the base game handles faction conflicts.

In vanilla Avorion, diplomacy is very simple. Two factions either like each other, or they don't. If their relations drop low enough, a switch flips from "Peace" to "War." Once that switch flips, their ships might occasionally shoot at each other if they happen to spawn in the same sector.

> **The Limitation: Zero Depth and No Consequences**
>
> * Wars never naturally end unless the random number generator randomly decides to improve their relations.
> * There is no buildup or escalation.
> * Wars have no effect on the economy.
> * You, the player, rarely even know a war is happening unless you physically watch two ships shooting each other.

## ⚙️ The Cosmic Way: The "War Heat" System

Cosmic War completely replaces this binary switch with a highly advanced, sliding scale called **War Heat**. Instead of just "War" or "Peace," tensions simmer, boil, and eventually explode.

Every faction in the galaxy is secretly assigned a personality when they are generated:

* **War Bias:** Are they aggressive conquerors or peaceful traders?
* **Diplomatic Polarity:** Are they forgiving and willing to negotiate, or are they mistrustful and hold grudges?

As relations deteriorate between two rival factions, the **War Heat** scale rises from `0` to `100`. The entire galaxy reacts to this number in real-time.

### 🤝 1. Living Politics & Consequences

Because of these hidden personalities, politics constantly drift. A highly aggressive faction might bully their neighbors, driving up War Heat.

* **Diplomatic Sanctions:** As War Heat rises, factions actively embargo and sanction each other. You will see factions physically losing millions of credits as their economies bleed from the war effort.
* **War Bounties:** Factions will post massive, time-sensitive bounties on their rivals, offering you huge payouts to join the fight.
* **The News Network:** You don't have to guess who is fighting anymore. The Cosmic War News Network will actively broadcast strategic alerts to your chat window, letting you know exactly when relations deteriorate and where the hotspots are.
* **Détente & Ceasefires:** Unlike vanilla, wars in Cosmic War can naturally end. If frontline commanders suffer enough losses, or if relations slowly recover, factions will sign ceasefires and return to peace.

### ⚔️ 2. Dynamic War Contracts

In vanilla Avorion, military missions are mostly "Go here, kill pirates." Cosmic War directly injects highly-scaled **War Contracts** into station Bulletin Boards that perfectly match the current War Heat:

* **Low Heat (Cold War):** Factions will hire you for *Force Recon* to scan covert enemy listening posts, or to intercept shady *Black Market Arms Deals*.
* **Medium Heat (Escalation):** The gloves come off. You will be hired for *Border Skirmishes* to eliminate patrols, *Resource Sabotage* to cripple enemy mining operations, or to escort allied supply convoys breaking through enemy blockades.
* **Maximum Heat (Total War):** Command will authorize *Frontline Sieges* against heavily fortified Forward Operating Bases, or *High-Value Extractions* to rescue defecting enemy officers.
* **The Climax:** If War Heat hits 100%, you will be offered a *Decapitation Strike*. You must hunt down and destroy an astronomically scaled Enemy Flagship Dreadnought. If you succeed, the enemy fleet breaks, and the two factions immediately sign a ceasefire.

### 3. Deep Space Flashpoints

Cosmic War doesn't just wait for you to take a mission. As you explore the galaxy, the war will find *you*. If you jump into an empty or border sector, you might stumble directly into a **Dynamic Flashpoint** based on local tensions:

* **Refugee Convoys:** You might intercept a civilian convoy with damaged hyperdrives begging for help while a ruthless hunter fleet closes in.
* **Diplomatic Sabotage:** You might find a Peace Envoy under heavy fire from hardliner extremists trying to prevent a ceasefire.
* **Fleet Clashes:** In highly volatile sectors, you might hear a warning siren right before a massive, multi-ship invasion fleet drops out of hyperspace to assault the sector you are currently in.
* **Stranded Flagships:** You might stumble across a heavily damaged enemy Dreadnought drifting in space. Do you destroy it, or do you flee before its repair fleet arrives?

### 🤝 4. The Galactic Politics Tab

In vanilla Avorion, you have no way to know who is fighting who unless you memorize chat messages or stumble into a warzone. Cosmic War introduces a brand-new **Galactic Politics Tab** directly into your Player Window.

* **Real-Time Intelligence:** See a live, color-coded list of every active war, ceasefire, and bounty across the entire galaxy.
* **Interactive Filtering:** Sort the list by "War Heat" to find the most explosive warzones, or filter for "Active Bounties" if you want to make some quick credits as a mercenary.
* **Strategic Tooltips:** Hover over any conflict to reveal hidden AI personalities (like Aggressive or Peaceful) and the exact credit payout for active war bounties.
* **Immersive Diplomacy:** Instantly see how you stand with fighting factions, helping you decide whether to intervene and save your allies, or sit back and watch your enemies destroy each other.

---

### 🔗 Cross-Mod Synergy

Cosmic War is powerful on its own, but it was designed to plug directly into the rest of the Cosmic ecosystem.

* If you use **Cosmic Chronicles**, the ambient dialogue of civilians and station workers will change dynamically based on the current War Heat.
* If you use **Cosmic Overhaul**, the War Heat will actively manipulate the economy, making trade routes through warzones far more dangerous, but drastically more profitable!

### Summary

**Cosmic War** gives factions a memory, a personality, and a real geopolitical presence. It ensures that no two playthroughs are the same, and that the galaxy is always moving, shifting, and escalating around you!


---

## 🔗 Cosmic Series Integration & Audit 3.0 Updates
<details>
<summary><b>Click to expand</b></summary>

During the Cosmic Series Final QA Audit (v3.0+), several massive backend systems were standardized across all mods:

### 📖 Cosmic Codex Integration
All deep lore, stat blocks, and dynamic recipes have been fully integrated into the in-game **Cosmic Codex**. You no longer need to tab out of the game to read these features; they will natively update and unlock inside your Codex UI as you progress!

### 🔒 Network Safety & Anti-Cheat
- **Math.Random Fix:** We systematically replaced all unstable Lua `math.random` calls with Avorion's deterministic `random():getInt()` generation sequence. This guarantees 100% synchronization on Multiplayer Dedicated Servers and prevents cascading desyncs during massive fleet spawns.
- **Callable Validation:** UI and background scripts have been fully hardened. Malicious clients can no longer spoof "free" remote calls; the server actively verifies execution contexts before processing any requests, sealing multiple Arbitrary Code Execution (ACE) vulnerabilities.

### 🛠️ Vanilla Bug Fixes
- **Scout Mission Fix:** We patched a massive, long-standing vanilla bug where Scout Missions would completely skip and ignore Faction Headquarters sectors because the native dialogue trees were missing the template definition.
</details>


---

### Ascendancy Beacon & Codex
The Cosmic Codex has been radically expanded to properly categorize the Eclipse Crisis.
**The Ascendancy Beacon:** 
A late-game construct that applies permanent, galaxy-wide stat multipliers to the player's fleet. Sector instances containing a beacon are simulated 24/7 without requiring the player to be online.
