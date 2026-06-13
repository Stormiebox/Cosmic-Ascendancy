# Cosmic Ascendancy - Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

--

## [v1.0.0] - UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)

The ultimate endgame expansion for the Cosmic Series has arrived. Establish your empire's permanent capital, generate immense wealth, forge god-tier weaponry, and defend against gargantuan sieges!

### UI & Codex
- **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.

### Added

### Story Campaign
- **New Campaign: The Eclipse Awakening**: A massive, epic 3-part storyline that automatically triggers when you interact with the Adventurer or Hermit near the galactic core.
- **The Ascendant Forge Unlock**: The Ascendant Forge is now securely locked behind the completion of the new story campaign.
- **New Artifact: The Eclipse Bane**: A legendary reward for completing the campaign. Grants massive bonuses to Hull, Shields, Turret Slots, Jump Range, and Damage.

- **Eclipse Strongholds**: Conquered unexplored sectors now have a 25% chance of spawning as fully fortified Eclipse Strongholds.
- **Multiplayer Boss Scaling**: Implemented dynamic `applyPermanentFactor` scaling. Harbingers and Citadels now inherently gain +100% Shield and +50% Damage per additional player in the sector.
- **Vault Fleet Integration**: Siege and Invasion fleets now utilize the `CosmicVaultFleet.orderAttackEnemies()` API to ruthlessly hunt down players rather than idling.
- **The Eclipse Oblivion Engine**: Added an apocalyptic new roaming superboss. It actively hunts populated sectors, obliterates everything, dynamically broadcasts via Galactic News, and rewards the galaxy's defenders with 5 Billion credits and maximum-tier loot! (Also includes a 'Stormbox Protocol' lore Easter Egg).
*   **The Ascendancy Beacon**: A brand new massive station that permanently keeps its sector loaded (24/7). Players can upgrade this beacon from Tier 1 to Tier 5 using astronomical amounts of credits and ores.
*   **Global Ascendant Buffs**: Upgrading your beacon grants a permanent, account-wide stat buff to all ships in your fleet, multiplying Hull, Shields, and Damage.
*   **The Grand Toll**: Since the sector is permanently loaded, the beacon acts as an intergalactic border checkpoint. All NPC traders and AI factions jumping into the sector are charged a massive entry tax that scales with the beacon's tier.
*   **Dynamic Wartime Premium**: Integrated with `Cosmic War`. AI factions currently engaged in massive wars will desperately pay up to a **+50% Premium Toll** for seeking safe harbor in your sector.
*   **Capital Sieges**: A hidden playtime clock runs within the beacon. Every 3 to 6 hours, a devastating siege fleet (Pirates, Xsotan, or War Factions) will invade your sector to destroy the beacon. If you defend it, you earn legendary loot. If it falls, your global buffs collapse.
*   **The Stellar Forge**: Exchange 1+ Billion Credits and massive ore reserves to asynchronously craft custom God-Tier weapons or Relic Subsystems over 24 real-time hours.
*   **Ascendant Subsystems (Living Relics)**: Four game-breaking subsystems (War-Drive, Aegis Matrix, Slipstream Core, Omni-Sensor) that dynamically multiply their power up to 7.5x based on your current Core Proximity and the Empire's War Heat!
*   **Wartime Innovation**: Weapons crafted at the Stellar Forge receive exponential damage multipliers based on how close the forge is to the Galactic Core (+200%) and your current War Heat (+150%). Forging at the core during a massive war yields a 9.0x damage super-weapon!

### Integrations
*   **Cosmic Vault**: Utilizes `CosmicVaultBuffs` API for global multiplier injections, and `CosmicVaultNews` to broadcast your empire's ascension, sieges, and falls to the entire galaxy.
*   **Cosmic War**: Deeply integrated with `CosmicWarBridge` to fetch War Heat for dynamic toll scaling, siege attackers, and Forge weapon multipliers.
*   **Cosmic Overhaul**: Requires standard Overhaul progression limits.
*   **Cosmic Chronicles**: Adds lore and weight to the massive empire capital milestones.

### Bug Fixes & Compliance
- **Galaxy Engine Initialization:** Fixed a critical structural issue where `server.lua` was placed in the wrong directory (`scripts/server/` instead of `scripts/galaxy/`). The Eclipse Awakening events will now correctly hook into newly generated sectors and spawn Eclipse Citadels as originally intended.
- **Multiplayer Synchronization:** Replaced all instances of `math.random` with Avorion's deterministic `random()` engine to prevent massive multiplayer client/server desyncs when generating loot, stats, and enemies.
*   **Keep-Alive Engine**: Built a dedicated background galaxy script (`ascendancykeepalive.lua`) to ensure the server physically holds beacon sectors in memory instead of unloading them.
*   **Alliance Buff Injection**: Patched the player synchronization script so that Alliance defense fleets properly inherit the global Ascendant stats when jumping into a sector.
*   **Stat Bloat Safety**: Added `onRemove` callback safety nets to prevent players from keeping permanent stat bloat if the beacon is destroyed or the mod is uninstalled.
*   **Asynchronous Forge Safety**: Ensured the forge utilizes server-side global playtime to prevent duplication exploits and allow crafting to continue gracefully while players are offline or during server restarts.
*   **Subsystem Memory Leak Patch**: Injected `secure()` and `restore()` persistence hooks into the Living Relic subsystems to prevent an infinite stat-stacking exploit and server crash when sectors rapidly load/unload.

### Endgame Expansion: The Eclipse
*   **The Awakening:** The death of the Xsotan Wormhole Guardian now triggers a galaxy-wide event. After a 10-minute agonizing delay of subspace anomalies, an ancient, ravenous faction known as **The Eclipse** awakens.
*   **Geometric Nightmares:** The Eclipse fly massive geometric structures made of black Avorion with glowing red accents: Nullifiers (Pyramids), Obliterators (Monoliths), and Harbingers (Obelisks).
*   **Relentless Invasions:** Once awake, The Eclipse will aggressively hunt down players across the galaxy, spawning massive invasion fleets directly on top of active players.
*   **Galactic Conquest:** New unexplored sectors have a 5% chance of already being conquered by The Eclipse, housing massive fortified Citadels.
*   **Game-Breaking Arsenal:** The Eclipse utilizes a customized weapon generator that forces Tech 52 (Maximum), boosts all weapon damage, reach, and fire rate significantly, and forces 100% accuracy.
*   **Cross-Mod Integration:** If *Cosmic Starfall* is installed, The Eclipse will randomly utilize its god-tier weaponry alongside their vanilla max-tech arsenal.
*   **Ascendant Bosses:** Eclipse Harbingers utilize the "Living Relic" subsystem mechanics internally, multiplying their shields by 3750% and damage by 500%.
