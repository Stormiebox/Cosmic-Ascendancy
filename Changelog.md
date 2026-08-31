# Changelog

All notable changes to **Cosmic Ascendancy** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Never remove, overwrite or write above this

## [v1.5.2]

### 🪲 Bug Fixes
- [Bugfix] **Eclipse Awakening Trigger (Envoy Softlock):** Fixed the root cause of a reported progression softlock where killing the Wormhole Guardian, receiving the galaxy-wide "Eclipse Awakens" broadcast, and even completing the vanilla "Kill the Guardian" mission would still leave a player with no Envoy spawn and no "A Mysterious Summons" quest. Vanilla's `WormholeGuardian.onDestroyed()` (`data/scripts/entity/story/wormholeguardian.lua`) only sets `wormhole_guardian_destroyed` on players physically present in `Sector():getPlayers()` at the exact destruction tick, while the vanilla mission itself completes via a much looser `Sector():getEntitiesByScript()` poll — a player who lands the killing blow and warps out the same tick, or is finished off by residual/DOT damage after leaving, could pass the vanilla quest without ever receiving the flag CA's Eclipse system polls for. `eclipse_awakes.lua`'s `EclipseAwakes.updateServer()` now also checks the unconditional, galaxy-wide `guardian_respawn_time` value (set the instant the Guardian dies, regardless of who's present) as a reliable fallback trigger — this is the fix a prior changelog entry already claimed had shipped, but the polling-only logic had regressed back into the live file.
- [Bugfix] **Ascendancy Beacon Restart Recovery:** Fixed `ascendancykeepalive.lua`'s "force reload active beacons on server restart" logic, which ran entirely inside `initialize()` — a function the engine always calls *before* `restore()`, even when loading a save. The recovery loop was therefore always iterating an empty, not-yet-restored table and never actually re-simulating previously active Ascendancy Beacon sectors after a server restart. The recovery pass now runs in `restore()`, after `data.activeBeacons` is actually populated.
- [Bugfix] **World-Eater Hazard State Loss:** `ca_worldeater_behavior.lua`'s in-flight Quantum EMP and Gravity Anomaly telegraphs (`activeGlows` / `activeAnomalies`) were tracked in plain local tables instead of the script's persisted `data` table, so a server save/reload mid-fight silently dropped any pending hazard. Both are now part of `data`, with a migration guard in `restore()` for saves made before this fix.
- [Bugfix] **Boss Audio Hook Namespace:** `ca_boss_audio_hook.lua` declared `-- namespace CaBossAudioHook` but assigned the table with `local`, unlike every other namespaced script in the mod — breaking the engine's automatic lifecycle binding for that script. Currently harmless since its `initialize()` does nothing, but corrected to a global assignment to match the rest of the codebase and prevent a silent trap for future changes.
- [Bugfix] **Defensive `restore()` Guards:** Added missing `data == nil` guards to the `restore()` functions in `ca_nemesis_resist.lua`, `ca_nemesis_system.lua`, `ca_station_overdrive.lua`, `ascendancybeacon.lua`, and `ascendancyforge.lua`, matching the defensive pattern already used everywhere else in the codebase.
- [Bugfix] **Forge Codex Documentation:** Corrected the in-game Codex entry for the Ascendancy Forge, which described unlocking it with a nonexistent "Guardian Core" item. It now correctly documents the actual mechanic — decrypting an Eclipse Datacore via the Forge's "Decrypt Eclipse Datacore" option.
- [Bugfix] **Aegis Dialogue RPC Forwarding (Campaign-Wide Softlock):** Fixed the deeper cause behind players being unable to progress the Aegis storyline at all, even after the Envoy spawn fix above. None of `ca_ascendant_envoy.lua`'s six dialog `onEnd` handlers (`onAcceptIntro`, `onAcceptStory1` through `onAcceptStory5`) forwarded from client to server (`if onClient() then invokeServerFunction(...) end`), the mandatory pattern used by every equivalent vanilla dialog handler (e.g. `Adventurer1.givePlayerGoodie` in `adventurer1.lua`). Since `ScriptUI():interactShowDialog()` only exists client-side, every `onEnd` callback fired on the client first, so their entire `if onServer() then ... end` bodies were unreachable — clicking through any Aegis conversation granted no mission, cleared no debrief flag, and gave no reward. All six handlers now forward to the server correctly and use `Player(callingPlayer)` instead of a bare `Player()` call, matching the verified vanilla convention for this exact RPC pattern. Also wired up the previously-unused `data.given` anti-replay table so these RPCs can no longer be called directly and repeatedly to farm credits, turrets, and system upgrades.
- [Bugfix] **World-Eater Boss Initialization:** `ca_worldeater_behavior.lua`'s `CAWorldEater.initialize()` called the client-only `registerBoss()` function as the first statement inside its server branch. Since client-only engine calls throw and abort the remainder of the calling block, this silently prevented the World-Eater's invincibility, its anchor-pylon tether spawn, and both its `onDestroyed`/`onDamaged` callback registrations from ever running — meaning the boss dropped no loot on death and never engaged its Nemesis Protocol. `registerBoss()` now runs in the client branch where it belongs.
- [Bugfix] **Elemental Damage Type Misread (4 Files):** `ca_eclipse_abilities.lua`, `ca_nemesis_resist.lua`, `ca_nemesis_system.lua`, and `ca_worldeater_behavior.lua` all declared their `onDamaged` callback with a 4-parameter signature (`objectIndex, amount, inflictor, damageType`), one parameter short of the engine's real 5-parameter signature (`objectIndex, amount, inflictor, damageSource, damageType`). Every one of these scripts was reading the engine's `damageSource` value into what it treated as `damageType`, silently breaking every hull-damage adaptive/elemental resistance mechanic in the mod (Adaptive Armor, the Nemesis Protocol, elemental resist adaptation). All four now declare the correct 5-parameter signature.
- [Bugfix] **Singularity Detonation Never Detaches:** `ca_singularity_detonation.lua` called `sector:removeScript("ca_singularity_detonation.lua")` to clean itself up, dropping the `sector/` subfolder required by this mod's own script-path convention. The mismatched path meant the script was never actually detached, so its detonation-phase AoE blast (15% max durability to every non-allied ship/station in range) would have kept re-firing every 0.2 seconds indefinitely instead of firing once.
- [Bugfix] **Ascendancy Beacon War Heat Crash:** `ascendancybeacon.lua` treated the return value of `Sector():getPresentFactions()` (raw faction indices) as `Faction` objects directly, which would crash beacon activation via `f.isAIFaction` whenever the Cosmic War bridge's `addWarHeat` hook is present. Now correctly wraps each index in `Faction(index)` first.
- [Bugfix] **Dead "Living Relic" Mechanics:** `ascendantomnisensor.lua` and `ascendantslipstream.lua` both registered their `onSectorEntered` hook on `Entity()` (the engine's 3-argument entity-side signature: `entityId, x, y`) while their handlers were written for the 4-argument player-side signature (`playerIndex, x, y, sectorChangeType`). This meant the Omni-Sensor's Deep Scan report never fired (`Player(entityId)` resolved to nothing) and the Slipstream Core's post-jump velocity buff was completely unreachable (`sectorChangeType` was always nil). Both now correctly register on `Player()`.
- [Bugfix] **World-Eater Final Tether Phase:** `CAWorldEater.checkPhases()`'s processing early-out didn't include the 25%-HP "tethers25" phase in its completion check, and since that phase's threshold is always crossed after the 35%-HP phase's, the earlier phase would flip the early-out on before tethers25 could ever fire in a normal, gradually-declining fight. The check now also requires `tethers25`.
- [Bugfix] **World-Eater Wreckage Position:** `spawneclipseboss.lua`'s post-fight cleanup called `SectorGenerator:createWreckage()` without its `position` argument, so AI-owned ships/stations wiped when the boss despawned with no players present spawned their wreckage at a random point in the sector instead of where the entity actually was.
- [Bugfix] **The Eclipse Bane Reward Item:** `ascendanteclipsebane.lua` (the unique reward for defeating the Vanguard boss in story mission 3) gated its entire `onInstalled()` behind `if not permanent then return end` — but a looted inventory item is always installed non-permanently, so it granted none of its advertised +50% Shields/Hull, +5 turret slots, +5 jump range, or +25% damage. The gate has been removed; bonuses now apply on install as intended.
- [Bugfix] **Corrupted Databank Stash Duplicate Loot & Crash:** `ca_anomaly_stash.lua`'s `onOpenPressed()` had no idempotency guard before granting rewards, unlike every other single-use RPC-triggered loot script in the project (e.g. `CosmicChroniclesBlackBox.extract()`'s `extracted` flag) — a duplicate/spammed `invokeServerFunction` call could grant the dropped resources, turret, and upgrade more than once before the entity's deletion landed. Separately, the file's 10% "Anomaly Resurgence" branch called `SectorGenerator(x, y)` without ever including that library, guaranteeing an "attempt to call a nil value" crash whenever that branch rolled true. A `local opened` guard and the missing `local SectorGenerator = include("SectorGenerator")` fix both issues.
- [Bugfix] **World-Eater Boss Death Crash:** `ca_worldeater_behavior.lua`'s `CAWorldEater.onDestroyed()` called `SectorTurretGenerator(Sector().seed)` to roll the boss's legendary turret drops but never included that library anywhere in the file, guaranteeing a hard crash the instant the boss died — before any of its loot could actually drop. `SectorTurretGenerator` is now correctly included.
- [Bugfix] **Rift Hazard & Singularity Detonation Damage Not Applying:** Both `ca_rift_hazard.lua`'s shield-drain tick and `ca_singularity_detonation.lua`'s detonation blast called `Entity:inflictDamage()` without the engine's required `index` argument (`0` for whole-entity damage), which silently shifted the ship's `translationf` position into the integer index slot instead of the `location` slot — unlike the correct 6-argument form used everywhere else in the mod (e.g. `ca_worldeater_behavior.lua`, `ca_eclipse_abilities.lua`). Both now pass the full, correctly-ordered argument list.
- [Bugfix] **Eclipse Conquest Sector Mismatch:** The Eclipse's `eclipse_pending_annihilations`, `eclipse_pending_sieges`, and `eclipse_held_territory` coordinate lists only delimited entries with a trailing comma (e.g. `"25_10,5_10,"`), so a plain substring search for one sector's entry (e.g. `"5_10,"`) could false-positive match inside an unrelated sector's entry whenever one coordinate string happened to be a suffix of another (e.g. `"25_10,"`). A player entering the wrong sector could trigger that sector's annihilation/siege script instead of the actually-queued one, and removing the match could corrupt the neighboring entry. All coordinate list lookups and removals (`eclipse_conquest_manager.lua`, `ascendancyplayer.lua`) now anchor both the leading and trailing comma so entries can no longer collide as substrings of each other.
- [Code Quality] Removed several dead/unused locals (`ascendancyplayer.lua`, `ca_campaign_controller.lua`, `eclipse_awakes.lua`, `eclipsegenerator.lua`), a no-op dead conditional (`eclipse_conquest_manager.lua`), a duplicate chat message (`ca_rift_hazard.lua`), and corrected a stale comment (`ascendancysiege.lua`).

