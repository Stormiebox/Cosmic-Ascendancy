package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed()
    if not onServer() then return end
    local sector = Sector()
    local entity = Entity()
    local amount = random():getInt(100, 500)
    
    sector:dropCargo(entity.translationf, nil, nil, "Ascendant Matter", amount, 0)
end
