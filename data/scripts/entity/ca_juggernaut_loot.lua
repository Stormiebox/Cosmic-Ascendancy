package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed()
    if not onServer() then return end
    local sector = Sector()
    local entity = Entity()
    
    -- Juggernauts always drop 1 Datacore
    sector:dropCargo(entity.translationf, nil, nil, "Eclipse Datacore", 1, 0)
end
