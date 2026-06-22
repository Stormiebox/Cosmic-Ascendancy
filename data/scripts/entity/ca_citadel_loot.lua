package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed()
    if not onServer() then return end
    
    local sector = Sector()
    local entity = Entity()
    local pos = entity.translationf

    -- Ascendant Matter massive drop
    local matterAmount = random():getInt(100, 250)
    sector:dropCargo(pos, nil, nil, Good("Ascendant Matter"), 0, matterAmount)
    
    -- Eclipse Datacore drop
    local coreAmount = random():getInt(3, 5)
    for i = 1, coreAmount do
        sector:dropCargo(pos, nil, nil, Good("Eclipse Datacore"), 0, 1)
    end
    
    -- Legendary Weapons and Upgrades
    local generator = include("sectorgenerator")
    local sg = generator(sector:getCoordinates())
    for i = 1, random():getInt(8, 12) do
        local weapon = InventoryWeapon(sg:generateWeapon(random(), 52, 5))
        sector:dropPort(pos, nil, nil, weapon)
    end
    
    for i = 1, random():getInt(8, 12) do
        local upgrade = sg:generateSystem(5)
        sector:dropUpgrade(pos, nil, nil, upgrade)
    end
end