## [v1.5.1]

### 🪲 Bug Fixes
- [Bugfix] **Linux Dedicated Server Compatibility:** Fixed massive, game-breaking case-sensitivity issues across multiple scripts (such as `include("sectorgenerator")`) that completely prevented event scripts from loading on Linux dedicated servers, causing story and spawn logic to silently abort.
- [Bugfix] **API Hard Crash Preventions:** Corrected severe issues where scripts attempted to directly modify read-only properties (like `player.money` or `owner.money`). Direct assignments caused the Lua engine to quietly abort the entire thread, halting mission execution. Replaced with proper `player:pay()` and `faction:receive()` economy APIs.
- [Bugfix] **Multiplayer RPC Exploits:** Re-wired server/client API calls in namespaced files that incorrectly used `callable(nil, ...)`. This resolves silent server rejections when clients interacted with custom UI, allowing multiplayer functions to execute securely.
- [Bugfix] **Signature Mismatches & UI Crashes:** Fixed incorrect engine API parameters for `UpgradeGenerator`, event hooks (`onDamaged` vs `onShieldDamaged`), and resource transactions (`Faction:getResources()`) that caused the Ascendancy Beacon interface to grey out and crash upon activation.

## [v1.5.0]

### 🛠️ Architecture & Optimization
- [Optimized] **Global Wrapper Purge:** Completely overhauled the internal C++ API wrapper structure across `galaxy/`, `lib/`, `events/`, `entity/`, and `sector/` scripts. Removed dozens of invalid `function updateServer() return Namespace.updateServer() end` wrappers that were causing silent multiplayer linkage failures, strictly adhering to Avorion VFS constraints.
- [Optimized] **Namespace Alignment:** All `callable()` RPC registries and state persistence hooks (`secure()`/`restore()`) have been rigorously audited and mapped directly to their correct namespace objects, guaranteeing flawless dedicated server synchronization.

