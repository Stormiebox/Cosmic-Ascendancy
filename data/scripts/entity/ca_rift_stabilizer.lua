-- namespace AscendancyRiftStabilizer
AscendancyRiftStabilizer = {}

local CosmicVaultRift = include("cosmicvaultrift")
local conditionId

function AscendancyRiftStabilizer.initialize(initialConditionId)
    if type(initialConditionId) == "string" then conditionId = initialConditionId end
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function AscendancyRiftStabilizer.onDestroyed()
    if not onServer() then return end
    if conditionId then
        local ended, errorCode = CosmicVaultRift.EndRiftHazard(conditionId,
            "stabilizer_destroyed")
        if not ended then
            print("[Cosmic Ascendancy] Rift spillage cleanup failed: " .. tostring(errorCode))
        end
    end
    Sector():broadcastChatMessage("System", ChatMessageType.Information,
        "The Eclipse Rift Stabilizer has been destroyed! The subspace tear is closing."%_t)
end

function AscendancyRiftStabilizer.secure()
    return {conditionId = conditionId}
end

function AscendancyRiftStabilizer.restore(data)
    if type(data) == "table" and type(data.conditionId) == "string" then
        conditionId = data.conditionId
    end
end
