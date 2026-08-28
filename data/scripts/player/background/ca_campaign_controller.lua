package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace AscendancyCampaign
AscendancyCampaign = {}

function AscendancyCampaign.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function AscendancyCampaign.onSectorEntered(playerIndex, x, y, changeType)
    local player = Player(playerIndex)

    -- Trigger Lore Anomalies dynamically
    local LoreAnomalies = include("player/background/ca_story_lore_anomalies")
    if LoreAnomalies and LoreAnomalies.onSectorEntered then
        LoreAnomalies.onSectorEntered(playerIndex, x, y, changeType or SectorChangeType.Jump)
    end
end

