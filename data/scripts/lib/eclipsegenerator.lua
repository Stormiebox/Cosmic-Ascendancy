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
-- CORRECT approach: addMultiplyableBias on StatsBonuses.FireRate acts as a DPS scalar.
-- The (factor - 1.0) converts a multiplier (e.g. 2.0x) to a bias delta (e.g. +1.0).
-- Keys are intentionally not stored since these buffs are permanent until the ship is destroyed.
function EclipseGenerator.applyDamageMultiplier(entity, factor)
    entity:addMultiplyableBias(StatsBonuses.FireRate, factor - 1.0)
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
        for _, p in pairs({Server():getPlayers()}) do
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
    if sector then
        cx, cy = sector:getCoordinates()
    end
    local generator = SectorTurretGenerator(cx, cy)
    generator.coaxialAllowed = false
    
    -- Try to use Starfall if available (soft dependency — no crash if not installed)
    local status, starfall = pcall(include, "starfall")
    
    local numTurrets = numTurrets or 20
    
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
        
        -- Force maximum stats on top of generation: Eclipse weapons are elite
        turret.tech = 52
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
    
    local planPath = "data/plans/eclipse/" .. (planType or "monolith") .. ".xml"
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

    if planType == "monolith" then
        ship:setTitle("Eclipse Obliterator"%_T, {})
    elseif planType == "obelisk" then
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
    if planType == "obelisk" then
        ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 37.5) -- +3750% Shields
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
    local ship = EclipseGenerator.createShip(position, "pyramid", 150.0, 150)
    ship:setTitle("Eclipse World Eater"%_T, {})
    
    -- The World Eater gets an extra multiplier
    EclipseGenerator.applyDamageMultiplier(ship, 3.0)
    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 15.0) -- Massive shields for the raid boss
    
    -- -90% Speed as per design
    ship:addMultiplyableBias(StatsBonuses.Velocity, -0.9)
    
    -- Add the boss behavior script which handles Tethers, EMPs, and Gravity Anomalies
    ship:addScriptOnce("data/scripts/entity/ca_worldeater_behavior.lua")
    
    return ship
end

function EclipseGenerator.createCarrier(position)
    local ship = EclipseGenerator.createShip(position, "voidweaver")
    ship:setTitle("Eclipse Void-Weaver"%_T, {})
    
    ship:addScriptOnce("ai/carrier.lua")
    -- ShipUtility.addCarrierEquipment handles the hangar check internally.
    -- Calling it directly is the correct vanilla pattern.
    ShipUtility.addCarrierEquipment(ship, 30)
    
    return ship
end

function EclipseGenerator.createAssassin(position)
    local ship = EclipseGenerator.createShip(position, "phantom")
    ship:setTitle("Eclipse Phantom"%_T, {})
    
    EclipseGenerator.applyDamageMultiplier(ship, 3.0) -- +300% burst damage
    ship:addMultiplyableBias(StatsBonuses.Velocity, 3.0) -- Fast turning/moving
    
    return ship
end

function EclipseGenerator.createArtillery(position)
    local ship = EclipseGenerator.createShip(position, "singularity")
    ship:setTitle("Eclipse Singularity"%_T, {})
    
    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 0.5) -- 50% weaker shields
    
    -- Multiply reach of generated weapons
    for _, turret in pairs({ship:getTurrets()}) do
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, weapon in pairs(weapons) do
            weapon.reach = weapon.reach * 3.0 -- Extreme range
            turret:addWeapon(weapon)
        end
    end
    
    return ship
end

function EclipseGenerator.createJuggernaut(position)
    local ship = EclipseGenerator.createShip(position, "juggernaut")
    ship:setTitle("Eclipse Juggernaut"%_T, {})
    
    ship:addMultiplyableBias(StatsBonuses.ShieldDurability, 2.0) -- +200% Shields
    ship:addMultiplyableBias(StatsBonuses.Velocity, -0.5) -- -50% Speed
    -- Add loot script for Eclipse Datacore
    ship:addScriptOnce("data/scripts/entity/ca_juggernaut_loot.lua")
    
    return ship
end

function EclipseGenerator.createInterceptor(position)
    local ship = EclipseGenerator.createShip(position, "interceptor")
    ship:setTitle("Eclipse Interceptor"%_T, {})
    
    ship:addMultiplyableBias(StatsBonuses.Velocity, 1.5) -- +150% Speed
    EclipseGenerator.applyDamageMultiplier(ship, -0.2) -- -20% Damage
    
    return ship
end

function EclipseGenerator.createHarvester(position)
    local ship = EclipseGenerator.createShip(position, "harvester")
    ship:setTitle("Eclipse Harvester"%_T, {})
    
    ship:addMultiplyableBias(StatsBonuses.CargoHold, 5.0) -- +500% Cargo
    
    return ship
end

function EclipseGenerator.createDefiler(position)
    local ship = EclipseGenerator.createShip(position, "defiler")
    ship:setTitle("Eclipse Defiler"%_T, {})
    
    EclipseGenerator.applyDamageMultiplier(ship, 1.5) -- +150% Damage
    
    return ship
end

function EclipseGenerator.createStation(position)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()
    
    local planPath = "data/plans/eclipse/citadel.xml"
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
    station:addScriptOnce("entity/eclipse_boss_scaling.lua")
    station:addScriptOnce("data/scripts/entity/ca_citadel_loot.lua")
    
    -- The Lockdown Matrix: Prevents players from jumping out while the Citadel is alive (Paced)
    station:addScriptOnce("entity/ca_citadel_blocker.lua")
    
    Boarding(station).boardable = false
    
    return station
end

return EclipseGenerator
