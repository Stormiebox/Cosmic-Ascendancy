# Changelog

All notable changes to **Cosmic Ascendancy** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v1.0.5] - Hotfix

### 🐛 Bug Fix

- [Bugfix] **Flavor Text & Audio Silent Failure:** Fixed a critical cross-script execution failure where the Eclipse Awakening UI banner and audio triggers were silently failing. The bridge functions in the player audio hook were encapsulated inside a namespace table and lacked global wrapper functions, which caused Avorion's `invokeFunction` and `invokeClientFunction` to silently fail when searching the script's global scope.
- [Bugfix] **Eclipse Ghost Broadcasts:** Fixed a bug where the Eclipse Doomsday broadcast would fire from a non-existent faction. The `eclipse_awakes.lua` script now explicitly instructs the engine to fully generate and register the Eclipse faction in the galaxy database at the exact moment the awakening timer hits zero, ensuring complete database stability for manager scripts.

## [v1.0.4] - Hotfix

### 🐛 Bug Fix

- [Bugfix] **Flavor Text & Audio Missing:** Fixed a critical bug where the cinematic banner, music, and warning flavor text failed to display when the Wormhole Guardian was defeated. The global listener was using an invalid engine API (getPlayers()) instead of getOnlinePlayers(), causing the script to crash immediately after detecting the Guardian's death. This resolves the silent failure during the Eclipse awakening sequence.
- [Bugfix] **Missing Dark Fog Logic:** Fixed a bug where jumping into a Dark Sector in the core attempted to load a non-existent weather script. Dark Sectors will now correctly spawn the Dark Matter Fog environmental hazard using the Vault API.
- [Codex] **Dark Matter Fog:** Clarified the Codex entry for Dark Matter Fog. It does not deal passive damage-over-time; it solely imposes harsh debuffs on ship sensors and jump drives.

## [v1.0.3] - Hotfix

### 🐛 Bug Fix

- [Bugfix] **Eclipse Awakening Failure:** Fixed a critical bug where The Eclipse failed to awaken after defeating the Wormhole Guardian. The core event scripts (`eclipse_awakes.lua` and `ca_expansion_manager.lua`) were missing the mandatory `data/scripts/` root path prefix when being attached to the `Galaxy()` singleton. Because the engine couldn't resolve the relative paths, it silently failed to load the scripts, causing the event listeners to never activate. The script initialization paths have been corrected and will retroactively detect the Guardian's death on existing saves.

## [v1.0.2] - Patch

### 🐛 Bug Fix

- [Bugfix] Fixed a critical server/client synchronization "Bridge" crash where server-side scripts (World Eater, Eclipse) were calling client-only UI and Audio functions directly. Implemented bridge functions in `ca_boss_audio_hook.lua` to properly route UI banners and boss music triggers to the client.
- [Bugfix] Fixed an issue in `eclipse_awakes.lua` where the 10-minute awakening timer was tied to `server.unpausedRuntime`, causing it to reset entirely if a dedicated server restarted during the countdown. It now properly persists using script localization parameters.
- [Bugfix] Fixed an issue in `ca_world_eater_manager.lua` where the 3-hour cooldown timer was not being serialized during server shutdowns. The timer will now correctly persist across server restarts, ensuring World Eaters actually spawn.
- [Bugfix] **Eclipse Awakening Trigger:** Refactored the `eclipse_awakes.lua` trigger logic to seamlessly track Guardian kills via global `guardian_respawn_time` without polling players, fixing an edge-case where the event would fail to trigger if the killer disconnected immediately.

### ⚖️ Balancing