### 🪲 Bug Fixes
- [Bugfix] **Aegis Campaign State Machine:** Fixed a severe structural logic flaw across the entire 5-part Aegis Story Campaign (`ca_story1` through `ca_story5`). Previously, the `ca_ascendant_envoy.lua` dialog script would brute-force delete the mission scripts via `removeScript()` when advancing the questline, which prevented the missions from naturally calling `finish()` and logging as "Completed" in the player's quest journal. All 5 missions have been refactored to include an `updateServer()` state hook that listens for the Envoy to clear the `ca_ready_for_debrief` flag, allowing them to terminate cleanly.
- [Bugfix] **Callback Registrations:** Patched `ca_singularity_detonation.lua` and several other entity scripts to correct `callable` namespace targets that were previously pointing to `nil`, restoring missing visual and mechanical effects.

## [v1.4.1]

### 🪲 Bug Fixes
- [Bugfix] **Visual Desync & Server Crash Prevention:** Fixed a critical server-side crash in `ca_worldeater_behavior.lua`, `ca_singularity_detonation.lua`, and `ca_anomaly_stash.lua` where the engine would attempt to execute `Sector():createExplosion()` or `createGlow()` directly on the server thread. All visual detonation logic has been strictly isolated and routed through `broadcastInvokeClientFunction`, ensuring massive cinematic explosions properly render for all clients in the sector without crashing the dedicated server.
- [Bugfix] **API Call Accuracy:** Ensured correct namespace and global function wrapper registrations for visual RPC callbacks across all affected scripts.

## [v1.4.0]

