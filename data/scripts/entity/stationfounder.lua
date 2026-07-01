package.path = package.path .. ";data/scripts/lib/?.lua"

-- Inject Ascendancy Beacon into the global StationFounder.stations table
table.insert(StationFounder.stations, {
    name = "Ascendancy Beacon"%_t,
    tooltip = "A massive megastructure that acts as your Empire's Capital. It permanently simulates the sector it is built in, regardless of whether a player is present. Requires massive continuous upkeep."%_t,
    scripts = {{script = "data/scripts/entity/ascendancybeacon.lua"}},
    price = 100000000 -- 100 million credits
})
