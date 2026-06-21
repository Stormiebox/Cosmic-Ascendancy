# Changelog

All notable changes to **Cosmic Ascendancy** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v1.0.0] - UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)

### 🚀 Major Expansion Features
- **Ancient Eclipse Mechanics:** The Eclipse now wield devastating, class-specific mechanics to obliterate fleets:
  - **Dark Matter Blink (All Ships):** Upon taking 15% burst damage within 1 second, the ship will violently blink 5-10km away to escape, leaving behind a Void Rift (cooldown: 30s).
  - **Ethereal Phase-Shift (Interceptors & Phantoms):** Slippery vanguards will instantly phase out of reality for 4 seconds upon shield break, becoming an invincible void-shadow to reposition.
  - **Adaptive Resistance (Defilers & Artillery):** These heavy combatants analyze incoming fire; taking 5% Hull damage from a specific element (e.g., Plasma) triggers a 75% resistance to that element for 15 seconds!
  - **Void Siphon Aura (Carriers, Cruisers, Dreadnoughts, Juggernauts):** Massive command ships constantly project a 3km devouring aura, draining 2% of the shield capacity of all nearby player ships per second to heal themselves.
  - **Singularity Implosion (All Large Capital Ships):** Upon death, these gargantuan reactors collapse. After a 3-second warning, they violently detonate, dealing 50,000 true-damage to everything within 3km!
- **The Eclipse World-Eater MMO Boss Fight:** The Eclipse World-Eater has been completely reimagined from a static sponge into a dynamic, multi-phase encounter. It now features 6 distinct mechanic phases based on its Hull Integrity:
  - **80% HP:** Summons 5 Defiler Escorts.
  - **70% HP:** Emits a Dark Matter EMP, instantly stripping 50% of the shield capacity from all players in the sector.
  - **60% HP:** Deploys 4 Eclipse Destroyers.
  - **50% HP:** Blinks randomly to a distant location and initiates emergency repairs, healing up to 10% of its Max Hull.
  - **35% HP:** Blinks again, unleashes a second EMP, and enters an Enraged state (+50% Fire Rate, +50% Global Damage) until destroyed!
- **Ascendancy Beacon Treasury System:** The massive Ascendancy Beacon tolls are now securely routed into a localized `AscendancyBeacon.treasury`. Instead of spamming your UI feed every time an AI freighter enters the sector, the Beacon now pays out the entire accumulated war-tax directly to your faction in a single, clean lump-sum every 45 minutes on the Upkeep billing cycle.
- **Eclipse Boss Rebalancing:** The World-Eater is now completely exempt from the massive +2,500% shield multipliers granted to lesser Eclipse bosses, forcing it to rely exclusively on its colossal 125x Hull mass.

- **The Fallen Empire Awakening**: The Eclipse conquest manager now tracks total territory annihilation. Upon conquering 10 sectors, The Eclipse triggers the 'Fallen Empire' state.
- **Systematic Crusades**: Once awakened, the Eclipse algorithmic intelligence stops targeting random player borders and redirects massive Crusade fleets to systematically hunt down and wipe out AI Faction Capitals.
- **Eclipse Superiority**: All Eclipse entities are now natively immune to Cosmic Overhaul Subspace Weather effects (Ion Storms, Solar Flares).
- **The Ascendancy Beacon:** A brand new massive station that permanently keeps its sector loaded (24/7). Players can upgrade this beacon from Tier 1 to Tier 5 using astronomical amounts of credits and ores.
- **Global Ascendant Buffs:** Upgrading your beacon grants a permanent, account-wide stat buff to all ships in your fleet, multiplying Hull, Shields, and Damage.
- **The Stellar Forge:** Exchange 1+ Billion Credits and massive ore reserves to asynchronously craft custom God-Tier weapons or Relic Subsystems over 24 real-time hours.
- **Endgame Expansion: The Eclipse:** The death of the Xsotan Wormhole Guardian now triggers a galaxy-wide event. After a 10-minute agonizing delay of subspace anomalies, an ancient, ravenous faction known as **The Eclipse** awakens and aggressively hunts players.
- **Cosmic Codex Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore and mechanical documentation (such as features, UI tools, and dynamic events) are now readable directly in-game from the new Cosmic Codex tab.

