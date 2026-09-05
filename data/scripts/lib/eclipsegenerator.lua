package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("utility")
include ("stringutility")
include ("defaultscripts")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipUtility = include ("shiputility")
local PlanGenerator = include ("plangenerator")
local cv_goods = include ("cosmicvaultgoods")

local EclipseGenerator = {}

-- ASCENDANT GOODS REGISTRATION (early, not just in eclipse_conquest_manager.lua):
-- eclipse_conquest_manager.lua only ever attaches 10 minutes after the Guardian dies (it's
-- addScriptOnce'd behind Server():getValue("eclipse_fully_awake") in eclipse_awakes.lua), and its
-- own initialize() is the only other place these three goods get registered. But this module
-- (eclipsegenerator.lua) loads the instant the very first Eclipse ship is spawned -- e.g.
-- ca_story1_awakening.lua's Phase 3 ambush, seconds/minutes after the Guardian kill -- and every
-- Eclipse ship carries ca_eclipse_abilities.lua (see EclipseGenerator.createShip below), whose
-- onDestroyed handler drops goods["Ascendant Matter"]. Without registering it here too, an early
-- ambush kill looks up a good that was never created and drops nothing (or worse, hands
-- Sector:dropCargo a nil good). CosmicVaultGoods.registerGood() checks goodsArray for an existing
-- entry by name and no-ops if found, so this and eclipse_conquest_manager.lua's later call are
-- both safe to run.
if cv_goods and cv_goods.registerGood then
    cv_goods.registerGood({
        name = "Ascendant Matter",
        description = "A hyper-dense dark energy composite synthesized by Eclipse Harvesters.",
        price = 250000,
        size = 2.5,
        icon = "data/textures/icons/AscendantMatter.png",
        illegal = true,
        dangerous = true,
        tags = {ascendant = true}
    })
    cv_goods.registerGood({
        name = "Eclipse Datacore",
        description = "An encrypted quantum datacore extracted from a high-ranking Eclipse vessel.",
        price = 1000000,
        size = 5.0,
        icon = "data/textures/icons/EclipseDatacore.png",
        illegal = true,
        tags = {ascendant = true}
    })
    cv_goods.registerGood({
        name = "Ascendant Scrap",
        description = "Failed remnants of an Ascendant forging process. Highly sought after by underground tech brokers.",
        price = 100000,
        size = 1.0,
        icon = "data/textures/icons/AscendantScrap.png",
        illegal = true,
        tags = {ascendant = true}
    })
end

-- Writing directly to entity.damageMultiplier is silently discarded by the C++ engine with no
-- error (see the Modding Codex's entity.damageMultiplier correction). The actual fix is scaling
-- FireRate as a DPS proxy -- but this used addMultiplyableBias, not addBaseMultiplier, which this
-- same bug pattern has already been found and fixed for elsewhere in this exact mod (see
-- Changelog.md's "World-Eater DPS Scaling Desync", "Ascendant Gateway DPS Scaling Desync", and
-- "Ascendant Relic Math & API Desync" entries): addMultiplyableBias is confirmed (vanilla
-- behemothcarriersystem.lua: addMultiplyableBias for a flat +N count vs addBaseMultiplier for a
-- genuine percentage bonus) to be the ADDITIVE-bias primitive, not the multiplicative one --
-- exactly the "flat addition instead of a real percentage boost, resulting in negligible scaling"
-- shape those three entries describe. This function (the single shared damage-scaling path for
-- every Eclipse ship in the mod) had the identical bug and was missed by all three prior fixes.
-- The (factor - 1.0) converts a multiplier (e.g. 2.0x) to a bias delta (e.g. +1.0), which is the
-- correct convention for addBaseMultiplier too (0.3 -> 1.3x, confirmed against ca_station_overdrive.lua's
-- restore() and vanilla batterybooster.lua's percentage-bonus usage).
-- Keys are intentionally not stored since these buffs are permanent until the ship is destroyed.
function EclipseGenerator.applyDamageMultiplier(entity, factor)
    entity:addBaseMultiplier(StatsBonuses.FireRate, factor - 1.0)
end

-- Eclipse Remnant Escalation: a long-running save that keeps defeating World-Eaters and Citadels
-- would otherwise plateau at the same difficulty forever. Each confirmed kill (tracked in
-- ca_world_eater_manager.lua's cancelEvent and ca_citadel_loot.lua's onDestroyed) adds to a score,
-- and every 10 points raises the Remnant Tier by one, capped at 5. World-Eater kills count for more
-- since they're the rarer, harder milestone.
local REMNANT_SCORE_PER_TIER = 10
local REMNANT_MAX_TIER = 5

function EclipseGenerator.getRemnantTier()
    local worldEatersKilled = Server():getValue("eclipse_world_eaters_killed") or 0
    local citadelsKilled = Server():getValue("eclipse_citadels_killed") or 0
    local score = worldEatersKilled * 3 + citadelsKilled
    return math.min(REMNANT_MAX_TIER, math.floor(score / REMNANT_SCORE_PER_TIER))
end

-- Called after eclipse_world_eaters_killed/eclipse_citadels_killed is incremented, to broadcast a
-- one-time announcement whenever the tier actually goes up (not on every kill).
function EclipseGenerator.checkRemnantEscalation()
    local tier = EclipseGenerator.getRemnantTier()
    local announcedTier = Server():getValue("eclipse_remnant_tier_announced") or 0
    if tier <= announcedTier then return end

    Server():setValue("eclipse_remnant_tier_announced", tier)
    Server():broadcastChatMessage("The Eclipse", 2, "Remnant Escalation Protocol Tier " .. tier .. " engaged. Surviving forces have adapted.")

    local cv_news = include("cosmicvaultnews")
    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "GALACTIC THREAT: Eclipse Remnants Adapt",
            content = "Every World-Eater and Citadel destroyed has forced the Eclipse's surviving remnants to compensate. Surviving Eclipse superweapons are now measurably stronger and more frequent than before (Remnant Tier " .. tier .. ").",
            category = "Galactic Dread"
        })
    end
end

-- Applied on top of an entity's existing multipliers (World-Eaters, Citadels), a modest additional
-- layer per Remnant Tier so a mature save's superweapons keep pace with how many the players have
-- already cleared, without dwarfing the base tuning the way a multiplicative re-scale would.
function EclipseGenerator.applyRemnantScaling(entity)
    local tier = EclipseGenerator.getRemnantTier()
    if tier <= 0 then return end

    entity:addBaseMultiplier(StatsBonuses.ShieldDurability, tier * 0.15) -- +15% shields per tier
    local hullDurability = Durability(entity.id)
    hullDurability.maxDurabilityFactor = hullDurability.maxDurabilityFactor + (tier * 0.10) -- +10% hull per tier
    EclipseGenerator.applyDamageMultiplier(entity, 1.0 + tier * 0.10) -- +10% damage per tier
end

function EclipseGenerator.getFaction()
    local name = "The Eclipse"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
        faction.initialRelations = -100000
        faction.initialRelationsToPlayer = -100000
        faction.staticRelationsToPlayers = true
        faction.description = "A sentient algorithmic plague that propagates through the multiverse. Its sole directive is to seek out complex, chaotic life and 'sanitize' it, reducing entire universes to a state of perfect, sterile order."

        for trait, value in pairs(faction:getTraits()) do
            faction:setTrait(trait, 0)
        end
        faction:setTrait("aggressive", 1)
        faction:setTrait("brave", 1)
        faction:setTrait("careful", 0)
        faction:setTrait("peaceful", 0)
        faction:setTrait("trusting", 0)
        faction:setTrait("opportunistic", 0)
    end

    faction.initialRelationsToPlayer = -100000
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    -- Several other Cosmic mods (Cosmic Overhaul's tradecommand.lua, Cosmic Vault's
    -- cv_weather_controller.lua/cv_weather_debuff.lua, Cosmic War's cosmicwartraits.lua and
    -- siegeevent.lua) all identify the Eclipse via "faction.name == 'The Eclipse' or
    -- faction:getValue('is_eclipse')" - a translated-name-safe fallback. Nothing in the codebase
    -- ever actually set this value, so the fallback was permanently dead: if this mod ever ships a
    -- translation entry for "The Eclipse" (making %_T above return a localized name), every one of
    -- those name-equality checks would silently stop matching the real Eclipse faction. Setting it
    -- here, on every call, closes that gap for free since it's purely additive and idempotent.
    faction:setValue("is_eclipse", true)

    return faction
end

-- Returns the standard physical ship volume for this sector.
-- IMPORTANT: We wrap Sector() in a `pcall` fallback. If this generator is called globally
-- by `server.lua` or the conquest manager where Sector() is invalid, it defaults to (0, 0).
function EclipseGenerator.getShipVolume(x, y)
    if not x or not y then
        local sector = Sector()
        if sector then
            x, y = sector:getCoordinates()
        else
            x, y = 0, 0
        end
    end
    local volume = Balancing_GetSectorShipVolume(x, y)

    -- Adaptive Eclipse Scaling based on highest player Ascendancy Tier
    local maxTier = 0
    local cv_buffs = include("cosmicvaultbuffs")
    if cv_buffs.getGlobalTier then
        for _, p in pairs({Server():getOnlinePlayers()}) do
            local tier = cv_buffs.getGlobalTier(p.index)
            if tier > maxTier then maxTier = tier end
        end
    end

    local eclipseScale = math.min(3.0, 1.0 + (maxTier * 0.5)) -- +50% size/durability per tier, capped at 3.0x

    return volume * 2.5 * eclipseScale
end

function EclipseGenerator.addTurrets(ship, numTurrets)
    -- which is the starting region and generates Titanium/Naonite-tier weapons.
    -- Always pass the current sector coordinates so turrets scale to the correct material tier.
    local cx, cy = 0, 0
    local sector = Sector()
    -- SectorTurretGenerator's constructor only takes a single seed argument (see
    -- data/scripts/lib/sectorturretgenerator.lua's `local function new(seed)`), so passing (cx, cy)
    -- silently drops cy and seeds purely off cx, so every sector sharing that X coordinate would
    -- roll identical turrets. Use the sector's own unique seed instead, matching the correct pattern
    -- already used everywhere else this generator is constructed in this mod (ca_worldeater_behavior.lua,
    -- ca_citadel_loot.lua, ascendancysiege.lua). cx/cy are still needed separately below, for
    -- generateArmed()'s own distance-from-center weapon-tier calculation.
    local seed = sector and sector.seed or nil
    if sector then
        cx, cy = sector:getCoordinates()
    end
    local generator = SectorTurretGenerator(seed)
    generator.coaxialAllowed = false

    -- Try to use Starfall if available (soft dependency — no crash if not installed)
    local status, starfall = pcall(include, "starfall")

    numTurrets = numTurrets or 20

    -- Build a pool of turrets scaled to the sector location
    for i = 1, numTurrets do
        local turret
        -- If Starfall is installed, 50% chance to use a Starfall legendary for this slot
        if status and starfall and starfall.generateLegendary and random():getFloat() > 0.5 then
            turret = starfall.generateLegendary()
        else
            -- Generate a max-rarity turret appropriate for the current sector's material tier
            turret = generator:generateArmed(cx, cy, 0, Rarity(RarityType.Legendary))
        end

        -- Force maximum stats on top of generation: Eclipse weapons are elite.
        -- NOTE: TurretTemplate has no writable "tech" property (see Avorion Stubs/TurretTemplate.lua --
        -- only the read-only averageTech/maxTech exist). Tech level is baked in at generation time by
        -- generateArmed()'s (cx, cy) distance-from-center argument above, not settable after the fact.
        -- The line that used to sit here ("turret.tech = 52") crashed addTurrets() on every single call.
        -- Because Lua errors propagate up through the whole call chain, this didn't just skip the rest
        -- of createShip() -- it aborted whatever called createShip()/createInterceptor() too. In
        -- ca_story1_awakening.lua's Phase 3 (the ambush), that call sits inside a `for i = 1, 3 do`
        -- loop in onBeginServer(), before the line that sets mission.data.custom.bossSpawned = true;
        -- the crash meant that flag was never set, and Phase 3's updateServer() bails out immediately
        -- whenever it's unset -- so the mission got permanently stuck with no ambush ships and no way
        -- to progress. Removed; the elite feel is still delivered by the Legendary rarity roll and the
        -- flat weapon-stat bonuses below.
        -- Stormbox: This comment will retain here for future reference.
        turret.turningSpeed = math.max(turret.turningSpeed, 3.0)

        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, weapon in pairs(weapons) do
            weapon.damage = weapon.damage * 1.5     -- 50% flat damage bonus over standard legendary
            weapon.fireRate = weapon.fireRate * 1.25 -- 25% faster fire rate
            weapon.reach = weapon.reach * 1.5       -- 50% longer range
            weapon.accuracy = 1.0                   -- Perfect accuracy — Eclipse never misses
            turret:addWeapon(weapon)
        end

        ShipUtility.addTurretsToCraft(ship, turret, 1)
    end
end

-- Which of the four class-specific abilities (ca_eclipse_abilities.lua) each hull type gets,
-- keyed by the real planType instead of a post-hoc title-string match. Previously
-- EclipseAbilities.initialize() derived this by pattern-matching entity.title/translatedTitle at
-- attach time -- but createShip() below attaches ca_eclipse_abilities.lua BEFORE any caller except
-- the Harbinger/Obliterator branch sets the ship's real title, so every other class read the
-- placeholder "Eclipse Nullifier" title, which matched none of the four patterns, and silently got
-- no special ability for its entire lifetime. Keying on planType removes the timing dependency
-- entirely instead of just reordering two lines. Matches the keyword lists ca_eclipse_abilities.lua
-- used to match against exactly (its "cruiser"/"dreadnought" keywords are dropped here since no
-- ship in this table was ever titled either word -- dead patterns, not a real class).
local ABILITY_CLASS = {
    ca_voidweaver  = {siphon = true, singularity = true},
    ca_juggernaut  = {siphon = true, singularity = true},
    ca_harbinger   = {siphon = true, singularity = true},
    ca_worldeater  = {siphon = true, singularity = true},
    ca_phantom     = {ethereal = true},
    ca_interceptor = {ethereal = true},
    ca_defiler     = {adaptive = true},
    ca_singularity = {adaptive = true},
}

function EclipseGenerator.createShip(position, planType, volumeScale, turretCount)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()

    local planPath = "data/plans/eclipse/" .. (planType or "ca_obliterator") .. ".xml"
    local plan = LoadPlanFromFile(planPath)
    -- LoadPlanFromFile's actual failure return is not documented (no description on either the
    -- stub or the raw HTML docs), and vanilla's own factionpacks.lua -- the only vanilla script
    -- that checks this call's result at all -- uses `if not valid(plan) then`, not `if not plan
    -- then`, which is evidence the failure case may hand back a non-nil-but-invalid object rather
    -- than a real nil. Currently dormant here since every data/plans/eclipse/*.xml this mod ships
    -- exists on disk, but a plain `not plan` check would silently miss the fallback entirely if a
    -- plan file is ever renamed or deleted, passing an invalid plan straight into createShip/
    -- createStation. valid() is safe to call on nil too, so this is a strict correctness upgrade.
    if not valid(plan) then
        -- Fallback if not found
        local x, y = 0, 0
        local sector = Sector()
        if sector then x, y = sector:getCoordinates() end
        local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
        local material = Material(getValueFromDistribution(probabilities))
        plan = PlanGenerator.makeXsotanShipPlan(EclipseGenerator.getShipVolume(x, y) * (volumeScale or 1.0), material)
    end

    -- Scale the plan volume to match the target Eclipse ship size
    local volume = EclipseGenerator.getShipVolume() * (volumeScale or 1.0)
    local currentVolume = plan.volume
    if currentVolume > 0 then
        local scale = (volume / currentVolume) ^ (1/3)
        plan:scale(vec3(scale, scale, scale))
    end

    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)
    -- Sector:createShip()'s failure return isn't documented as impossible (see the identical
    -- valid(plan) writeup above), and every caller of this shared factory indexes the result
    -- unconditionally -- including the mission files' own "if boss then bossSpawned = true end"
    -- guards, which never get a chance to run because a nil here throws one call frame earlier,
    -- inside addTurrets() below. Fail fast and return nil so every caller's own nil-check (already
    -- present) actually has something to guard against.
    if not ship then return nil end

    EclipseGenerator.addTurrets(ship, turretCount or 15)

    if planType == "ca_obliterator" then
        ship:setTitle("Eclipse Obliterator"%_T, {})
    elseif planType == "ca_harbinger" then
        ship:setTitle("Eclipse Harbinger"%_T, {})
    else
        ship:setTitle("Eclipse Nullifier"%_T, {})
    end

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)
    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("utility/aiundockable.lua")

    -- If it's a Harbinger, inject Ascendant Multipliers
    if planType == "ca_harbinger" then
        ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 10.0) -- +1000% Shields (Nerfed to preserve World-Eater supremacy)
        EclipseGenerator.applyDamageMultiplier(ship, 10.0) -- 10x/+900% Damage (compensated for lost turrets)
        ship:addBaseMultiplier(StatsBonuses.FireRate, 1.0) -- +100% Fire Rate

        -- NEMESIS SYSTEM
        local nemesisResist = Server():getValue("eclipse_nemesis_resist")
        if nemesisResist then
            ship:addScriptOnce("data/scripts/entity/ca_nemesis_resist.lua", nemesisResist)
        end
        ship:addScriptOnce("data/scripts/entity/ca_nemesis_system.lua")
    end

    Boarding(ship).boardable = false
    local abilities = ABILITY_CLASS[planType] or {}
    -- Multiple extra args after the path ARE forwarded to initialize() -- confirmed live in this
    -- same codebase (ascendancysiege.lua's own AscendancySiege.initialize(t, ownerIndex) receives
    -- two from Sector():addScriptOnce("events/ascendancysiege.lua", currentTier, owner.index)).
    ship:addScriptOnce("data/scripts/entity/ca_eclipse_abilities.lua", abilities.siphon or false, abilities.ethereal or false, abilities.adaptive or false, abilities.singularity or false)

    return ship
end

function EclipseGenerator.createWorldEater(position)
    -- The World-Eater is a massive Pyramid
    local ship = EclipseGenerator.createShip(position, "ca_worldeater", 150.0, 150)
    -- Hyphenated to match ca_eclipse_abilities.lua's "world%-eater" classification pattern (a
    -- literal hyphen in a Lua pattern) and the WIKI's own hyphenated "World-Eater" spelling used
    -- everywhere else. Before this fix the un-hyphenated title meant the pattern could never match,
    -- so the raid final boss never got Void Siphon Aura or Singularity Implosion.
    ship:setTitle("Eclipse World-Eater"%_T, {})

    -- The World Eater gets an extra multiplier
    -- Raised from 3.0/15.0 (4x/16x) to 4.0/18.0 (4x/19x) as part of re-establishing the World-Eater
    -- as strictly the strongest single thing in the mod: removing eclipse_boss_scaling.lua's
    -- double-stack from Harbinger/Citadel (see createShip/createStation above) fixed the stacking
    -- bug, but the World-Eater's own baseline still needed a modest bump to clear both of their own
    -- standalone numbers (Harbinger 11x/11x, Citadel's retuned 17x/5x). Its volume scale (150.0, vs.
    -- Citadel's 8.0 and Harbinger's 1.0) already gives it an order-of-magnitude bigger raw hull pool
    -- on top of this.
    EclipseGenerator.applyDamageMultiplier(ship, 4.0)
    ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 18.0) -- Massive shields for the raid boss

    -- -90% Speed as per design
    ship:addBaseMultiplier(StatsBonuses.Velocity, -0.9)

    -- Eclipse Remnant Escalation: a modest extra layer per Remnant Tier, on top of the base
    -- multipliers above and the separate per-fight multiplayer scaling applied later by
    -- EclipseGenerator.applyWorldEaterMultiplayerScaling.
    EclipseGenerator.applyRemnantScaling(ship)

    -- Add the boss behavior script which handles Tethers, EMPs, and Gravity Anomalies
    ship:addScriptOnce("data/scripts/entity/ca_worldeater_behavior.lua")

    return ship
end

-- Multiplayer/Alliance Scaling: the World-Eater's base stats above are tuned around a single
-- defender. A whole alliance converging on the same fight brings far more simultaneous DPS, so
-- without this the boss would fold in seconds against a large group while still being an
-- appropriate multi-minute fight solo. Called separately from every spawn path (the natural
-- Doomsday Event, the player-summoned Raid Boss) right after createWorldEater(), rather than
-- folded into createWorldEater() itself, since it needs to read the sector's current player
-- count at the moment of the actual fight, not at plan-generation time.
function EclipseGenerator.applyWorldEaterMultiplayerScaling(ship)
    local defenders = {Sector():getPlayers()}
    local n = math.max(1, #defenders)
    -- Diminishing returns instead of a flat per-extra-defender rate: the original linear formula
    -- (+150%/+75%/+30% per extra defender) grew unboundedly, reaching +1050%/+525%/+210% at 8
    -- simultaneous defenders and getting worse without limit on a busy dedicated server -- steep
    -- enough to approach "unkillable," not just "harder." 2*(sqrt(n)-1) tracks the old linear rate
    -- closely for the first couple of extra defenders (a duo fight barely changes) and tapers hard
    -- after that (8 players: +549%/+274%/+110%; 20 players: +1041%/+520%/+208% and still slowly
    -- climbing), so a large raid still faces real, growing difficulty without a hard wall.
    local scale = 2.0 * (math.sqrt(n) - 1.0)
    if scale > 0 then
        -- Shields scale via the StatsBonuses system (same mechanism as every other Eclipse buff).
        ship:addBaseMultiplier(StatsBonuses.ShieldDurability, scale * 1.5)
        -- There is no StatsBonuses.HullDurability entry (the enum only goes up to FireRate=40). Hull HP
        -- is instead scaled through the Durability component's maxDurabilityFactor, additive on top of
        -- whatever the hull's base volume/material already grants (confirmed against vanilla usage in
        -- data/scripts/lib/spawnutility.lua: "durability.maxDurabilityFactor = durability.maxDurabilityFactor + hpFactor").
        local hullDurability = Durability(ship.id)
        hullDurability.maxDurabilityFactor = hullDurability.maxDurabilityFactor + (scale * 0.75)
        EclipseGenerator.applyDamageMultiplier(ship, 1.0 + scale * 0.3)
    end
end

function EclipseGenerator.createCarrier(position)
    local ship = EclipseGenerator.createShip(position, "ca_voidweaver")
    ship:setTitle("Eclipse Void-Weaver"%_T, {})

    ship:addScriptOnce("ai/carrier.lua")
    -- ShipUtility.addCarrierEquipment handles the hangar check internally.
    -- Calling it directly is the correct vanilla pattern.
    ShipUtility.addCarrierEquipment(ship, 30)

    return ship
end

function EclipseGenerator.createAssassin(position)
    local ship = EclipseGenerator.createShip(position, "ca_phantom")
    ship:setTitle("Eclipse Phantom"%_T, {})

    EclipseGenerator.applyDamageMultiplier(ship, 3.0) -- 3x/+200% burst damage
    ship:addBaseMultiplier(StatsBonuses.Velocity, 3.0) -- Fast turning/moving

    return ship
end

function EclipseGenerator.createArtillery(position)
    local ship = EclipseGenerator.createShip(position, "ca_singularity")
    ship:setTitle("Eclipse Singularity"%_T, {})

    ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 0.5) -- 50% weaker shields

    -- Multiply reach of generated weapons
    for _, turret in pairs({ship:getTurrets()}) do
        local weaponsCmp = Weapons(turret.id)
        if weaponsCmp then
            local weapons = {weaponsCmp:getWeapons()}
            weaponsCmp:clearWeapons()
            for _, weapon in pairs(weapons) do
                weapon.reach = weapon.reach * 3.0 -- Extreme range
                weaponsCmp:addWeapon(weapon)
            end
        end
    end

    return ship
end

function EclipseGenerator.createJuggernaut(position)
    local ship = EclipseGenerator.createShip(position, "ca_juggernaut")
    ship:setTitle("Eclipse Juggernaut"%_T, {})

    ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 2.0) -- +200% Shields
    ship:addBaseMultiplier(StatsBonuses.Velocity, -0.5) -- -50% Speed
    -- Add loot script for Eclipse Datacore
    ship:addScriptOnce("data/scripts/entity/ca_juggernaut_loot.lua")

    return ship
end

function EclipseGenerator.createInterceptor(position)
    local ship = EclipseGenerator.createShip(position, "ca_interceptor")
    ship:setTitle("Eclipse Interceptor"%_T, {})

    ship:addBaseMultiplier(StatsBonuses.Velocity, 1.5) -- +150% Speed
    -- applyDamageMultiplier(entity, factor) takes a TOTAL multiplier (e.g. 0.8 = 80% = -20%), not
    -- the delta itself -- it internally computes factor - 1.0. Passing -0.2 directly drove the
    -- final FireRate multiplier to 1 + (-0.2 - 1.0) = -0.2, a negative multiplier, instead of the
    -- intended 0.8 (1 + (0.8 - 1.0) = 0.8). Interceptors were dealing near-zero/negative damage.
    EclipseGenerator.applyDamageMultiplier(ship, 0.8) -- -20% Damage

    return ship
end

function EclipseGenerator.createHarvester(position)
    local ship = EclipseGenerator.createShip(position, "ca_harvester")
    ship:setTitle("Eclipse Harvester"%_T, {})

    ship:addBaseMultiplier(StatsBonuses.CargoHold, 5.0) -- +500% Cargo
    -- Changelog.md advertises "Ascendant Matter (dropped by Harvesters)" as a headline feature of
    -- the Ascendant Matter arms race, but this attach line was missing -- ca_harvester_loot.lua
    -- existed in the mod with no addScriptOnce call anywhere referencing it, so Harvesters were
    -- never actually dropping anything. Juggernauts get the equivalent wire-up two functions below
    -- (ca_juggernaut_loot.lua); this brings Harvester in line with that sibling pattern.
    ship:addScriptOnce("data/scripts/entity/ca_harvester_loot.lua")

    return ship
end

function EclipseGenerator.createDefiler(position)
    local ship = EclipseGenerator.createShip(position, "ca_defiler")
    ship:setTitle("Eclipse Defiler"%_T, {})

    EclipseGenerator.applyDamageMultiplier(ship, 1.5) -- 1.5x/+50% Damage

    return ship
end

function EclipseGenerator.createStation(position)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()

    local planPath = "data/plans/eclipse/ca_citadel.xml"
    local plan = LoadPlanFromFile(planPath)
    -- See EclipseGenerator.createShip's identical check above for why this is valid(plan), not a
    -- plain nil check.
    if not valid(plan) then
        local x, y = 0, 0
        local sector = Sector()
        if sector then x, y = sector:getCoordinates() end
        local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
        local material = Material(getValueFromDistribution(probabilities))
        plan = PlanGenerator.makeXsotanShipPlan(EclipseGenerator.getShipVolume(x, y) * 5, material)
    end

    -- Scale the plan volume to match the target Citadel size (8x a standard Eclipse ship)
    local volume = EclipseGenerator.getShipVolume() * 8
    local currentVolume = plan.volume
    if currentVolume > 0 then
        local scale = (volume / currentVolume) ^ (1/3)
        plan:scale(vec3(scale, scale, scale))
    end

    local station = Sector():createStation(faction, plan, position)
    -- See the identical guard in createShip() above for why this can't be skipped.
    if not station then return nil end

    EclipseGenerator.addTurrets(station, 40)
    station:setTitle("Eclipse Citadel"%_T, {})

    station.crew = station.idealCrew
    station.shieldDurability = station.shieldMaxDurability

    AddDefaultStationScripts(station)
    station:addScriptOnce("utility/aiundockable.lua")

    -- Retuned from 50.0 (51x -- exceeded even the World-Eater's own baseline on its own, before
    -- eclipse_boss_scaling.lua's now-removed double-stack made it worse) down to 16.0 (17x), just
    -- below the World-Eater's redesigned 19x floor. The Citadel is still an appropriately massive
    -- siege objective (8x volume, 4 orbital platforms, the Lockdown Matrix trapping attackers in
    -- the sector) -- it just no longer outguns the raid boss it's supposed to answer to.
    station:addBaseMultiplier(StatsBonuses.ShieldDurability, 16.0)
    EclipseGenerator.applyDamageMultiplier(station, 5.0)
    -- Eclipse Remnant Escalation: see EclipseGenerator.applyRemnantScaling.
    EclipseGenerator.applyRemnantScaling(station)
    station:addScriptOnce("data/scripts/entity/ca_citadel_loot.lua")

    -- The Lockdown Matrix: Prevents players from jumping out while the Citadel is alive (Paced)
    station:addScriptOnce("data/scripts/entity/ca_citadel_blocker.lua")

    Boarding(station).boardable = false

    return station
end

return EclipseGenerator

