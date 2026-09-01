package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("utility")
include ("stringutility")
include ("defaultscripts")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipUtility = include ("shiputility")
local PlanGenerator = include ("plangenerator")

local EclipseGenerator = {}

-- All writes to it are silently discarded by the C++ engine with no error.
-- CORRECT approach: addMultiplyableBias on StatsBonuses.FireRate acts as a DPS scalar. However further research on this must be done.
-- The (factor - 1.0) converts a multiplier (e.g. 2.0x) to a bias delta (e.g. +1.0).
-- Keys are intentionally not stored since these buffs are permanent until the ship is destroyed.
function EclipseGenerator.applyDamageMultiplier(entity, factor)
    entity:addMultiplyableBias(StatsBonuses.FireRate, factor - 1.0)
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

    entity:addMultiplyableBias(StatsBonuses.ShieldDurability, tier * 0.15) -- +15% shields per tier
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

function EclipseGenerator.createShip(position, planType, volumeScale, turretCount)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()

    local planPath = "data/plans/eclipse/" .. (planType or "ca_obliterator") .. ".xml"
    local plan = LoadPlanFromFile(planPath)
    if not plan then
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
        ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 10.0) -- +1000% Shields (Nerfed to preserve World-Eater supremacy)
        EclipseGenerator.applyDamageMultiplier(ship, 10.0) -- +1000% Damage (compensated for lost turrets)
        ship:addMultiplyableBias(StatsBonuses.FireRate, 1.0) -- +100% Fire Rate
        ship:addScriptOnce("entity/eclipse_boss_scaling.lua")

        -- NEMESIS SYSTEM
        local nemesisResist = Server():getValue("eclipse_nemesis_resist")
        if nemesisResist then
            ship:addScriptOnce("data/scripts/entity/ca_nemesis_resist.lua", nemesisResist)
        end
        ship:addScriptOnce("data/scripts/entity/ca_nemesis_system.lua")
    end

    Boarding(ship).boardable = false
    ship:addScriptOnce("data/scripts/entity/ca_eclipse_abilities.lua")

    return ship
end

function EclipseGenerator.createWorldEater(position)
    -- The World-Eater is a massive Pyramid
    local ship = EclipseGenerator.createShip(position, "ca_worldeater", 150.0, 150)
    ship:setTitle("Eclipse World Eater"%_T, {})

    -- The World Eater gets an extra multiplier
    EclipseGenerator.applyDamageMultiplier(ship, 3.0)
    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 15.0) -- Massive shields for the raid boss

    -- -90% Speed as per design
    ship:addMultiplyableBias(StatsBonuses.Velocity, -0.9)

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
    local extraDefenders = math.max(0, #defenders - 1)
    if extraDefenders > 0 then
        -- Shields scale via the StatsBonuses system (same mechanism as every other Eclipse buff).
        ship:addMultiplyableBias(StatsBonuses.ShieldDurability, extraDefenders * 1.5) -- +150% shields per extra defender
        -- There is no StatsBonuses.HullDurability entry (the enum only goes up to FireRate=40). Hull HP
        -- is instead scaled through the Durability component's maxDurabilityFactor, additive on top of
        -- whatever the hull's base volume/material already grants (confirmed against vanilla usage in
        -- data/scripts/lib/spawnutility.lua: "durability.maxDurabilityFactor = durability.maxDurabilityFactor + hpFactor").
        local hullDurability = Durability(ship.id)
        hullDurability.maxDurabilityFactor = hullDurability.maxDurabilityFactor + (extraDefenders * 0.75) -- +75% hull per extra defender
        EclipseGenerator.applyDamageMultiplier(ship, 1.0 + extraDefenders * 0.3) -- +30% damage per extra defender
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

    EclipseGenerator.applyDamageMultiplier(ship, 3.0) -- +300% burst damage
    ship:addMultiplyableBias(StatsBonuses.Velocity, 3.0) -- Fast turning/moving

    return ship
end

function EclipseGenerator.createArtillery(position)
    local ship = EclipseGenerator.createShip(position, "ca_singularity")
    ship:setTitle("Eclipse Singularity"%_T, {})

    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 0.5) -- 50% weaker shields

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

    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 2.0) -- +200% Shields
    ship:addMultiplyableBias(StatsBonuses.Velocity, -0.5) -- -50% Speed
    -- Add loot script for Eclipse Datacore
    ship:addScriptOnce("data/scripts/entity/ca_juggernaut_loot.lua")

    return ship
end

function EclipseGenerator.createInterceptor(position)
    local ship = EclipseGenerator.createShip(position, "ca_interceptor")
    ship:setTitle("Eclipse Interceptor"%_T, {})

    ship:addMultiplyableBias(StatsBonuses.Velocity, 1.5) -- +150% Speed
    EclipseGenerator.applyDamageMultiplier(ship, -0.2) -- -20% Damage

    return ship
end

function EclipseGenerator.createHarvester(position)
    local ship = EclipseGenerator.createShip(position, "ca_harvester")
    ship:setTitle("Eclipse Harvester"%_T, {})

    ship:addMultiplyableBias(StatsBonuses.CargoHold, 5.0) -- +500% Cargo

    return ship
end

function EclipseGenerator.createDefiler(position)
    local ship = EclipseGenerator.createShip(position, "ca_defiler")
    ship:setTitle("Eclipse Defiler"%_T, {})

    EclipseGenerator.applyDamageMultiplier(ship, 1.5) -- +150% Damage

    return ship
end

function EclipseGenerator.createStation(position)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()

    local planPath = "data/plans/eclipse/ca_citadel.xml"
    local plan = LoadPlanFromFile(planPath)
    if not plan then
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

    EclipseGenerator.addTurrets(station, 40)
    station:setTitle("Eclipse Citadel"%_T, {})

    station.crew = station.idealCrew
    station.shieldDurability = station.shieldMaxDurability

    AddDefaultStationScripts(station)
    station:addScriptOnce("utility/aiundockable.lua")

    station:addMultiplyableBias(StatsBonuses.ShieldDurability, 50.0)
    EclipseGenerator.applyDamageMultiplier(station, 5.0)
    -- Eclipse Remnant Escalation: see EclipseGenerator.applyRemnantScaling.
    EclipseGenerator.applyRemnantScaling(station)
    station:addScriptOnce("entity/eclipse_boss_scaling.lua")
    station:addScriptOnce("data/scripts/entity/ca_citadel_loot.lua")

    -- The Lockdown Matrix: Prevents players from jumping out while the Citadel is alive (Paced)
    station:addScriptOnce("entity/ca_citadel_blocker.lua")

    Boarding(station).boardable = false

    return station
end

return EclipseGenerator

