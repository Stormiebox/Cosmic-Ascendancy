package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_success, cv_buffs = true, include("cosmicvaultbuffs")
include("cosmicascendancyconfig")
-- namespace AscendancyPlayer
AscendancyPlayer = {}

function AscendancyPlayer.initialize()
    if onServer() then Player():addScriptOnce("data/scripts/player/background/ca_campaign_controller.lua") end
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        Player():registerCallback("onShipBuilt", "onShipBuilt")
        Player():registerCallback("onShipChanged", "onShipChanged")
    end
    if onClient() then
        Player():addScriptOnce("data/scripts/player/cosmicascendancycodex.lua")
    end
end

local function applyToEntity(entityId)
    local entity = Entity(entityId)
    if not entity then return end

    -- Apply to ships/stations owned by the player, OR their alliance!
    local ownerIndex = entity.factionIndex
    if ownerIndex ~= Player().index then
        local allianceIndex = Player().allianceIndex
        if not allianceIndex or ownerIndex ~= allianceIndex then return end
    end

    if not entity:hasScript("data/scripts/entity/ascendancyglobalbuff.lua") then
        entity:addScript("data/scripts/entity/ascendancyglobalbuff.lua")
    end
end

function AscendancyPlayer.onSectorEntered(playerIndex, x, y)
    local entities = {Sector():getEntitiesByFaction(playerIndex)}

    local p = Player(playerIndex)
    if p and p.allianceIndex then
        local allianceEntities = {Sector():getEntitiesByFaction(p.allianceIndex)}
        for _, e in pairs(allianceEntities) do
            table.insert(entities, e)
        end
    end

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


function initialize(...)
    if AscendancyPlayer.initialize then return AscendancyPlayer.initialize(...) end
end
function onSectorEntered(...)
    if AscendancyPlayer.onSectorEntered then return AscendancyPlayer.onSectorEntered(...) end
end