### 🛠️ Architecture & Optimization
- [Optimized] **Progressive Materialization:** Completely overhauled the `ca_expansion_manager.lua` and `ascendancyplayer.lua` API. When The Eclipse faction expands or annihilates a sector, they no longer force the server to physically load the sector into memory to generate stations or delete entities (which caused massive server stutters). 
- [Feature] **Lazy Loading API:** Eclipse expansions and sector annihilations are now queued mathematically in a global `CosmicAscendancy_PendingExpansions` string. When a player jumps into the affected sector, the game seamlessly intercepts the loading screen and instantly applies the changes. Zero stutter!
- [Optimized] **Threat Economy Safety:** Added a 50ms CPU intercept check via `HighResolutionTimer` inside the Eclipse Threat Economy manager (`eclipse_conquest_manager.lua`). This prevents the server from freezing when validating thousands of sectors against the Annihilation engine.

## [v1.3.1]

### 🐛 Bug Fixes
- [Bugfix] **Lore Anomalies:** Fixed a C++ API logic exception (invalid type 'Matrix' expected 'vec3') when calculating randomized anomaly stash generation, preventing the lore databanks from appearing.

## [v1.3.0]

### ⭐ Features
- **Omni-Sensor Deep Scan:** The Ascendant Omni-Sensor now automatically performs a deep scan upon entering a sector, printing the exact coordinates of any claimable asteroids or hidden stashes directly to your chat interface.
- **Slipstream Drift:** Jumping into a sector with the Ascendant Slipstream Drive equipped now grants a massive +50% velocity boost for 10 seconds, simulating the momentum of exiting the hyperspace tunnel.
- **Void Drill Overclocking:** The immense power draw of the Ascendant Void Drill now occasionally causes your ship to vent massive, harmless plasma bursts. 
- **Anomaly Resurgence:** When extracting databanks from a Lore Anomaly, there is now a 10% chance for the anomaly to resonate and spawn a secondary, smaller stash nearby containing bonus loot!


## [v1.2.5]

### 🐛 Bug Fixes
- [Bugfix] **Lore Anomaly Crash Fixes:** Fixed two critical server crashes in `ca_story_lore_anomalies.lua` when spawning deep-space corrupted databanks. First, replaced an invalid enum `ComponentType.Station` with proper `sector:getEntitiesByType(EntityType.Station)` checks to accurately verify empty sectors. Second, removed a defunct `getBasicWreckagePlan` call that was crashing the `SectorGenerator` by defaulting to the engine's built-in `createUnstrippedWreckage` logic, allowing anomalies to finally spawn flawlessly!

## [v1.2.4]

### 🐛 Bug Fixes
- [Bugfix] **Aegis Spawn Fatal Crash:** Fixed a severe legacy bug carried over through all campaign stages (`ca_story0` through `ca_story5`). The scripts were attempting to spawn the Aegis Envoy ship using an invalid `SectorGenerator:createShip(...)` API call, which would trigger a fatal silent crash the moment a player entered the rendezvous sector, failing to progress the questline. Successfully migrated all Aegis spawns to the robust `sector:createShip` pipeline with proper missing-plan fallbacks and manually re-hooked the despawn scripts.
## [v1.2.3]

### 🐛 Bug Fixes
- [Bugfix] **Aegis Mail Trigger Crash:** Fixed a critical hyperspace race-condition crash in `ca_story0_meet_aegis.lua`. If a player jumped to a new sector at the exact millisecond the 10-second Aegis delay timer elapsed, the mission would fail to grab the sector coordinates and silently crash, failing to deliver the rendezvous mail or objective. Replaced the static `Sector():getCoordinates()` API with the robust `player:getSectorCoordinates()` to ensure it safely resolves coordinates even during loading screens and hyperspace jumps.
- [Bugfix] **Aegis Mission UI:** Added the explicit `mission.data.autoTrackMission = true` flag to the Aegis story mission. Now, the moment Aegis contacts the player and assigns the rendezvous coordinates, it will properly force the objective to appear on the player's right-hand HUD immediately, preventing players from missing the event.
- [Bugfix] **Restored Missing Campaign Stage:** Fixed a severe progression gap in `ca_ascendant_envoy.lua` where the entire 3rd stage of the campaign (`ca_story3_vanguard.lua`) was accidentally skipped, causing the story to jump straight from the Forge to the Citadel. The Vanguard Assault has now been properly wired back into the main storyline, bridging the gap between stages 2 and 4. Stage 3 now correctly spawns an Aegis debrief after defeating the Juggernaut, granting exclusive mid-game rewards.
- [Networking] **Multiplayer & Alliance Safety Nets:** Overhauled all story mission scripts (`ca_story1` through `ca_story5`) to be fully cooperative and dedicated-server safe.
  - **Duplicate Prevention:** Co-op players arriving in the same sector will no longer accidentally spawn duplicate bosses on top of each other.
  - **Co-op Progression:** If multiple players have the same mission stage active in the sector, defeating the boss cooperatively will properly advance the quest for all of them simultaneously.
  - **Race Condition Fix:** Added `spawnConfirmed` flags to `updateServer` loops to prevent dedicated server desyncs from instantly auto-completing missions before the boss fully loads into the engine.
  - **Mission Isolation:** Players on different stages of the campaign will not accidentally advance their quests or skip stages by assisting another player in their mission.

## [v1.2.2]

