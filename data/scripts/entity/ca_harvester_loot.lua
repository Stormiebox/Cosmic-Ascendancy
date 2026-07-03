package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed()
    if not onServer() then return end
    local sector = Sector()
    local entity = Entity()
    local amount = random():getInt(100, 500)
    
    sector:dropLoot(entity.translationf, CargoLoot(Good("Ascendant Matter"), amount))
end

function initialize(...) if Namespace.initialize then return Namespace.initialize(...) end end
