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

    -- Must come before the "checked" flag below: this callback fires on every sector entry, long
    -- before the Eclipse ever awakens (most core-region sectors get visited on the way to killing
    -- the Wormhole Guardian in the first place). If the flag were set unconditionally here, every
    -- sector a player passed through pre-awakening would be permanently marked "checked" without
    -- ever actually rolling for Dark Sector eligibility, so once the Eclipse did awaken almost no
    -- core sectors would still be eligible to become one.
    if not Server():getValue("the_eclipse_unleashed") then return end

    -- Ensure this check only happens once per sector
    if sector:getValue("ca_darksector_checked") then return end
    sector:setValue("ca_darksector_checked", true)

    -- Do not generate over faction territory, asteroid bases, or populated sectors
    if #({sector:getEntitiesByType(EntityType.Station)}) > 0 then return end
    
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
    local Placer = include("placer")
    local numCitadels = random():getInt(1, 3)
    local spawnedCitadels = {}

    for i = 1, numCitadels do
        local pos = generator:getPositionInSector(1000)
        -- A Citadel is a station, not a ship. ca_eclipse_abilities.lua's class-detection only
        -- matches ship-title keywords (carrier/juggernaut/dreadnought/etc.), so "citadel" never
        -- matches any of them and the Void Siphon/Singularity Implosion behaviors it might have been
        -- meant to grant never actually trigger. Its one effect that DOES apply unconditionally,
        -- Dark Matter Blink, would let this stationary siege structure teleport 5-10km away under
        -- burst damage, which conflicts with the Lockdown Matrix's own premise that the Citadel is
        -- the fixed anchor point players approach and destroy in place. Regular Citadels built
        -- through this same createStation() factory everywhere else in the mod never get this
        -- script, so leaving it off here keeps Dark Sector Citadels consistent with every other one.
        local citadel = EclipseGenerator.createStation(pos)
        if citadel then
            table.insert(spawnedCitadels, citadel)
        end
    end

    -- A Citadel's volume is 8x a standard Eclipse ship, and up to 3 are independently placed
    -- within the same 1000m radius here, so without intersection resolution they can physically
    -- overlap. This is the same collision-engine failure class this file's own fleet spawn loop
    -- below was already fixed for (see Changelog.md's "Dark Sector Physics Engine Overload" entry);
    -- that fix only ever covered the fleet array, not this citadel loop.
    if #spawnedCitadels > 0 and Placer and Placer.resolveIntersections then
        Placer.resolveIntersections(spawnedCitadels)
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

    if Placer and Placer.resolveIntersections then
        Placer.resolveIntersections(spawnedFleets)
    end
    
    -- Spawn dense resource asteroids (Ascendant Matter / Ogonite)
    generator:createAsteroidField(0.1)
    
    Player(playerIndex):sendChatMessage("WARNING", 1, "WARNING! You have entered an Eclipse Dark Sector. Extreme Dark Matter Fog detected."%_t)
end