- [Balance] **Void Shields (Physical Mitigation):** Reduced from 90% to 80%. This gives Physical weapons (Cannons, Bolters, Chainguns) a slight fighting chance, though Energy/Plasma/Antimatter remain highly recommended.
- [Balance] **Eclipse Citadel HP:** Reduced base HP from 250,000,000 to 200,000,000 to make Citadel sieges slightly less of a slog.
- [Balance] **World Eater Spawn Timer:** Increased the global spawn timer from 2-3 hours to 3-5 hours to make the encounter feel more like a rare galactic event.
- [Balance] **World Eater Doomsday Timer:** Increased the Doomsday Sector Annihilation timer from 15 minutes to 20 minutes, giving players more time to rally a fleet and reach the location.
- [Balance] **Adaptive Armor (Defilers/Artillery):** Reduced the heal-back amount while Adaptive Armor is active from 75% to 50%.
- [Balance] **Endgame Hazard Scaling:** Converted all major Eclipse endgame hazards from flat-damage numbers to percentage-based scaling damage to ensure they remain lethal against ultra-lategame players with Ascendancy Beacons.
- [Balance] **Singularity Implosion:** Converted from 250,000 flat true-damage to stripping 15% of a player's Max Hull.
- [Balance] **World Eater EMP Hazard:** Converted from 1,000,000 flat Energy damage to 25% Max Hull damage (after stripping 100% shields).
- [Balance] **World Eater Breaker Laser:** Converted from 5,000,000 flat Energy damage to a blast that deals 100% of Max Shields + 50% of Max Hull.
- [Balance] **World Eater Gravity Anomaly:** Converted from 50,000 flat Physical DoT to 5% Max Hull per second.
- [Balance] **Eclipse Ambushes:** Reduced the chance for the Eclipse to personally ambush players in their sector every 25-45 minutes from 60% down to 40%.
- [Balance] **Void Siphon Aura (Eclipse Command Ships):** Reduced the massive heal-back conversion from draining players from 100% of damage drained down to 25%. The boss will no longer become an unkillable sponge if you bring a large fleet. Also reduced the aura radius from 15km to 10km to allow for better kiting.
- [Balance] **Dark Matter Blink (All Eclipse Ships):** Increased the cooldown of the emergency teleport from 30 seconds to 45 seconds to reduce frustration when chasing ships with high-DPS builds.
- [Balance] **World-Eater Emergency Repairs:** Reduced the Phase 50% Emergency Repair heal from 10% of Max Hull to 5% of Max Hull.

### ⚙️ Adjustments

- [Changed] **Ambush Timer Persistence:** Converted ambush invasion timers to use absolute real-time stamps (`Server().unpausedRuntime`) rather than tick-based accumulation, preventing desync from server lag.

## [v1.0.1] - Patch

### 🐛 Bug Fix

- [Bugfixed] Fixed an issue where the Rift Hazard anomaly would silently drain non-Eclipse shields without notifying the player. Entering a hazard zone now immediately broadcasts a high-priority UI and chat warning.

## [v1.0.0] - UNRELEASED WORKSHOP VERSION (PROJECT UNDER DEVELOPMENT)

### ✨ New Features & 📦 Content Additions

- [Feature] **The World-Eater Boss Fight Overhaul:** The Eclipse World-Eater has been completely reimagined from a static sponge into a dynamic, multi-phase raid boss. It now features massive mechanics based on its Hull Integrity:
  - **Anchor Pylon Tethers:** Upon spawning, the World-Eater summons 4 Eclipse Juggernauts. Until all 4 are destroyed, the boss remains 100% invincible, visually tethered to them by massive purple lasers.
  - **Quantum EMP Hazards:** Periodically targets a random player with a massive cyan glow. After 3 seconds, an EMP erupts, instantly stripping 100% of their shields and inflicting catastrophic energy damage.
  - **Gravity Anomaly Hazards:** Periodically spawns a dark purple Black Hole at a player's location. This anomaly actively pulls all player ships towards the center using physical constraints, inflicting crushing hull damage over time!
  - **The 6-Phase Gauntlet:**
    - **80% HP:** Summons 5 Defiler Escorts.
    - **70% HP:** Emits a Dark Matter EMP, instantly stripping 50% of the shield capacity from all players in the sector.
    - **60% HP:** Deploys 4 Eclipse Assassin Hunter-Killers (Destroyers).
    - **50% HP:** Blinks randomly to a distant location and initiates emergency repairs, healing up to 10% of its Max Hull.
    - **35% HP:** Blinks again, unleashes a second global EMP, and enters an Enraged state (+50% Fire Rate, +50% Global Damage) until destroyed!
