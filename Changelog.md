# Changelog

All notable changes to **Cosmic Ascendancy** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v1.0.0] - UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)

The ultimate endgame expansion for the Cosmic Series has arrived. Establish your empire's permanent capital, generate immense wealth, forge god-tier weaponry, and defend against gargantuan sieges!

### 🚀 Major Overhaul Features
- **The Ascendancy Beacon:** A brand new massive station that permanently keeps its sector loaded (24/7). Players can upgrade this beacon from Tier 1 to Tier 5 using astronomical amounts of credits and ores.
- **Global Ascendant Buffs:** Upgrading your beacon grants a permanent, account-wide stat buff to all ships in your fleet, multiplying Hull, Shields, and Damage.
- **The Stellar Forge:** Exchange 1+ Billion Credits and massive ore reserves to asynchronously craft custom God-Tier weapons or Relic Subsystems over 24 real-time hours.
- **Endgame Expansion: The Eclipse:** The death of the Xsotan Wormhole Guardian now triggers a galaxy-wide event. After a 10-minute agonizing delay of subspace anomalies, an ancient, ravenous faction known as **The Eclipse** awakens and aggressively hunts players.
- **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.

### ✨ Added
- **New Campaign: The Eclipse Awakening:** A massive, epic 3-part storyline that automatically triggers when you interact with the Adventurer or Hermit near the galactic core.
- **New Artifact: The Eclipse Bane:** A legendary reward for completing the campaign. Grants massive bonuses to Hull, Shields, Turret Slots, Jump Range, and Damage.
- **Eclipse Strongholds:** Conquered unexplored sectors now have a 25% chance of spawning as fully fortified Eclipse Strongholds.
- **Geometric Nightmares:** The Eclipse fly massive geometric structures made of black Avorion with glowing red accents: Nullifiers (Pyramids), Obliterators (Monoliths), Harbingers (Obelisks), and 4 massive new specialized classes (Juggernaut, Interceptor, Harvester, Defiler) that utilize dynamically scaled, jagged aesthetics.
- **Ascendancy Beacon Megastructures:** Players founding an Ascendancy Beacon will now instantly automatically deploy a massive, customized megastructure `.xml` design instead of a procedural vanilla station.
- **Game-Breaking Arsenal:** The Eclipse utilizes a customized weapon generator that forces Tech 52 (Maximum), boosts all weapon damage, reach, and fire rate significantly, and forces 100% accuracy.
- **The Eclipse Oblivion Engine:** Added an apocalyptic new roaming superboss. It actively hunts populated sectors, obliterates everything, dynamically broadcasts via Galactic News, and rewards the galaxy's defenders with 5 Billion credits and maximum-tier loot! (Also includes a 'Stormbox Protocol' lore Easter Egg).
- **Ascendant Subsystems (Living Relics):** Four game-breaking subsystems (War-Drive, Aegis Matrix, Slipstream Core, Omni-Sensor) that dynamically multiply their power up to 7.5x based on your current Core Proximity and the Empire's War Heat!
- **Cross-Mod Integration:**
  - **Cosmic Vault:** Utilizes `CosmicVaultBuffs` API for global multiplier injections, and `CosmicVaultNews` to broadcast your empire's ascension, sieges, and falls to the entire galaxy.
  - **Cosmic War:** Deeply integrated with `CosmicWarBridge` to fetch War Heat for dynamic toll scaling, siege attackers, and Forge weapon multipliers.
  - **Cosmic Starfall:** If installed, The Eclipse will randomly utilize its god-tier weaponry alongside their vanilla max-tech arsenal.
  - **Cosmic Overhaul & Chronicles:** Adds lore and weight to the massive empire capital milestones.

### ⚙️ Changed & Balanced
- **The Grand Toll:** Since the sector is permanently loaded, the beacon acts as an intergalactic border checkpoint. All NPC traders and AI factions jumping into the sector are charged a massive entry tax that scales with the beacon's tier.
- **Dynamic Wartime Premium:** Integrated with `Cosmic War`. AI factions currently engaged in massive wars will desperately pay up to a **+50% Premium Toll** for seeking safe harbor in your sector.
- **Capital Sieges:** A hidden playtime clock runs within the beacon. Every 3 to 6 hours, a devastating siege fleet (Pirates, Xsotan, or War Factions) will invade your sector to destroy the beacon. If you defend it, you earn legendary loot. If it falls, your global buffs collapse.
- **Wartime Innovation:** Weapons crafted at the Stellar Forge receive exponential damage multipliers based on how close the forge is to the Galactic Core (+200%) and your current War Heat (+150%). Forging at the core during a massive war yields a 9.0x damage super-weapon!
- **Multiplayer Boss Scaling:** Implemented dynamic `applyPermanentFactor` scaling. Harbingers and Citadels now inherently gain +100% Shield and +50% Damage per additional player in the sector.
- **Vault Fleet Integration:** Siege and Invasion fleets now utilize the `CosmicVaultFleet.orderAttackEnemies()` API to ruthlessly hunt down players rather than idling.
- **Ascendant Bosses:** Eclipse Harbingers utilize the "Living Relic" subsystem mechanics internally, multiplying their shields by 3750% and damage by 500%.
- **The Ascendant Forge Unlock:** The Ascendant Forge is now securely locked behind the completion of the new story campaign.

### 🐛 Bug Fixes & Optimization
- **Multiplayer Network Synchronization:** Fixed a silent networking bug where the Ascendancy Beacon UI buttons (Toggle Beacon, Upgrade Tier) would not respond on Dedicated Servers because the server-side functions were missing `callable()` declarations.
- **Infinite Spawns Prevention:** Replaced `addScript` with `addScriptOnce` in `ascendancybeacon.lua` so the Eclipse Siege script doesn't inject multiple times into the same sector upon reloading, which caused exponential enemy spawns.
- **Galaxy Engine Initialization:** Fixed a critical structural issue where `server.lua` was placed in the wrong directory (`scripts/server/` instead of `scripts/galaxy/`). The Eclipse Awakening events will now correctly hook into newly generated sectors and spawn Eclipse Citadels as originally intended.
- **Keep-Alive Engine:** Built a dedicated background galaxy script (`ascendancykeepalive.lua`) to ensure the server physically holds beacon sectors in memory instead of unloading them.
- **Alliance Buff Injection:** Patched the player synchronization script so that Alliance defense fleets properly inherit the global Ascendant stats when jumping into a sector.
- **Stat Bloat Safety:** Added `onRemove` callback safety nets to prevent players from keeping permanent stat bloat if the beacon is destroyed or the mod is uninstalled.
- **Asynchronous Forge Safety:** Ensured the forge utilizes server-side global playtime to prevent duplication exploits and allow crafting to continue gracefully while players are offline or during server restarts.
- **Subsystem Memory Leak Patch:** Injected `secure()` and `restore()` persistence hooks into the Living Relic subsystems to prevent an infinite stat-stacking exploit and server crash when sectors rapidly load/unload.
- **Performance & TPS Optimization:** Drastically reduced server load during late-game scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s) into the 3 main story missions (`ca_story1_awakening`, `ca_story2_forge`, `ca_story3_vanguard`) to stop them from polling the sector 60 times a second.
- **Deterministic Fixes:** Removed `math.random` from `ascendancysiege.lua`, preventing massive multiplayer desyncs during the Eclipse Vanguard invasions.