### 🐛 Bug Fixes
- [Bugfix] **Aegis Legacy Save Compatibility:** Fixed an issue where loading into a legacy save with the Wormhole Guardian already destroyed would trigger the Aegis encounter instantly without any narrative delay. `ca_spawn_envoy.lua` now properly utilizes a 10-second `updateServer` background delay before initiating contact.
- [Bugfix] **Dark Sector Premature Spawning:** Fixed a bug in `ca_darksector_generator.lua` where players could encounter Eclipse fleets and Dark Matter Fog in the deep core before actually defeating the Wormhole Guardian and awakening them.
- [Bugfix] **Story Mission UI Polish & Softlocks:** Safely patched all 6 stages of the Cosmic Ascendancy narrative campaign (`ca_story0` through `ca_story5`). The missions are now explicitly marked as un-abandonable (`abandon = nil`), preventing players from accidentally aborting the questline and soft-locking their playthrough. Added missing `mission.data.brief` descriptions and assigned the official yellow story-mission icons.

## [v1.2.1]

### ✨ Features & UI
- [Feature] **Aegis Contact Flow:** Completely overhauled the initial encounter with Aegis, the Ascendant Envoy. Instead of abruptly spawning at sector 0:0 during the unskippable end-credits sequence, Aegis now formally contacts the player via a secure, priority in-game Mail and grants a mission (`A Mysterious Summons`) directing them to a nearby rendezvous coordinate.

### 🐛 Bug Fixes
- [Bugfix] **Aegis Despawn Softlock:** Fixed a critical progression softlock during the new Aegis rendezvous encounter. If a player warped to her sector but jumped away before initiating contact (causing her to naturally despawn to prevent sector clutter), the game previously permanently locked her out. The mission now dynamically scans the sector and safely respawns her upon the player's return.
- [Bugfix] **Cinematic Music Overlap:** Fixed an issue where the custom "Forge the Ascendant" OST would awkwardly overlap with the Wormhole Guardian's end-credits track. The OST trigger has been removed from a hardcoded 15-second timer and moved to the exact moment the player enters Aegis's rendezvous sector, explicitly silencing all vanilla battle music (`Music():stop()`) before playing.
- [Bugfix] **StringUtility API Crash:** Fixed a severe, widespread background thread crash affecting 21 scripts across the Cosmic Ascendancy module (including `ca_worldeater_behavior`, `eclipse_awakes`, and `eclipse_roaming_boss`). These scripts utilized the `%_T` localized string macro but failed to `include("stringutility")`, causing fatal arithmetic runtime errors when triggered.
- [Bugfix] **Audio Hook Syntax & Synchronization:** Fixed critical server desyncs in `ca_boss_audio_hook.lua`. Removed legacy global C++ wrappers shadowing the engine's internal callback handler and properly bound all client/server RPCs natively to the `CaBossAudioHook` namespace.
- [Bugfix] **Linux Case Sensitivity:** Fixed a critical bug where `ca_darksector_generator.lua` and `ca_spawn_envoy.lua` used lowercase `include("sectorgenerator")`, which causes a fatal `module not found` crash on strict Linux dedicated servers.

## [v1.2.0] - The Ascendant Envoy Update

### ✨ Features & UI

- [Feature] **Aegis, The Ascendant Envoy:** Added a completely new story NPC, Aegis, who spawns to guide players through the Eclipse lore after defeating the Wormhole Guardian. The NPC features an invincible, non-collidable hologram projection format.
- [Feature] **Expanded Campaign:** Vastly expanded the end-game campaign into 5 distinct, sequential missions (The Seal is Broken, The Vanguard, Forging the Defense, The Citadel Threat, and The World-Eater). Replaced generic NPC mentions with Aegis and fully refreshed the dialogue.

### 🐛 Bug Fixes

- [Bugfix] **Engine Pathing:** Fixed a critical bug where `server.lua` was placed in the wrong folder structure for global initialization, failing to trigger the Aegis events upon Guardian death. Restored to `data/scripts/galaxy/server.lua`.
- [Bugfix] **Cinematic Audio & Banners:** Fixed a broken server-to-client RPC hook (`ca_boss_audio_hook.lua`) that was preventing ominous music and red Doomsday banners from appearing on players' screens when an Eclipse boss spawns.

## [v1.1.1] - Hotfix

### 🐛 Bug Fix

- [Bugfix] **Namespace RPC Registries:** Fixed a critical structural flaw across `ascendancyforge.lua`, `ascendancybeacon.lua`, `ca_station_overdrive.lua`, `ca_boss_audio_hook.lua`, `ca_singularity_detonation.lua`, `ca_world_eater_manager.lua`, `eclipsebossbehavior.lua`, `ascendancysiege.lua`, `ca_expansion_manager.lua`, `cc_newsgenerator.lua`, and `cosmicchronicles_rumormonger.lua`. Corrected `callable()` RPC registries based on whether the script utilizes a module namespace. Scripts with `-- namespace` declarations (e.g. `ascendancybeacon.lua`, `ca_station_overdrive.lua`) now properly bind their RPCs to their internal namespaces without global wrappers, while scripts executing in the global scope correctly retain their `callable(nil)` registries, restoring full UI interactivity and event synchronization for multiplayer.