- [Feature] **Raid Summoning:** Jettisoning an **Eclipse Datacore** from your cargo hold into space acts as a quantum beacon. If there are no other Eclipse ships currently in the sector, the datacore will violently collapse, tearing open a hyperspace rift and instantly summoning the **Eclipse World-Eater**!
- [Feature] **Ancient Eclipse Mechanics:** The Eclipse now wield devastating, class-specific mechanics to obliterate fleets:
  - **Dark Matter Blink (All Ships):** Upon taking 15% burst damage within 1 second, the ship will violently blink 5-10km away to escape, leaving behind a Void Rift (cooldown: 30s).
  - **Ethereal Phase-Shift (Interceptors & Phantoms):** Slippery vanguards will instantly phase out of reality for 4 seconds upon shield break, becoming an invincible void-shadow to reposition.
  - **Adaptive Resistance (Defilers & Artillery):** These heavy combatants analyze incoming fire; taking 5% Hull damage from a specific element (e.g., Plasma) triggers a 75% resistance to that element for 15 seconds!
  - **Void Siphon Aura (Carriers, Cruisers, Dreadnoughts, Juggernauts):** Massive command ships constantly project a 3km devouring aura, draining 2% of the shield capacity of all nearby player ships per second to heal themselves.
  - **Singularity Implosion (All Large Capital Ships):** Upon death, these gargantuan reactors collapse. After a 3-second warning, they violently detonate, dealing 50,000 true-damage to everything within 3km!
- [Feature] **The Fallen Empire Awakening:** The Eclipse conquest manager now tracks total territory annihilation. Upon conquering 10 sectors, The Eclipse triggers the 'Fallen Empire' state, redirecting massive Crusade fleets to systematically hunt down and wipe out AI Faction Capitals.
- [Feature] **Endgame Expansion: The Eclipse:** The death of the Xsotan Wormhole Guardian now triggers a galaxy-wide event. After a 10-minute agonizing delay of subspace anomalies, an ancient, ravenous faction known as **The Eclipse** awakens and aggressively hunts players.
- [Feature] **The Ascendancy Beacon Megastructure:** A brand new massive station that permanently keeps its sector loaded (24/7) using a custom Keep-Alive engine. Players can construct it via standard station founding, and upgrade it from Tier 1 to Tier 5 using astronomical amounts of credits and ores.
- [Feature] **Global Ascendant Buffs:** Upgrading your beacon grants a permanent, account-wide stat buff to all ships in your fleet, multiplying Hull, Shields, and Damage.
- [Feature] **The Stellar Forge:** Exchange 1+ Billion Credits and massive ore reserves to asynchronously craft custom God-Tier weapons or Relic Subsystems over 24 real-time hours.
- [Feature] **Ascendant Overdrive:** As a late-game economic sink, players can approach any factory they own and interact with it to feed it 50 Ascendant Matter. This activates "Ascendant Overdrive", tripling (3.0x) the station's production capacity for 1 real-time hour!
- [Feature] **Forge Decryption Matrix:** The Ascendancy Forge now accepts `Eclipse Datacores`. Decrypting them permanently raises your Global Ascendancy Tier, granting +15% Shields, +20% Shield Regen, and +10% Hyperspace Cooldown natively to all player ships.
- [Feature] **Eclipse Citadel Mechanics:**
  - **Lockdown Matrix:** Attached the vanilla `hyperspaceblocker.lua` script to Citadels natively, actively trapping players in the sector until the Citadel is destroyed.
  - **Suppression Field:** Destroying a Citadel now writes a global server timestamp that aggressively halts all new Eclipse invasions galaxy-wide for 6 hours.
