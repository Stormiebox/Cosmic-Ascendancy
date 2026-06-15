package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    Player():registerCallback("onShipChanged", "onShipChanged")
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function getUpdateInterval()
    return 60
end

function updateServer(timeStep)
    -- As a fallback, try to attach to all player ships in the sector occasionally
    local sector = Sector()
    if not sector then return end
    
    local player = Player()
    local entities = {sector:getEntitiesByFaction(player.index)}
    for _, entity in pairs(entities) do
        if entity.isShip or entity.isStation then
            if not entity:hasScript("data/scripts/entity/ca_ascendancy_ship_buff.lua") then
                entity:addScript("data/scripts/entity/ca_ascendancy_ship_buff.lua")
            end
        end
    end
end

function onShipChanged(playerIndex, craftId)
    if not onServer() then return end
    local ship = Entity(craftId)
    if ship and (ship.isShip or ship.isStation) then
        if not ship:hasScript("data/scripts/entity/ca_ascendancy_ship_buff.lua") then
            ship:addScript("data/scripts/entity/ca_ascendancy_ship_buff.lua")
        end
    end
end

function onSectorEntered(playerIndex, x, y, changeType)
    if not onServer() then return end
    local player = Player(playerIndex)
    local craft = player.craft
    if craft and (craft.isShip or craft.isStation) then
        if not craft:hasScript("data/scripts/entity/ca_ascendancy_ship_buff.lua") then
            craft:addScript("data/scripts/entity/ca_ascendancy_ship_buff.lua")
        end
    end
end
