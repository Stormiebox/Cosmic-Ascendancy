package.path = package.path .. ";data/scripts/lib/?.lua"

local oldInitialize = StationFounder.initialize or function() end

function StationFounder.initialize(shipyardFaction)
    oldInitialize(shipyardFaction)

    -- Inject Ascendancy Beacon
    table.insert(StationFounder.stations, {
        name = "Ascendancy Beacon"%_t,
        tooltip = "A massive megastructure that acts as your Empire's Capital. It permanently simulates the sector it is built in, regardless of whether a player is present. Requires massive continuous upkeep."%_t,
        scripts = {"data/scripts/entity/ascendancybeacon.lua"}
    })
end