- [Feature] **The Grand Toll & Treasury Payouts:** Since the Ascendancy Beacon sector is permanently loaded, the beacon acts as an intergalactic border checkpoint. All NPC traders and AI factions jumping into the sector are charged a massive entry tax that scales with the beacon's tier. To prevent endless notification spam, the Beacon safely stores all collected tolls in its internal treasury and pays out a single lump-sum to your faction every 45 minutes (synced with the Upkeep cycle).
- [Feature] **Dynamic Wartime Premium:** Integrated with `Cosmic War`. AI factions currently engaged in massive wars will desperately pay up to a **+50% Premium Toll** for seeking safe harbor in your heavily defended capital sector!
- [Feature] **Capital Sieges:** A hidden playtime clock runs within the beacon. Every 3 to 6 hours, a devastating siege fleet (Pirates, Xsotan, or War Factions) will invade your sector to destroy the beacon. If you defend it, you earn legendary loot. If it falls, your global buffs collapse.
- [Feature] **Dynamic Faction Expansion:** AI Factions and Pirates will now organically expand their borders and establish new stations in uncharted sectors over time, driven by a highly optimized background simulation.
- [Feature] **Global Map Conquest:** The Eclipse now permanently claims ownership of sectors they annihilate or conquer on the Galaxy Map.
- [Feature] **Adaptive Eclipse Scaling:** The Eclipse dynamically scan the server for the highest Ascendancy Tier player. For every tier achieved, the entire Eclipse faction receives a permanent +50% physical volume and stat multiplier.
- [Feature] **Dead Empire Filter:** The Eclipse Conquest Engine natively utilizes `FactionEradicationUtility` to strictly filter out destroyed empires, preventing crusades from glitching and targeting wiped out factions.
- [Feature] **Eclipse Rift Spillage:** Eclipse Invasions now have a 10% chance to destabilize local space, tearing a massive subspace rift that drains sector shields. You must destroy the Eclipse Rift Stabilizer to close the tear and end the hazard.
- [Feature] **Automated Sector Defense Fleets:** `ca_ascendant_gateway.lua` implemented to allow automated Ascendant defense fleets to spawn at player gateways.
- [Feature] **Cosmic Codex & Deep Wiki Integration:** The mod now fully supports the Cosmic Codex! Comprehensive lore, the Eclipse Crisis storyline, and mechanical documentation for the Ascendancy Forge crafting systems are natively integrated.
- [Feature] **The Galactic Dread News Network:** Integrated with `CosmicVaultNews`. Publishes server-wide breaking news when The Eclipse annihilates a sector, or when players secure a Heroic Victory against an Obliterator or World-Eater.
- [Feature] **Custom OST Integration:** Integrated the "Forge The Ascendant" custom soundtrack to play dynamically exactly 15 seconds after the Wormhole Guardian's defeat.
- [Feature] **Cross-Mod Integration:**
  - **Cosmic Vault:** Utilizes `CosmicVaultBuffs` API for global multiplier injections, and `CosmicVaultNews` to broadcast your empire's ascension, sieges, and falls to the entire galaxy.
  - **Cosmic War:** Deeply integrated with `CosmicWarBridge` to fetch War Heat for dynamic toll scaling, siege attackers, and Forge weapon multipliers.
  - **Cosmic Starfall:** If installed, The Eclipse will randomly utilize its god-tier weaponry alongside their vanilla max-tech arsenal.
  - **Cosmic Overhaul & Chronicles:** Adds lore and weight to the massive empire capital milestones.
