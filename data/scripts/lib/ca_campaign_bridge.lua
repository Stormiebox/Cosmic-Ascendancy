local CampaignBridge = {}
local CONTROLLER = "data/scripts/player/background/ca_campaign_controller.lua"

function CampaignBridge.GetSnapshot()
    local resultCode, snapshot, err = Player():invokeFunction(CONTROLLER, "getSnapshot")
    if resultCode ~= 0 then return nil, "controller_unavailable" end
    return snapshot, err
end

function CampaignBridge.GetTarget(chapter)
    local snapshot, err = CampaignBridge.GetSnapshot()
    if not snapshot then return nil, nil, err end
    if snapshot.chapter ~= chapter or not snapshot.target then return nil, nil, "target_mismatch" end
    return snapshot.target.x, snapshot.target.y, nil
end

function CampaignBridge.RequestDebrief(chapter, x, y)
    local snapshot, err = CampaignBridge.GetSnapshot()
    if not snapshot then return nil, err end
    local resultCode, revision, requestError = Player():invokeFunction(
        CONTROLLER, "requestDebrief", chapter, x, y, snapshot.revision)
    if resultCode ~= 0 then return nil, "controller_unavailable" end
    return revision, requestError
end

function CampaignBridge.IsDebriefComplete(chapter)
    local snapshot = CampaignBridge.GetSnapshot()
    if not snapshot then return false end
    if snapshot.phase == "campaign_complete" then return true end
    return type(snapshot.chapter) == "number" and snapshot.chapter > chapter
end

return CampaignBridge
