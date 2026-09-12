# 🌌 Cosmic Ascendancy

*The endgame campaign and crisis simulation for the Cosmic Series.*

![Version](https://img.shields.io/badge/version-2.0.0-6f42c1?style=flat-square)
![Avorion](https://img.shields.io/badge/Avorion-2.5.13-2f81f7?style=flat-square)
![License](https://img.shields.io/badge/license-GPLv3-informational?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=flat-square)
![Requires](https://img.shields.io/badge/requires-Core%204-success?style=flat-square)

> [!TIP]
> New here? [`PLAYER_GUIDE.md`](PLAYER_GUIDE.md) is a friendly gameplay tour. [`WIKI.md`](WIKI.md) has the full technical reference, and [`Ascendancy_Lore.md`](Ascendancy_Lore.md) tells the story of The Eclipse.

## 📖 Overview
Following the destruction of the Wormhole Guardian, a darker, ancient adversary awakens: The Eclipse. Cosmic Ascendancy adds an endgame narrative campaign where you track a mysterious distress signal, uncover the truth behind The Eclipse, and unlock the Ascendancy Forge to craft the weapons needed to survive.

## ✨ Features
<details>
<summary><b>Click to expand features</b></summary>

- **The Eclipse:** An endgame crisis faction that invades from the galactic core outward.
- **The World-Eater Doomsday Event:** A 20-minute countdown that targets a populated sector with a colossal raid boss.
- **Hunt the Dread-Lord:** A retreating Nemesis relocates instead of vanishing, so you can track it down and finish it off.
- **Eclipse Remnant Escalation:** Clearing World-Eaters and Citadels builds toward five tiers of rising difficulty.
- **Galactic Dread News Network:** Live server-wide reporting of sector annihilations and heroic victories.
- **Adaptive Scaling:** The Eclipse grows in size and power to match the highest-tier player on the server.
- **Dynamic Faction Expansion:** AI factions and Pirates naturally expand their borders into uncharted sectors over time, driven by a background simulation with no loading-screen stutter.
- **The Ascendancy Beacon:** A recoverable capital megastructure with renewable sector leases, independent upkeep, fleet-wide bonuses, and a Sanctuary Field at Tier 3+.
- **Story Campaign:** A scripted, multi-stage questline whose missions, coordinates, progress, and rewards are tracked independently for every player.
- **The Ascendancy Forge:** Craft Ascendant-tier technologies through server-verified, restart-safe orders using Eclipse materials and rare subsystem sacrifices.
- **Dynamic Strongholds:** Eclipse Citadels naturally spawn and conquer sectors.
- **Eclipse Rift Spillage:** Eclipse invasions have a 10% chance to tear open a subspace rift that drains sector shields. Destroy the Eclipse Rift Stabilizer to close it.
</details>

## ⚙️ Requirements
- Avorion 1.0+
- **Required:** `Cosmic Vault`, `Cosmic Overhaul`, `Cosmic War`, and `Cosmic Chronicles` — Cosmic Ascendancy is one of the Core 4, and the Core 4 require each other plus Vault.

`modinfo.lua` itself only declares `Cosmic Vault` — Avorion throws a circular-dependency error if the Core 4 try to cross-declare each other there, so the real requirement is enforced through each mod's Steam Workshop "Require Items" listing instead. See `WIKI.md` for the full synergy list (dynamic War Heat scaling, contraband markets, corrupted data nodes, and more).

## 🚀 Installation
1. Place the folder in:
   - **Windows:** `%AppData%\Avorion\mods\`
   - **Linux:** `~/.avorion/mods/`
2. Enable **Cosmic Ascendancy** in **Settings -> Mods**.
3. Restart Avorion when prompted.

## 📚 Documentation

| Document | For | Covers |
|---|---|---|
| [`PLAYER_GUIDE.md`](https://github.com/Stormiebox/Cosmic-Ascendancy/wiki/Player-Guide) | Players | A friendly walkthrough of the Eclipse crisis and its systems. |
| [`WIKI.md`](https://github.com/Stormiebox/Cosmic-Ascendancy/wiki/Features-and-Enhancements) | Anyone who wants the exact numbers | The Nemesis System, the Eclipse Threat Dashboard (`/eclipsestatus`), Ascendant Gateways, and full technical detail. |
| [`Ascendancy_Lore.md`](https://github.com/Stormiebox/Cosmic-Ascendancy/wiki/Cosmic-Ascendancy-Lorebook) | Players who want the story | The Eclipse's origin and narrative campaign lore. |
| **Cosmic Codex** *(in-game)* | Players | All of the above, readable without leaving the game. |

Server administrators can inspect ambiguous migrated or interrupted operations with the dry-run
`/ascendancyrepair` command. See `WIKI.md` for its syntax and safety model.

---

<div align="center">

**🌌 Cosmic Ascendancy** — part of the [Cosmic Series](https://github.com/Stormiebox) · built by **Stormbox**

</div>