- [Feature] **Post-Boss Anomalies:** Upon destroying the Eclipse World-Eater (Oblivion Engine), the game natively invokes `CosmicVaultAnomalies` to spawn a massive, persistent `PrecursorWreck` anomaly for exploration and salvaging.
- [Content] **New Campaign: The Eclipse Awakening:** A massive, epic 3-part storyline that automatically triggers when you interact with the Adventurer or Hermit near the galactic core.
- [Content] **New Artifact: The Eclipse Bane:** A legendary reward for completing the campaign. Grants massive bonuses to Hull, Shields, Turret Slots, Jump Range, and Damage.
- [Content] **The "World-Eater" Doomsday Event:** A new server-wide crisis that triggers every 2-3 hours. A massive 5x scaled Juggernaut warps into a populated player sector, initiating a 15-minute countdown to total atomic annihilation, escorted by a Royal Escort Fleet (2 Carriers, 2 Artillery, 4 Defilers, 8 Interceptors).
- [Content] **The World Eater:** Added an apocalyptic new roaming superboss. It actively hunts populated sectors, obliterates everything, dynamically broadcasts via Galactic News, and rewards the galaxy's defenders with 5 Billion credits and maximum-tier loot! (Also includes a 'Stormbox Protocol' lore Easter Egg).
- [Content] **Geometric Nightmares:** The Eclipse fly massive geometric structures made of black Avorion with glowing red accents: Nullifiers (Pyramids), Obliterators (Monoliths), Harbingers (Obelisks), and 4 massive new specialized classes (Juggernaut, Interceptor, Harvester, Defiler) that utilize dynamically scaled, jagged aesthetics.
- [Content] **Eclipse Strongholds:** Conquered unexplored sectors now have a 25% chance of spawning as fully fortified Eclipse Strongholds.
- [Content] **The "Ascendant Matter" Arms Race:** Introduced `Ascendant Matter` (dropped by Harvesters) and `Eclipse Datacores` (dropped by Juggernauts) as new illegal galactic goods acquired exclusively by destroying Eclipse vessels.
- [Content] **Game-Breaking Arsenal:** The Eclipse utilizes a customized weapon generator that forces Tech 52 (Maximum), boosts all weapon damage, reach, and fire rate significantly, and forces 100% accuracy.
- [Content] **Ascendant Subsystems (Living Relics):** Four game-breaking subsystems (War-Drive, Aegis Matrix, Slipstream Core, Omni-Sensor) that dynamically multiply their power up to 7.5x based on your current Core Proximity and the Empire's War Heat!
- [Content] **New Ascendant Subsystems:**
  - **Ascendant Swarm Nexus:** Massively multiplies your ship's production capacity and grants heavy bonuses to fighter squadrons and pilots.
  - **Ascendant Void-Drill:** Immensely increases Transporter and Loot Collection Range, and multiplies generated energy capacity.
- [Content] **Ascendant Neural Implant:** Added a new craftable ship subsystem that wires the captain directly into the vessel's core. Providing massive boosts to Jump Reach (+15), Velocity (+30%), Armed/Unarmed Turrets (+10), and Fighter Squadrons (+3), simulating a heavily augmented Ascendant Captain.
- [Content] **Ascendant World-Breaker:** Added a massive Titan-Class Coaxial weapon to the Ascendancy Forge. Harnessing the CosmicVaultArsenal framework, this superweapon delivers 250,000 baseline continuous damage to completely vaporize threats.
- [Content] **The Dark Sector:** Added a terrifying new environmental hazard deep within the Galactic Core (Barrier). Jumping into un-generated sectors near the core now carries a 20% risk of dropping you into a permanent Dark Matter Fog field, crawling with heavily guarded Eclipse Citadels and Juggernauts.

### ⚙️ Changed & ⚖️ Balanced

