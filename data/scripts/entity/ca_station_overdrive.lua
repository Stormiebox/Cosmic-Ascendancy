package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")

-- namespace StationOverdrive
StationOverdrive = {}
local isOverdriven = false
local overdriveEndTime = 0
local OVERDRIVE_DURATION = 3600 -- 1 Hour

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
    -- Use Server().unpausedRuntime instead so the 1-hour timer only ticks during active gameplay.
    overdriveEndTime = Server().unpausedRuntime + OVERDRIVE_DURATION

    -- The correct method is addBaseMultiplier, which multiplies the base capacity.
    entity:addBaseMultiplier(StatsBonuses.ProductionCapacity, 2.0)

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
        local pt = Server().unpausedRuntime
        if pt >= overdriveEndTime then
            isOverdriven = false
            local entity = Entity()
            
            -- Remove the multiplier
            entity:removeScriptBonuses()
            
            local owner = Faction(entity.factionIndex)
            if owner then
                owner:sendChatMessage("Overdrive"%_t, 2, "Ascendant Overdrive has worn off on your factory."%_t)
            end
            
            StationOverdrive.sync()
        else
            -- Run the vanilla factory self-update logic in parallel to process the boost
            -- Calling it twice per overdrive tick artificially doubles production throughput.
            -- This is the correct workaround because StatsBonuses.ProductionCapacity is ignored
            -- by vanilla factory.lua's own production logic (it only reads from its parallel slots count).
            local entity = Entity()
            if entity:hasScript("factory.lua") then
                entity:invokeFunction("factory", "updateParallelSelf", timeStep)
                entity:invokeFunction("factory", "updateParallelSelf", timeStep)
            elseif entity:hasScript("mine.lua") then
                -- mine.lua does not exist in the vanilla copy; this branch is unreachable but harmless
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
        -- In case the server restarted while overdriven, re-apply the multiplier.
        -- addMultiplyableBias is volatile and does not persist across restarts unless re-added.
        -- We must first strip the saved bias from the database before re-adding.
        local entity = Entity()
        entity:removeScriptBonuses()
        entity:addBaseMultiplier(StatsBonuses.ProductionCapacity, 2.0)
    end
end