### ✨ Added
- **Dynamic Faction Expansion:** AI Factions and Pirates will now organically expand their borders and establish new stations in uncharted sectors over time, driven by a highly optimized background simulation.
- **The Galactic Dread News Network**: Integrated with `CosmicVaultNews`. Publishes server-wide breaking news when The Eclipse annihilates a sector, or when players secure a Heroic Victory against an Obliterator or World-Eater.
- **The "Ascendant Matter" Arms Race**: Introduced `Ascendant Matter` (dropped by Harvesters) and `Eclipse Datacores` (dropped by Juggernauts) as new illegal galactic goods.
- `ca_nemesis_system.lua` and `ca_nemesis_resist.lua` implemented for Eclipse Dread-Lords.
- `ca_ascendant_gateway.lua` implemented to allow automated sector defense fleets.
- **Passive Real-Estate Income:** Beacons automatically tax all passing AI-controlled freighters. This passive income is dynamically scaled by the **War Heat** of the passing faction (factions actively at war will pay a 50% premium for safe passage through your heavily defended capital!).
- **Treasury Payouts:** To prevent endless notification spam from freighters constantly passing through your capital, the Beacon safely stores all collected tolls in its internal treasury and pays out a single lump-sum to your faction every 45 minutes (synced with the Upkeep cycle).
- **Adaptive Eclipse Scaling**: The Eclipse dynamically scan the server for the highest Ascendancy Tier player. For every tier achieved, the entire Eclipse faction receives a permanent +50% physical volume and stat multiplier.
- **The "World-Eater" Doomsday Event**: A new server-wide crisis that triggers every 2-3 hours. A massive 5x scaled Juggernaut warps into a populated player sector, initiating a 15-minute countdown to total atomic annihilation.
- **Global Map Conquest**: The Eclipse now permanently claims ownership of sectors they annihilate or conquer on the Galaxy Map.
- **Codex Expansions:** Detailed the exact global buffs and simulation capabilities of the Ascendancy Beacon.
- **Deep Wiki Integration:** The entire lore structure for the Eclipse Crisis and the Ascendancy Forge crafting systems have been natively integrated into the Cosmic Codex.
- **New Campaign: The Eclipse Awakening:** A massive, epic 3-part storyline that automatically triggers when you interact with the Adventurer or Hermit near the galactic core.
- **New Artifact: The Eclipse Bane:** A legendary reward for completing the campaign. Grants massive bonuses to Hull, Shields, Turret Slots, Jump Range, and Damage.
- **Eclipse Generators:** Constructed to automatically spawn brutal endgame boss encounters via automated scripts.
- **The World-Eater Raid Boss:** An apocalyptic Juggernaut that spawns dynamic escorts, fires EMP pulses, blinks across the sector, and enrages across 6 distinct mechanical phases as its massive hull is shredded.
- **Eclipse Strongholds:** Conquered unexplored sectors now have a 25% chance of spawning as fully fortified Eclipse Strongholds.
- **Geometric Nightmares:** The Eclipse fly massive geometric structures made of black Avorion with glowing red accents: Nullifiers (Pyramids), Obliterators (Monoliths), Harbingers (Obelisks), and 4 massive new specialized classes (Juggernaut, Interceptor, Harvester, Defiler) that utilize dynamically scaled, jagged aesthetics.
- **Ascendancy Beacon Megastructures:** Players founding an Ascendancy Beacon will now instantly automatically deploy a massive, customized megastructure `.xml` design instead of a procedural vanilla station.
- **Game-Breaking Arsenal:** The Eclipse utilizes a customized weapon generator that forces Tech 52 (Maximum), boosts all weapon damage, reach, and fire rate significantly, and forces 100% accuracy.
- **The Eclipse Oblivion Engine:** Added an apocalyptic new roaming superboss. It actively hunts populated sectors, obliterates everything, dynamically broadcasts via Galactic News, and rewards the galaxy's defenders with 5 Billion credits and maximum-tier loot! (Also includes a 'Stormbox Protocol' lore Easter Egg).
- **Eclipse World-Eater Royal Escort**: The World-Eater doomsday event now spawns with a massive Royal Escort Fleet (2 Carriers, 2 Artillery, 4 Defilers, 8 Interceptors) to protect it from player swarms.
- **Eclipse World-Eater Hull Scaling**: The World-Eater's physical volume has been scaled natively by 5.0 (yielding a 125x Hull HP boost inherently via Avorion engine physics) ensuring it acts as a true sponge!
- **Ascendant Subsystems (Living Relics):** Four game-breaking subsystems (War-Drive, Aegis Matrix, Slipstream Core, Omni-Sensor) that dynamically multiply their power up to 7.5x based on your current Core Proximity and the Empire's War Heat!
- **Cross-Mod Integration:**
  - **Cosmic Vault:** Utilizes `CosmicVaultBuffs` API for global multiplier injections, and `CosmicVaultNews` to broadcast your empire's ascension, sieges, and falls to the entire galaxy.
  - **Cosmic War:** Deeply integrated with `CosmicWarBridge` to fetch War Heat for dynamic toll scaling, siege attackers, and Forge weapon multipliers.
  - **Cosmic Starfall:** If installed, The Eclipse will randomly utilize its god-tier weaponry alongside their vanilla max-tech arsenal.
  - **Cosmic Overhaul & Chronicles:** Adds lore and weight to the massive empire capital milestones.