- [Changed] **Eclipse Faction Architecture Overhaul:** ALL Eclipse ships and the Ascendancy Megastructures have been physically upscaled and mathematically upgraded to Avorion (Tier 6) material. The World-Eater now stands at an imposing 5.9 kilometers in length!
- [Changed] **Dark Matter Aura (Constant Pressure):** Upon reaching the final 35% HP Enrage Phase, the boss projects a passive, sector-wide necrotic aura that constantly drains the hull and shields of all non-Eclipse entities at a rate of 0.25% Max HP per second.
- [Changed] **Nemesis Protocol (Adaptive Resistance):** If the boss takes massive damage (5% of its Max HP) from a single damage type within a short window, it engages the Nemesis Protocol, gaining a 90% elemental heal-back resistance to that specific damage type for 60 seconds.
- [Changed] **Upgraded Gravity Anomalies:** Gravity Anomalies now severely dampen engine velocity (rather than infinitely stacking permanent stat biases) in addition to massive physical pull forces and physical damage.
- [Changed] **The World-Breaker Laser:** The boss now periodically locks onto a random player with a massive tracking beam. After 5 seconds, if the player is still within 20km, it detonates for 5,000,000 energy damage.
- [Changed] **Dynamic Tether Resurgence:** At 50% HP (Emergency Repairs) and 25% HP (Final Stand), the boss will forcibly warp in 2 additional Anchor Pylons (Juggernauts). Until these new tethers are destroyed, the boss regains total invulnerability.
- [Changed] **Vault Fleet Integration:** Siege and Invasion fleets now utilize the `CosmicVaultFleet.orderAttackEnemies()` API to ruthlessly hunt down players rather than idling.
- [Changed] **Ascendant Scrap Utility & Forge Sacrifice Overhaul:** Rebuilt the `ascendancyforge.lua` UI to mimic the Vanilla Research Station. You must drag and drop Legendary (+20% success) or Exotic (+10% success) subsystems to guarantee your craft. Failures immediately destroy materials but reward you with new `Ascendant Scrap`. You can consume Ascendant Scrap to fuel the forge when you do not meet the 100% success rate (1x Scrap = +2% Success Rate).
- [Changed] **The Ascendant Forge Unlock:** The Ascendant Forge is now securely locked behind the completion of the new story campaign.
- [Changed] **Core Dependencies:** Removed `pcall` soft-dependencies. Core 5 mods are now hard requirements.
- [Balanced] **Singularity Collapse (Black Hole):** When a Singularity Core dies (Carriers, Dreadnoughts, Harbingers), the blast radius is increased from 3km to 15km. During the 3-second windup, the collapsing core acts as a Gravity Well, physically pulling all non-Eclipse ships inward. The subsequent detonation deals 250,000 true damage to all ships and stations caught in the blast.
- [Balanced] **Void Siphons:** Siphon auras (Void-Weavers, Juggernauts, etc.) have had their radius drastically increased from 3km to 15km. If a target is unshielded, the aura will now forcefully drain their Hull (Durability) to repair the Eclipse ship.
- [Balanced] **Adaptive Memory Decay:** Adaptive armor (Defilers, Artillery) will now decay its elemental memory if it hasn't been hit by that specific element within 3 seconds, preventing a permanent lockout from stray shots.
- [Balanced] **Ethereal Phase Regeneration:** When Ethereal ships (Phantoms, Interceptors) lose their shields and trigger Phase Shift, they now passively regenerate 25% of their Max Shields over the 4-second invincibility window.
- [Balanced] **Wartime Innovation:** Weapons crafted at the Stellar Forge receive exponential damage multipliers based on how close the forge is to the Galactic Core (+200%) and your current War Heat (+150%). Forging at the core during a massive war yields a 9.0x damage super-weapon!
- [Balanced] **War Heat Integrity:** Added a hardcap of 10.0x for the War Heat bonus (if Cosmic War is installed) to prevent damage values from causing infinite integer overflow.
- [Balanced] **Ascendancy Beacon Economy:** Smoothed out the upgrade costs and correctly aligned the material requirements to the natural progression curve (Naonite -> Trinium -> Xanion -> Avorion).
- [Balanced] **Ascendancy Forge Economy:** Rebalanced the forge costs from an impossible 15 Billion Credits / 90 Million Avorion down to a steep but achievable 300 Million Credits / 3 Million Avorion per weapon. Ascendant Matter requirements were also rebalanced so a single World Eater kill funds 3 to 5 Ascendant weapon forges. God-Tier weapons now explicitly require `Ascendant Matter` to forge.
- [Balanced] **Galactic Turn Synchronization:** `expansionInterval` slowed from 30m to 20m to align with the global server turn. `expansionChance` gracefully reduced from 35% to 25% to keep the overall hourly expansion rate mathematically identical.
- [Balanced] **Eclipse Superiority:** All Eclipse entities are now natively immune to Cosmic Overhaul Subspace Weather effects (Ion Storms, Solar Flares).
- [Balanced] **Endgame Crisis Consistency:** The Eclipse Boss now receives a staggering baseline **25x Shield Multiplier** and **3x Damage Multiplier**, far surpassing the standard 10x shield of War Dreadnoughts, guaranteeing The Eclipse remains a terrifying endgame threat.
- [Balanced] **Multiplayer Boss Scaling:** Implemented dynamic `applyPermanentFactor` scaling. Harbingers and Citadels now inherently gain +100% Shield and +50% Damage per additional player in the sector.
- [Balanced] **Eclipse Boss Rebalancing:** The World-Eater is now completely exempt from the massive +2,500% shield multipliers granted to lesser Eclipse bosses, forcing it to rely exclusively on its colossal 125x Hull mass. Capped Eclipse Boss volume/HP scaling at 3.0x maximum to prevent physics engine crashes.
- [Balanced] **Eclipse World-Eater Hull Scaling:** The World-Eater's physical volume has been scaled natively by 5.0 (yielding a 125x Hull HP boost inherently via Avorion engine physics) ensuring it acts as a true sponge!

