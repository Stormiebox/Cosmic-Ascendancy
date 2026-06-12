package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_success, cv_buffs = pcall(require, "cosmicvaultbuffs")

-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onShipBuilt", "onShipBuilt")
        Player():registerCallback("onShipChanged", "onShipChanged")
    end
end

local function applyToEntity(entityId)
    local entity = Entity(entityId)
    if not entity then return end
    
    -- Only apply to ships/stations owned by this player
    if entity.factionIndex ~= Player().index then return end
    
    if not entity:hasScript("data/scripts/entity/ascendancyglobalbuff.lua") then
        entity:addScript("data/scripts/entity/ascendancyglobalbuff.lua")
    end
end

function AscendancyPlayer.onSectorEntered(playerIndex, x, y)
    local entities = {Sector():getEntitiesByFaction(playerIndex)}
    for _, entity in pairs(entities) do
        applyToEntity(entity.id)
    end
end

function AscendancyPlayer.onShipBuilt(entityId)
    applyToEntity(entityId)
end

function AscendancyPlayer.onShipChanged(playerIndex, craftId)
    applyToEntity(craftId)
end
