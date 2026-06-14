package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("utility")
include ("stringutility")
include ("defaultscripts")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipUtility = include ("shiputility")
local PlanGenerator = include ("plangenerator")
include("weapontype")

local EclipseGenerator = {}

function EclipseGenerator.getFaction()
    local name = "The Eclipse"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
        faction.initialRelations = -100000
        faction.initialRelationsToPlayer = -100000
        faction.staticRelationsToPlayers = true

        for trait, value in pairs(faction:getTraits()) do
            faction:setTrait(trait, 0)
        end
        faction:setTrait("aggressive", 1)
        faction:setTrait("brave", 1)
    end

    faction.initialRelationsToPlayer = -100000
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function EclipseGenerator.getShipVolume()
    local sector = Sector()
    local volume = Balancing_GetSectorShipVolume(sector:getCoordinates())
    return volume * 2.5 -- Eclipse are significantly larger
end

function EclipseGenerator.addTurrets(ship, numTurrets)
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false
    
    -- Try to use Starfall if available
    local status, starfall = pcall(require, "starfall")
    
    local numTurrets = numTurrets or 20
    local turretsAdded = 0
    
    -- We want to add multiple turrets to the ship. Let's create a pool of possible turrets.
    for i = 1, numTurrets do
        local turret
        -- If Starfall is installed, there's a 50% chance to pick a Starfall weapon for this slot
        if status and starfall and starfall.generateLegendary and random():getFloat() > 0.5 then
            turret = starfall.generateLegendary()
        else
            -- Otherwise, pick a Max Tech Vanilla Legendary Turret
            turret = generator:generateArmed(0, 0, 0, Rarity(RarityType.Legendary))
        end
        
        -- FORCE MAXIMUM STATS, TECH, AND RARITY
        turret.tech = 52
        turret.turningSpeed = math.max(turret.turningSpeed, 3.0)
        
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, weapon in pairs(weapons) do
            weapon.damage = weapon.damage * 1.5 -- 50% flat damage boost over standard legendary
            weapon.fireRate = weapon.fireRate * 1.25 -- 25% faster firing
            weapon.reach = weapon.reach * 1.5 -- 50% more range
            weapon.accuracy = 1.0 -- 100% perfect accuracy
            turret:addWeapon(weapon)
        end
        
        ShipUtility.addTurretsToCraft(ship, turret, 1)
    end
end

function EclipseGenerator.createShip(position, planType)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()
    
    local planPath = "data/plans/eclipse/" .. (planType or "monolith") .. ".xml"
    local plan = LoadPlanFromFile(planPath)
    if not plan then
        -- Fallback if not found
        local x, y = Sector():getCoordinates()
        local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
        local material = Material(getValueFromDistribution(probabilities))
        plan = PlanGenerator.makeXsotanShipPlan(EclipseGenerator.getShipVolume(), material)
    end
    
    -- Scale the plan
    local volume = EclipseGenerator.getShipVolume()
    local currentVolume = plan.volume
    if currentVolume > 0 then
        local scale = math.pow(volume / currentVolume, 1/3)
        plan:scale(vec3(scale, scale, scale))
    end
    
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)
    
    EclipseGenerator.addTurrets(ship, 15)

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
        ship:addMultiplyableFactor(StatsBonuses.ShieldDurability, 37.5) -- +3750% Shields
        ship:addMultiplyableFactor(StatsBonuses.Damage, 5.0) -- +500% Damage
        ship:addMultiplyableFactor(StatsBonuses.ArmedTurrets, 75.0) -- +75 Turrets
        ship:addScriptOnce("entity/eclipse_boss_scaling.lua")
    end

    Boarding(ship).boardable = false

    return ship
end

function EclipseGenerator.createCarrier(position)
    local ship = EclipseGenerator.createShip(position, "voidweaver")
    ship:setTitle("Eclipse Void-Weaver"%_T, {})
    
    ship:addScriptOnce("ai/carrier.lua")
    local hangar = Hangar(ship)
    if hangar then
        ShipUtility.addCarrierEquipment(ship, 30)
    end
    
    return ship
end

function EclipseGenerator.createAssassin(position)
    local ship = EclipseGenerator.createShip(position, "phantom")
    ship:setTitle("Eclipse Phantom"%_T, {})
    
    ship:addScriptOnce("enemies/blinker.lua")
    ship:addMultiplyableFactor(StatsBonuses.Damage, 3.0) -- +300% burst damage
    ship:addMultiplyableFactor(StatsBonuses.Velocity, 3.0) -- Fast turning/moving
    
    return ship
end

function EclipseGenerator.createArtillery(position)
    local ship = EclipseGenerator.createShip(position, "singularity")
    ship:setTitle("Eclipse Singularity"%_T, {})
    
    ship:addMultiplyableFactor(StatsBonuses.ShieldDurability, 0.5) -- 50% weaker shields
    
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
    
    ship:addMultiplyableFactor(StatsBonuses.ShieldDurability, 2.0) -- +200% Shields
    ship:addMultiplyableFactor(StatsBonuses.Velocity, -0.5) -- -50% Speed
    
    return ship
end

function EclipseGenerator.createInterceptor(position)
    local ship = EclipseGenerator.createShip(position, "interceptor")
    ship:setTitle("Eclipse Interceptor"%_T, {})
    
    ship:addMultiplyableFactor(StatsBonuses.Velocity, 1.5) -- +150% Speed
    ship:addMultiplyableFactor(StatsBonuses.Damage, -0.2) -- -20% Damage
    
    return ship
end

function EclipseGenerator.createHarvester(position)
    local ship = EclipseGenerator.createShip(position, "harvester")
    ship:setTitle("Eclipse Harvester"%_T, {})
    
    ship:addMultiplyableFactor(StatsBonuses.CargoCapacity, 5.0) -- +500% Cargo
    
    return ship
end

function EclipseGenerator.createDefiler(position)
    local ship = EclipseGenerator.createShip(position, "defiler")
    ship:setTitle("Eclipse Defiler"%_T, {})
    
    ship:addMultiplyableFactor(StatsBonuses.Damage, 1.5) -- +150% Damage
    
    return ship
end

function EclipseGenerator.createStation(position)
    position = position or Matrix()
    local faction = EclipseGenerator.getFaction()
    
    local planPath = "data/plans/eclipse/citadel.xml"
    local plan = LoadPlanFromFile(planPath)
    if not plan then
        local x, y = Sector():getCoordinates()
        local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
        local material = Material(getValueFromDistribution(probabilities))
        plan = PlanGenerator.makeXsotanShipPlan(EclipseGenerator.getShipVolume() * 5, material)
    end
    
    local volume = EclipseGenerator.getShipVolume() * 10
    local currentVolume = plan.volume
    if currentVolume > 0 then
        local scale = math.pow(volume / currentVolume, 1/3)
        plan:scale(vec3(scale, scale, scale))
    end
    
    local station = Sector():createStation(faction, plan, position)
    
    EclipseGenerator.addTurrets(station, 40)
    station:setTitle("Eclipse Citadel"%_T, {})
    
    station.crew = station.idealCrew
    station.shieldDurability = station.shieldMaxDurability
    
    AddDefaultStationScripts(station)
    station:addScriptOnce("utility/aiundockable.lua")
    
    station:addMultiplyableFactor(StatsBonuses.ShieldDurability, 50.0) 
    station:addMultiplyableFactor(StatsBonuses.Damage, 5.0) 
    station:addScriptOnce("entity/eclipse_boss_scaling.lua")
    
    Boarding(station).boardable = false
    
    return station
end

return EclipseGenerator
