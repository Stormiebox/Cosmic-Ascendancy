package.path = package.path .. ";data/scripts/lib/?.lua"

include("goods")

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed()
    if not onServer() then return end
    local sector = Sector()
    local entity = Entity()
    
    -- Anchor Pylons are Juggernauts but shouldn't drop the raid-summoning Datacore!
    if entity:getValue("is_worldeater_tether") then return end
    
    -- Juggernauts always drop 1 Datacore
    sector:dropCargo(entity.translationf, nil, nil, goods["Eclipse Datacore"], 0, 1)
end