### 🐛 Bug Fixes & 🛠️ Optimization

- [Bugfixed] **World-Eater Physics Crash:** Prevented a hard server crash in the gravity anomaly logic by replacing an invalid `vel:addVelocity` call with proper vector addition (`vel.velocity = vel.velocity + ...`).
- [Bugfixed] **Permanent Cripple Exploit:** Prevented the World-Eater's black hole from infinitely stacking permanent debuffs on player ships via `addMultiplyableBias`. It now applies a safe, temporary physical dampener.
- [Bugfixed] **Codex Crash Protection:** Hardened all Ascendancy Codex entries to prevent UI crashes if a registered `[Category]` goes missing.
- [Optimized] **Performance & TPS Optimization:** Drastically reduced server load during late-game scenarios. Injected a hardcoded `getUpdateInterval` throttle (1.0s) into the 3 main story missions (`ca_story1_awakening`, `ca_story2_forge`, `ca_story3_vanguard`) to stop them from polling the sector 60 times a second.
- [Optimized] **Callback Optimization:** Cleaned up redundant script initializations and unregistered invalid `onUpdateServer` and `onEntityDestroyed` callbacks that the engine would trip over.
- [Optimized] **Keep-Alive Engine:** Built a dedicated background galaxy script (`ascendancykeepalive.lua`) to ensure the server physically holds beacon sectors in memory instead of unloading them.
- [Bugfixed] **Multiplayer RNG Synchronization:** Removed `math.random` in procedural generation loops (`ca_eclipse_abilities.lua`, `ca_expansion_manager.lua`) and from `ascendancysiege.lua`, replacing them with deterministic `random()` to prevent massive multiplayer desyncs during the Eclipse Vanguard invasions.
- [Bugfixed] **Subsystem Memory Leak Patch:** Replaced manual `removeBonus` tracking in Living Relic subsystems (`ascendantaegis.lua`, `ascendantomnisensor.lua`, `ascendantslipstream.lua`) with native `Entity():removeScriptBonuses()` to prevent an infinite stat-stacking exploit upon server restart. Added `onRemove` callback safety nets to prevent players from keeping permanent stat bloat if the beacon is destroyed or the mod is uninstalled.
- [Bugfixed] **Alliance Forge Desync Fixed:** Completely refactored the Forge's interaction logic to correctly grab items and resources from the exact entity utilizing the UI (eliminating a massive Alliance inventory desync bug). Fixed `ascendancyforge.lua` Alliance lockout bug where Alliance-owned forges would permanently reject Datacore submissions.
- [Bugfixed] **Engine API Crash Fixes:** Resolved an engine-level crash related to vanilla `Sector:dropCargo` failing to parse missing good identifiers. Fixed a severe engine-level bug involving `inflictDamage` signatures being passed `Uuid`s instead of integers. Fixed Velocity logic causing engine lag/crashes by directly writing incorrect `vec3`s to the Velocity component instead of scaling it gracefully.
- [Bugfixed] **Nemesis Resistances Native Overhaul:** Restructured `ca_nemesis_resist.lua` to calculate its 90% elemental damage reduction dynamically inside the `onDamaged` loop, instead of relying on non-existent `StatsBonuses.*DamageReceived` API enums.
- [Bugfixed] **Eclipse Boss Damage Gate:** Hardened the 8% damage gate inside `ca_nemesis_system.lua` to properly check if shields are active. If a god-tier weapon bypasses the gate, the script seamlessly restores the correct health pool (shields or hull) to prevent one-shots.
- [Bugfixed] **Station Foundation Behavior:** Previously, the Codex hallucinated that the Ascendancy Beacon automatically generated its structure when founded by a player. The logic has been completely separated: the towering `Ascendancy_beacon.xml` is strictly generated as an ancient wreck during the main story quest, and players founding their own Ascendancy Beacons will correctly enter Build Mode to use their own ship/station designs as intended by vanilla mechanics.
- [Bugfixed] **Initialization Bypass:** Fixed severe bug in `init.lua` where the Ascendancy Codex failed to initialize and inject its UI tabs on fresh server boots.
- [Bugfixed] **Galaxy Engine Initialization:** Fixed a critical structural issue where `server.lua` was placed in the wrong directory (`scripts/server/` instead of `scripts/galaxy/`). The Eclipse Awakening events will now correctly hook into newly generated sectors and spawn Eclipse Citadels as originally intended. Fixed global crash in `server.lua` where `Sector()` was called during galaxy generation `onSectorGenerated`. Replaced with global marking, and shifted physical spawning of Strongholds to player `onSectorEntered` mechanics.
- [Bugfixed] **Conquest Injection Target:** Fixed a fatal dedicated server crash triggered when the Eclipse Conquest Manager attempted to inject siege events from the Galaxy VM. Siege injection is now safely delegated to player VMs in the target sector.
- [Bugfixed] **Sector Calling Context:** Fixed `eclipse_conquest_manager.lua` attempted to call `Sector()` from a Galaxy script context during Annihilation. Offloaded sector wipes to a player script instance to safely execute. Wrapped `Sector()` calls in `eclipsegenerator.lua` inside safe `pcall` fallbacks.
- [Bugfixed] **Invalid StatsBonuses Wipe:** Scrubbed all invalid API enums (like `StatsBonuses.Damage`, `StatsBonuses.ShieldCapacity`, `StatsBonuses.CargoCapacity`) from all generator scripts (`eclipsegenerator.lua`, `spawneclipseboss.lua`, etc). Bosses (like Eclipse Harbingers) will now correctly receive their intended 500% damage boosts and 3750% shields natively using the "Living Relic" subsystem mechanics! Fixed Ascendant Gateways erroneously spawning Ascendant Guardians with `StatsBonuses.ArmedTurrets` instead of damage multipliers.
- [Bugfixed] **Inventory Context API:** Fixed `ca_story2_forge.lua` used raw inventory lookups for Avorion, which failed. Switched to native `player:pay()` API.
- [Bugfixed] **Forge UI Sync:** Fixed `ascendancyforge.lua` UI sync function containing a merged syntax error.
- [Bugfixed] **Math Logic Spawning Bug:** Swept the codebase and replaced critical logic faults where probability checks were evaluating against `getInt()` instead of `getFloat()`, restoring exact percentage math for Eclipse Stronghold generation and Superboss hunts.
- [Bugfixed] **Multiplayer UI Sync:** Fixed a silent networking bug where the Ascendancy Beacon UI buttons (Toggle Beacon, Upgrade Tier) would not respond on Dedicated Servers because the server-side functions were missing `callable()` declarations.
- [Bugfixed] **Infinite Spawns Prevention:** Replaced `addScript` with `addScriptOnce` in `ascendancybeacon.lua` so the Eclipse Siege script doesn't inject multiple times into the same sector upon reloading, which caused exponential enemy spawns.
- [Bugfixed] **Alliance Buff Injection:** Patched the player synchronization script so that Alliance defense fleets properly inherit the global Ascendant stats when jumping into a sector.
- [Bugfixed] **Asynchronous Forge Safety:** Ensured the forge utilizes server-side global playtime to prevent duplication exploits and allow crafting to continue gracefully while players are offline or during server restarts.
- [Bugfixed] **Boss Loot Drops:** Fixed severe API call crash (`dropPort`, `generateWeapon`) in `ca_citadel_loot.lua` that prevented the Citadel from dropping its legendary loot when destroyed. Fixed an exploitable bug where the `World Eater` roaming boss dropped permanently artificially buffed weapons (3x damage, 2x range) directly as raw loot, bypassing the Ascendancy Forge economy entirely.

- [Bugfixed] **VFS Compliance:** Stripped redundant global wrapper functions from namespaced scripts to prevent silent double-execution logic loops and engine crashes.