### ⚙️ Changed & Balanced
- Capped Eclipse Boss volume/HP scaling at 3.0x maximum to prevent physics engine crashes.
- Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements.
- **Forge Decryption Matrix**: The Ascendancy Forge now accepts `Eclipse Datacores`. Decrypting them permanently raises your Global Ascendancy Tier, granting +15% Shields, +20% Shield Regen, and +10% Hyperspace Cooldown natively to all player ships.
- **Forge Crafting Costs**: God-Tier weapons now require `Ascendant Matter` to forge.
- **The Grand Toll:** Since the sector is permanently loaded, the beacon acts as an intergalactic border checkpoint. All NPC traders and AI factions jumping into the sector are charged a massive entry tax that scales with the beacon's tier.
- **Dynamic Wartime Premium:** Integrated with `Cosmic War`. AI factions currently engaged in massive wars will desperately pay up to a **+50% Premium Toll** for seeking safe harbor in your sector.
- **Capital Sieges:** A hidden playtime clock runs within the beacon. Every 3 to 6 hours, a devastating siege fleet (Pirates, Xsotan, or War Factions) will invade your sector to destroy the beacon. If you defend it, you earn legendary loot. If it falls, your global buffs collapse.
- **Wartime Innovation:** Weapons crafted at the Stellar Forge receive exponential damage multipliers based on how close the forge is to the Galactic Core (+200%) and your current War Heat (+150%). Forging at the core during a massive war yields a 9.0x damage super-weapon!
- **Multiplayer Boss Scaling:** Implemented dynamic `applyPermanentFactor` scaling. Harbingers and Citadels now inherently gain +100% Shield and +50% Damage per additional player in the sector.
- **Eclipse Boss Damage Gate**: Implemented an 8% damage gate to Eclipse Dread-Lords in `ca_nemesis_resist.lua` to prevent players from instantly bursting them down with 9.0x super-weapons.
- **Nemesis Resistances Native Overhaul**: Restructured `ca_nemesis_resist.lua` to calculate its 90% elemental damage reduction dynamically inside the `onDamaged` loop, instead of relying on non-existent `StatsBonuses.*DamageReceived` API enums.
- **Vault Fleet Integration:** Siege and Invasion fleets now utilize the `CosmicVaultFleet.orderAttackEnemies()` API to ruthlessly hunt down players rather than idling.

### ⚖️ Balance
- **Galactic Turn Synchronization:** `expansionInterval` slowed from 30m to 20m to align with the global server turn. `expansionChance` gracefully reduced from 35% to 25% to keep the overall hourly expansion rate mathematically identical.
- **Endgame Crisis Consistency:** The Eclipse Boss now receives a staggering baseline **25x Shield Multiplier** and **3x Damage Multiplier**, far surpassing the standard 10x shield of War Dreadnoughts, guaranteeing The Eclipse remains a terrifying endgame threat.

### 🐛 Bug Fixes & Optimization

- **Fixed**: Fixed a fatal dedicated server crash triggered when the Eclipse Conquest Manager attempted to inject siege events from the Galaxy VM. Siege injection is now safely delegated to player VMs in the target sector.
- **Fixed:** `ascendantaegis.lua` continuously stacked global `addMultiplier` shields infinitely every 15 seconds. Replaced with safe, non-stacking `addMultiplyableFactor` implementations.
- **Fixed:** `ca_story2_forge.lua` used raw inventory lookups for Avorion, which failed. Switched to native `player:pay()` API.
- **Fixed:** `ascendancyforge.lua` UI sync function contained a merged syntax error.
- **Fixed:** Global crash in `server.lua` where `Sector()` was called during galaxy generation `onSectorGenerated`. Replaced with global marking, and shifted physical spawning of Strongholds to player `onSectorEntered` mechanics.
- **Fixed:** `eclipse_conquest_manager.lua` attempted to call `Sector()` from a Galaxy script context during Annihilation. Offloaded sector wipes to a player script instance to safely execute.
- **Fixed:** `eclipsegenerator.lua` attempted to call `Sector()` when spawning blueprints globally. Wrapped all `Sector()` coordinate fetches in safe `pcall` fallbacks.
- **Invalid StatsBonuses Wipe**: Scrubbed all invalid API enums (like `StatsBonuses.Damage`, `StatsBonuses.ShieldCapacity`, `StatsBonuses.CargoCapacity`) from `eclipsegenerator.lua`, `spawneclipseboss.lua`, `ca_ascendant_gateway.lua`, `eclipse_boss_scaling.lua`, `ca_ascendancy_ship_buff.lua`, and `ascendanteclipsebane.lua`. Bosses will now correctly receive their intended 500% damage boosts (by mathematically looping over the 6 native elemental types) and 3750% shields natively!
- **Ascendant Bosses:** Eclipse Harbingers utilize the "Living Relic" subsystem mechanics internally, multiplying their shields by 3750% and damage by 500%.
- **The Ascendant Forge Unlock:** The Ascendant Forge is now securely locked behind the completion of the new story campaign.
- **Fixed**: Removed `math.random` in procedural generation loops (`ca_eclipse_abilities.lua`, `ca_expansion_manager.lua`) and replaced them with deterministic `random()` to prevent multiplayer desyncs.
- **Initialization Bypass:** Fixed severe bug in `init.lua` where the Ascendancy Codex failed to initialize and inject its UI tabs on fresh server boots.
- **Math Logic Spawning Bug:** Swept the codebase and replaced critical logic faults where probability checks were evaluating against `getInt()` instead of `getFloat()`, restoring exact percentage math for Eclipse Stronghold generation and Superboss hunts.
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
