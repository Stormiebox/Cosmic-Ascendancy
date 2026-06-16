package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local AscendancyCampaign = {}

function AscendancyCampaign.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function AscendancyCampaign.onSectorEntered(playerIndex, x, y)
    local player = Player(playerIndex)

    -- Trigger Lore Anomalies dynamically
    local status, LoreAnomalies = pcall(include, "ca_story_lore_anomalies")
    if status and LoreAnomalies and LoreAnomalies.onSectorEntered then
        LoreAnomalies.onSectorEntered(playerIndex, x, y, SectorChangeType.Jump)
    end

    -- Check if player is near the core
    local dist = math.sqrt(x*x + y*y)
    if dist > 200 then return end

    -- Find Hermit or Adventurer
    local stations = {Sector():getEntitiesByType(EntityType.Station)}
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local entities = {}
    for _, s in pairs(stations) do table.insert(entities, s) end
    for _, s in pairs(ships) do table.insert(entities, s) end

    for _, entity in pairs(entities) do
        if entity.title == "Hermit" or entity.title == "Adventurer" then
            if not entity:hasScript("data/scripts/entity/ca_dialogue_hook.lua") then
                entity:addScriptOnce("data/scripts/entity/ca_dialogue_hook.lua")
            end
        end
    end
end

function initialize(...)
    if AscendancyCampaign.initialize then return AscendancyCampaign.initialize(...) end
end
function onSectorEntered(...)
    if AscendancyCampaign.onSectorEntered then return AscendancyCampaign.onSectorEntered(...) end
end


return AscendancyCampaign
