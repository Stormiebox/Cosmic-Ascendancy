package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
local SectorGenerator = include("SectorGenerator")

-- Dark Sector Generator
-- This script runs in the background for players. 
-- When they enter an uncharted sector deep within the galactic core (inside the barrier),
-- there is a high chance it transforms into a deadly Eclipse Dark Sector.

function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onClient() then return end
    
    local sector = Sector()
    if not sector then return end
    
    -- Ensure this check only happens once per sector
    if sector:getValue("ca_darksector_checked") then return end
    sector:setValue("ca_darksector_checked", true)

    -- Do not generate over faction territory, asteroid bases, or populated sectors
    if sector:getEntitiesByComponent(ComponentType.Station) then return end
    
    -- Check if inside the core
    local dist = length(vec2(x, y))
    if dist > 150 then return end
    
    -- Only a 20% chance to be a Dark Sector, keeping it somewhat rare
    if random():getFloat(0, 1) > 0.20 then return end
    
    -- It's a Dark Sector!
    print("Generating Eclipse Dark Sector at " .. tostring(x) .. ":" .. tostring(y))
    
    local generator = SectorGenerator(x, y)
    
    -- Add Dark Matter Fog (environmental hazard)
    sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", "DarkMatterFog", -1)
    
    -- Spawn Eclipse Citadels (1-3)
    local EclipseGenerator = include("eclipsegenerator")
    local numCitadels = random():getInt(1, 3)
    
    for i = 1, numCitadels do
        local pos = generator:getPositionInSector(1000)
        local citadel = EclipseGenerator.createStation(pos)
        if citadel then
            citadel:addScriptOnce("data/scripts/entity/ca_eclipse_abilities.lua")
        end
    end
    
    -- Spawn heavily guarded Eclipse Fleets
    local numFleets = random():getInt(2, 4)
    local spawnedFleets = {}
    for i = 1, numFleets do
        local pos = generator:getPositionInSector(1500)
        table.insert(spawnedFleets, EclipseGenerator.createJuggernaut(pos))
        table.insert(spawnedFleets, EclipseGenerator.createArtillery(pos))
        table.insert(spawnedFleets, EclipseGenerator.createAssassin(pos))
    end
    
    local Placer = include("placer")
    if Placer and Placer.resolveIntersections then
        Placer.resolveIntersections(spawnedFleets)
    end
    
    -- Spawn dense resource asteroids (Ascendant Matter / Ogonite)
    generator:createAsteroidField(0.1)
    
    Player(playerIndex):sendChatMessage("WARNING", 1, "WARNING! You have entered an Eclipse Dark Sector. Extreme Dark Matter Fog detected."%_t)
end
