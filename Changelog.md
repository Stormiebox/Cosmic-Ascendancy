# Cosmic Ascendancy - Changelog

All notable changes to **Cosmic Vault** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

--

## [v1.0.0] - Initial Release
The ultimate endgame expansion for the Cosmic Series has arrived. Establish your empire's permanent capital, generate immense wealth, forge god-tier weaponry, and defend against gargantuan sieges!

### Added
*   **The Ascendancy Beacon**: A brand new massive station that permanently keeps its sector loaded (24/7). Players can upgrade this beacon from Tier 1 to Tier 5 using astronomical amounts of credits and ores.
*   **Global Ascendant Buffs**: Upgrading your beacon grants a permanent, account-wide stat buff to all ships in your fleet, multiplying Hull, Shields, and Damage.
*   **The Grand Toll**: Since the sector is permanently loaded, the beacon acts as an intergalactic border checkpoint. All NPC traders and AI factions jumping into the sector are charged a massive entry tax that scales with the beacon's tier.
*   **Dynamic Wartime Premium**: Integrated with `Cosmic War`. AI factions currently engaged in massive wars will desperately pay up to a **+50% Premium Toll** for seeking safe harbor in your sector.
*   **Capital Sieges**: A hidden playtime clock runs within the beacon. Every 3 to 6 hours, a devastating siege fleet (Pirates, Xsotan, or War Factions) will invade your sector to destroy the beacon. If you defend it, you earn legendary loot. If it falls, your global buffs collapse.
*   **The Stellar Forge**: Exchange 1+ Billion Credits and massive ore reserves to asynchronously craft custom God-Tier weapons over 24 real-time hours.
*   **Wartime Innovation**: Weapons crafted at the Stellar Forge receive exponential damage multipliers based on how close the forge is to the Galactic Core (+200%) and your current War Heat (+150%). Forging at the core during a massive war yields a 9.0x damage super-weapon!

### Integrations
*   **Cosmic Vault**: Utilizes `CosmicVaultBuffs` API for global multiplier injections, and `CosmicVaultNews` to broadcast your empire's ascension, sieges, and falls to the entire galaxy.
*   **Cosmic War**: Deeply integrated with `CosmicWarBridge` to fetch War Heat for dynamic toll scaling, siege attackers, and Forge weapon multipliers.
*   **Cosmic Overhaul**: Requires standard Overhaul progression limits.
*   **Cosmic Chronicles**: Adds lore and weight to the massive empire capital milestones.

### Bug Fixes & Compliance
*   **Keep-Alive Engine**: Built a dedicated background galaxy script (`ascendancykeepalive.lua`) to ensure the server physically holds beacon sectors in memory instead of unloading them.
*   **Alliance Buff Injection**: Patched the player synchronization script so that Alliance defense fleets properly inherit the global Ascendant stats when jumping into a sector.
*   **Stat Bloat Safety**: Added `onRemove` callback safety nets to prevent players from keeping permanent stat bloat if the beacon is destroyed or the mod is uninstalled.
*   **Asynchronous Forge Safety**: Ensured the forge utilizes server-side global playtime to prevent duplication exploits and allow crafting to continue gracefully while players are offline or during server restarts.