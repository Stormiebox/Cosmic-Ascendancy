package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")

-- namespace StationOverdrive
StationOverdrive = {}
local isOverdriven = false
local overdriveEndTime = 0
local OVERDRIVE_DURATION = 3600 -- 1 Hour
local overdriveKey = nil

function StationOverdrive.initialize()
    if onClient() then
        invokeServerFunction("sync")
    end
end

function StationOverdrive.interactionPossible(playerIndex, option)
    local entity = Entity()
    -- Only allow if it's a station
    if not entity.isStation then return false end
    
    -- Only allow if the interacting player owns or can manage this station
    return checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageStations)
end

function StationOverdrive.initUI()
    ScriptUI():registerInteraction("Activate Ascendant Overdrive (50 Matter)"%_t, "onOverdrivePressed")
end

function StationOverdrive.onOverdrivePressed()
    if onClient() then invokeServerFunction("activateOverdrive"); return end
end

function StationOverdrive.activateOverdrive()
    if not onServer() then return end
    
    local entity = Entity()
    local owner = Faction(entity.factionIndex)
    if not owner then return end
    
    -- Verify player is in a ship
    local player = Player(callingPlayer)
    if not player then return end
    
    local craft = player.craft
    if not craft then
        player:sendChatMessage("Overdrive"%_t, 1, "You must be inside a ship to feed matter to the station."%_t)
        return
    end

    if isOverdriven then
        player:sendChatMessage("Overdrive"%_t, 1, "This station is already in Overdrive!"%_t)
        return
    end

    local matterCost = 50
    local cargoAmount = craft:getCargoAmount("Ascendant Matter")
    
    if cargoAmount < matterCost then
        player:sendChatMessage("Overdrive"%_t, 1, "Insufficient Ascendant Matter in your ship's cargo hold. Requires 50."%_t)
        return
    end

    -- Consume Matter
    craft:removeCargo(Good("Ascendant Matter"), matterCost)

    -- Activate Overdrive
    isOverdriven = true
    overdriveEndTime = Server().playtime + OVERDRIVE_DURATION

    -- Apply the 3x Production Capacity Multiplier (This works for Fighter Assemblies)
    overdriveKey = entity:addMultiplier(StatsBonuses.ProductionCapacity, 3.0)

    owner:sendChatMessage("Overdrive"%_t, 0, "Ascendant Overdrive engaged! Production speed tripled for 1 hour."%_t)
    
    -- Send sync
    StationOverdrive.sync()
end
callable(StationOverdrive, "activateOverdrive")

function StationOverdrive.getUpdateInterval()
    return 10
end

function StationOverdrive.updateServer(timeStep)
    if isOverdriven then
        local pt = Server().playtime
        if pt >= overdriveEndTime then
            isOverdriven = false
            local entity = Entity()
            
            -- Remove the Fighter Assembly multiplier
            if overdriveKey then
                entity:removeBonus(overdriveKey)
                overdriveKey = nil
            end
            
            local owner = Faction(entity.factionIndex)
            if owner then
                owner:sendChatMessage("Overdrive"%_t, 2, "Ascendant Overdrive has worn off on your factory."%_t)
            end
            
            StationOverdrive.sync()
        else
            -- Avorion Vanilla factories ignore StatsBonuses.ProductionCapacity entirely.
            -- To achieve true 3x production speed, we must artificially advance the factory's update loop twice per tick.
            local entity = Entity()
            if entity:hasScript("factory.lua") then
                entity:invokeFunction("factory", "updateParallelSelf", timeStep)
                entity:invokeFunction("factory", "updateParallelSelf", timeStep)
            elseif entity:hasScript("mine.lua") then
                entity:invokeFunction("mine", "updateParallelSelf", timeStep)
                entity:invokeFunction("mine", "updateParallelSelf", timeStep)
            end
        end
    end
end

function StationOverdrive.sync(data)
    if onServer() then
        if callingPlayer then
            invokeClientFunction(Player(callingPlayer), "sync", {
                isOverdriven = isOverdriven,
                overdriveEndTime = overdriveEndTime
            })
        else
            broadcastInvokeClientFunction("sync", {
                isOverdriven = isOverdriven,
                overdriveEndTime = overdriveEndTime
            })
        end
    else
        if data then
            isOverdriven = data.isOverdriven
            overdriveEndTime = data.overdriveEndTime
        end
    end
end
callable(StationOverdrive, "sync")

function StationOverdrive.secure()
    return {
        isOverdriven = isOverdriven,
        overdriveEndTime = overdriveEndTime
    }
end

function StationOverdrive.restore(data)
    isOverdriven = data.isOverdriven or false
    overdriveEndTime = data.overdriveEndTime or 0
    
    if isOverdriven and onServer() then
        -- In case the server restarted while overdriven, re-apply the multiplier 
        -- because addMultiplier is volatile and does not persist across restarts unless re-added
        local entity = Entity()
        overdriveKey = entity:addMultiplier(StatsBonuses.ProductionCapacity, 3.0)
    end
end


function getUpdateInterval(...)
    if StationOverdrive.getUpdateInterval then return StationOverdrive.getUpdateInterval(...) end
end
function updateServer(...)
    if StationOverdrive.updateServer then return StationOverdrive.updateServer(...) end
end
function secure(...)
    if StationOverdrive.secure then return StationOverdrive.secure(...) end
end
function restore(...)
    if StationOverdrive.restore then return StationOverdrive.restore(...) end
end
function initialize(...)
    if StationOverdrive.initialize then return StationOverdrive.initialize(...) end
end
function interactionPossible(...)
    if StationOverdrive.interactionPossible then return StationOverdrive.interactionPossible(...) end
end
function initUI(...)
    if StationOverdrive.initUI then return StationOverdrive.initUI(...) end
end
function onOverdrivePressed(...)
    if StationOverdrive.onOverdrivePressed then return StationOverdrive.onOverdrivePressed(...) end
end
function activateOverdrive(...)
    if StationOverdrive.activateOverdrive then return StationOverdrive.activateOverdrive(...) end
end
function sync(...)
    if StationOverdrive.sync then return StationOverdrive.sync(...) end
end