### 📦 Content Additions
[Added] New .xml ship and station designs for The Eclipse.

## [v1.1.0] - Gameplay & Fixes

### ✨ Features & UI

- [Feature] **World-Eater Grace Period:** After defeating the Eclipse World-Eater (or surviving an execution), the entire galaxy is granted a 10 real-time hour Grace Period where the Doomsday timer is paused.
- [Feature] **Global Status Command:** Added a new `/eclipsestatus` chat command available to all players. It allows players to check the remaining duration of the Citadel Suppression Field and the World-Eater Grace Period.

### 🐛 Bug Fixes

- [Bugfix] **World-Eater Engine Crash:** Fixed a severe server crash during the World-Eater doomsday execution sequence. The script previously called an invalid global API (`Galaxy():getFactions()`); it has been replaced with the robust `Galaxy():getNearestFaction(x, y)` to properly calculate famine and market repercussions without destroying the thread.
- [Bugfix] **Ascendant Overdrive UI Failure & Math Desync:** Fixed a critical bug in `ca_station_overdrive.lua` where the "Ascendant Overdrive" UI button would silently fail to activate when clicked by a client. The RPC bridge functions were incorrectly restricted to a local table scope in the `callable` registry, preventing the engine's global `invokeServerFunction` from resolving them. Additionally, replaced an invalid `addMultiplyableBias` call with `addBaseMultiplier` to properly grant the factory its +200% production capacity steroid, rather than a microscopic flat bonus.
- [Bugfix] **World-Eater Mechanics Total Failure:** Fixed a catastrophic bug in `ca_worldeater_behavior.lua` where the boss's entire core mechanical loop (Tether Invulnerability, Phase Tracking, and Anomalies) was encapsulated in a local namespace without global wrapper functions. This caused the C++ backend to silently fail to bind the `updateServer`, `onDestroyed`, and `onDamaged` lifecycle hooks. All 13 core events and RPC bridges have been exposed globally, completely restoring the boss fight's functionality.
- [Bugfix] **World-Eater DPS Scaling Desync:** Fixed an issue in `eclipse_boss_scaling.lua` where the boss's dynamic DPS scaling (based on extra players in the sector) was fundamentally broken due to incorrect C++ modifier API usage. It was incorrectly using `addMultiplyableBias` (flat addition) for its FireRate bonus instead of `addBaseMultiplier`, resulting in negligible damage scaling. The API has been corrected to properly amplify the boss's DPS.
- [Bugfix] **Ascendancy Beacon Total Failure:** Fixed a catastrophic bug in `ascendancybeacon.lua` where the entire script was encapsulated in a local namespace without global wrapper functions. Because the Avorion C++ backend requires global functions for lifecycle and event hooks, the entire beacon script (including UI buttons, upkeep checks, and toll collection) was silently failing to execute. All 18 hooks and RPC bridges have been exposed globally.
- [Bugfix] **Ascendant Forge Complete UI Failure:** Fixed a catastrophic bug in `ascendancyforge.lua` where the entire station UI (including Ignition, Claiming, and Decryption) failed to function for players. The script's 18 UI callbacks and RPC methods were heavily encapsulated within a local table namespace without global C++ wrappers, and their `callable` registries were incorrectly restricted. Global wrappers have been injected for all UI hooks, and RPC tags have been corrected to `nil` to allow engine resolution.
- [Bugfix] **Ascendant Gateway Entity Crash:** Fixed a severe server crash in `ca_ascendant_gateway.lua` triggered when scanning for hostile forces. The script mistakenly treated the raw integer outputs of `Sector():getPresentFactions()` as full faction objects, causing a fatal null-reference when checking diplomacy. The loop has been corrected to resolve the integers into proper faction instances.
- [Bugfix] **Ascendant Gateway DPS Scaling Desync:** Fixed an issue where Ascendant Guardian defenders were receiving a flat, microscopic bonus to their Fire Rate and Shields instead of a massive percentage boost due to an invalid `addMultiplyableBias` API call. Replaced with `addBaseMultiplier` to properly grant them +200% DPS and +300% Shields.
- [Bugfix] **Citadel Loot Monotony Fix:** Fixed an issue in `ca_citadel_loot.lua` where the legendary turret drops from destroyed Eclipse Citadels were generating identical stats across the entire Y-axis of the galaxy. The `SectorTurretGenerator` was erroneously being seeded by the sector's X coordinate integer rather than the unique `Sector().seed`.
- [Bugfix] **World-Eater Payout Crash:** Proactively replaced a high-risk `player:receive()` API overload in the Eclipse World-Eater's death payout loop (`eclipsebossbehavior.lua`) with direct property assignment. This eliminates a potential null-reference engine crash when the boss attempts to award its 5-billion credit bounty to victorious players.
- [Bugfix] **Story Mission Hyperspace Exploit:** Fixed a massive game-breaking exploit in `ca_story1_awakening.lua` and `ca_story3_vanguard.lua`. Previously, players could instantly skip entire boss fights, scripted ambushes, and anomaly scan timers simply by jumping to an adjacent sector (which caused the mission's entity tracker to return 0, instantly flagging the objective as complete). Both missions now strictly validate the player's physical coordinates before progressing the quest lines.
- [Bugfix] **Monolith Matrix Desync:** Fixed a critical API math desync during the first story mission's anomaly generation where the script attempted to apply a complex Matrix object directly to a `translationf` coordinate vector. The monolith spawn function now properly digests the matrix during instantiation, preventing a fatal Lua thread crash.
- [Bugfix] **Beacon Toll Payout Crash:** Proactively replaced a high-risk `owner:receive()` API overload in the Ascendancy Beacon toll payout loop with direct property assignment. This eliminates a potential null-reference engine crash when the beacon attempts to deposit AI passage tolls into the player's treasury.
- [Bugfix] **Ascendant Siege Loot Generation Crash:** Fixed a fatal table call crash in `ascendancysiege.lua` during the victory loot generation sequence. The script improperly referenced the `TurretGenerator` namespace directly instead of instantiating a localized `SectorTurretGenerator` using the sector's seed, which caused the Lua thread to instantly terminate upon victory instead of dropping legendary rewards.
- [Bugfix] **World-Eater Spawn Hang & Global Event Lock:** Fixed a critical bug in `ca_world_eater_event.lua` where a failed instantiation of the World-Eater boss (due to sector limits or generation errors) would cause the script to hang indefinitely. It now explicitly catches instantiation failures and safely cancels the global event trigger, preventing players from being permanently locked into the boss music track with a frozen doomsday countdown.
- [Bugfix] **Ascendant Siege Crash & Faction Desync:** Fixed a critical server crash inside `ascendancysiege.lua` where the script improperly treated raw integer outputs from `Sector():getPresentFactions()` as object models, causing a fatal null-reference when checking AI properties. Additionally, replaced an invalid `owner:receive()` API overload that silently broke siege defense rewards with direct economy manipulation.
- [Bugfix] **Boss Spawner Thread Crash:** Fixed a critical invalid API call inside `spawneclipseboss.lua`. The script mistakenly attempted to invoke `SectorGenerator:createWormhole()` (which doesn't exist). It now correctly utilizes the native `WormholeDescriptor` component to spawn anomalous rifts. Additionally, corrected the `SectorTurretGenerator` invocation to properly pass `Sector().seed` instead of an invalid argument matrix.
- [Bugfix] **Ascendant Relic Math & API Desync:** Fixed an issue where the underlying math for the 8 endgame Ascendant Subsystems (Living Relics) was fundamentally broken due to incorrect C++ modifier API usage. Percentage-based buffs (like +500% Velocity or +1000% Cargo) were incorrectly using `addMultiplyableBias` (flat additions) instead of `addBaseMultiplier`, resulting in negligible stat gains. All relics have been rigorously audited and corrected.
- [Bugfix] **Rift Hazard Double-Loop & Shield Combat State:** Fixed a severe performance issue inside `ca_rift_hazard.lua` where it was firing redundant `updateServer` loops due to an invalid `deferredCallback`. Furthermore, its shield drain mechanic was completely refactored to use the native `inflictDamage` API instead of manually reducing shield durability, meaning ships taking Rift Hazard damage are now properly flagged as being "in combat" by the engine.
- [Bugfix] **Player Context & Script Injection Optimization:** Fixed an implicit context desync in `ascendancyplayer.lua` by enforcing strict context parameter passing (`playerIndex`) to guarantee stability during callback execution. Additionally, implemented an entity-type safeguard to strictly prevent the engine from attempting to inject Lua scripts into lightweight components (such as Fighters), eliminating C++ backend console spam.
- [Bugfix] **Audio Hook Integration & API Scope:** Replaced placeholder UI comments inside `ca_boss_audio_hook.lua` with strict, functional native `Music():playTrack()` implementations to actually execute World-Eater combat music. Additionally, corrected the `callable` registry tags from a table scope to `nil`, fixing a bug where the global engine wrapper could not correctly resolve audio bridge triggers during `invokeClientFunction` execution.
- [Bugfix] **Invasion Engine Crash & Ghost Event:** Fixed a severe bug in `eclipseinvasion.lua` where the background event script crashed silently without notifying the player. The script was calling the global `AlertAbsentPlayers` function without including the native `player.lua` library. Additionally, added a hyperspace safety check to prevent the script from fatally crashing if the invasion triggered at the exact moment a player jumped to a new sector.
- [Bugfix] **Campaign Controller Event Sync & Crash Fix:** Fixed an implicit state desync in `ca_campaign_controller.lua` where the background script hardcoded a `SectorChangeType.Jump` parameter, leading to incorrect quest progression if players entered story sectors via login or gateway structures. Additionally, patched a fatal null-reference crash by verifying `Sector()` instantiation during asynchronous transitions.
- [Bugfix] **Dark Sector Physics Engine Overload:** Fixed a severe flaw in `ca_darksector_generator.lua` where Eclipse fleets generated within deep core Dark Sectors were spawned at the exact same spatial matrix coordinates. This caused catastrophic collision engine failures, sending capital ships violently spinning and causing severe server-side physics lag. The generator now correctly utilizes the native Placer library to resolve intersections across the fleet array before initializing physics. Additionally, implemented a strict hyperspace transition check to prevent null-reference desyncs.
- [Bugfix] **World Eater Alliance Territory Targeting:** Fixed a critical flaw in `eclipse_roaming_boss.lua` where the background roaming logic successfully avoided single-player territories, but failed to recognize player Alliance territories as protected sectors. The script's algorithmic targeting sequence now correctly validates both player and alliance factions before deploying the World Eater, securing player alliance hubs from random backend destruction.
- [Bugfix] **Eclipse Stronghold Generation API Fix:** Fixed a massive API logic error where the global server script `eclipse_awakes.lua` attempted to bind to an `onSectorGenerated` callback hook that simply does not exist in the Avorion engine's global `Server()` scope. This dead code caused Eclipse Strongholds to never actually spawn. The entire generation algorithm has been surgically migrated to the player-side transition hook in `ascendancyplayer.lua`. Now, when the first player discovers an unmarked sector, the script safely hooks into the native `SectorSpecifics` backend to dynamically calculate core distance probabilities and spawn the stronghold immediately.
- [Bugfix] **Lore Anomaly Logic & Library Fixes:** Fixed a severe script crash in `ca_story_lore_anomalies.lua` caused by an invalid API invocation (`getPositionInSector` instead of `createPositionInSector`). Furthermore, explicitly defined a table export (`return LoreAnomalies`) at the end of the script, fixing a fatal error where background caller scripts failed to load it as a library, crashing the entire event chain. Also strictly enforced player context routing and hyperspace safety locks to prevent background transition desyncs.
- [Bugfix] **Singularity Turret Scope Crash:** Fixed a critical bug in `eclipsegenerator.lua` where the generation pipeline crashed when spawning Singularity ships. The script attempted to invoke `getWeapons()` directly on a physical `Entity` wrapper instead of routing the request through the instantiated `Weapons` component. Singularity artillery turrets now properly inherit their intended 300% reach multipliers without destroying the backend generator thread.
- [Bugfix] **World-Eater Summoning & Desync:** Fixed a bug in `ca_raid_summoner.lua` where the script failed to save its internal state, allowing players to farm multiple World-Eaters simultaneously if a server rebooted. Also removed a conflicting hyperspace exit animation that caused the boss to visually glitch upon arrival.
- [Bugfix] **Singularity Detonation Engine Bug:** Fixed a fatal script crash inside `ca_singularity_detonation.lua` caused by a missing `callable` import, and repaired the global wrapper scope to ensure warning sounds properly play for clients. Additionally, shifted its damage pipeline to use the native `inflictDamage` API, ensuring players caught in the blast correctly enter the "Under Attack" combat state.
- [Bugfix] **Delayed Annihilation Instant-Death Trap:** Fixed an extremely severe game-breaking bug in `ca_delayed_annihilation.lua`. When Eclipse annihilated an unloaded sector, the script would wait for a player to visit it before wiping the sector's entities. However, the script instantly deleted the active player's ship the millisecond they jumped in (permanently vanishing the ship without reconstruction tokens or insurance). Player and Alliance ships are now strictly protected from the background annihilation wipe.

### ⚙️ System

- [Optimization] **Server Save Bloat:** Radically restructured how Eclipse Strongholds are flagged during galaxy generation. The generator now natively injects a localized sector script token instead of saving thousands of coordinate flags to the global `Server()` database. This permanently prevents massive save-file bloat and memory leaks on dedicated servers spanning long playthroughs.

### ⚖️ Balance

- [Balance] **Harbinger Re-Tune:** Reduced the Shield Durability Multiplier on Eclipse Harbingers from +3750% to +1000% to ensure that the Eclipse World-Eater Raid Boss properly retains its crown as the supreme flagship of the Ascendant fleets.
- [Balance] **Living Relics True Power:** Re-aligned all baseline tooltips and dynamic math loops for the Ascendant "Living Relics" (Aegis, Omni-Sensor, Slipstream, Swarm Nexus, Void-Drill, War-Drive, and Neural Implant). They now correctly grant the extreme, god-like stat boosts promised in their descriptions (e.g., flat +50,000 Production Capacity or true +1000% Cargo Scaling).

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
- [Bugfixed] **Station Foundation Behavior:** Previously, the Codex incorrectly stated that the Ascendancy Beacon automatically generated its structure when founded by a player. The logic has been completely separated: the towering `Ascendancy_beacon.xml` is strictly generated as an ancient wreck during the main story quest, and players founding their own Ascendancy Beacons will correctly enter Build Mode to use their own ship/station designs as intended by vanilla mechanics.
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



### ? Bug Fixes
- Fixed an architectural namespace violation in the World Eater Manager script where global wrapper functions were improperly defined, which could cause duplicate hook execution and VFS instability.
