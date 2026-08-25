package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        local entity = Entity()
        if not entity then return end
        
        -- Add +50% velocity boost
        entity:addBaseMultiplier(StatsBonuses.Velocity, 0.5)
        
        -- Set a timer to remove the buff after 10 seconds
        deferredCallback(10, "removeBuff")
        
        -- Notify player
        Sector():broadcastChatMessage("Ship Computer", 3, "Slipstream Drift active. Velocity significantly increased for 10 seconds.")
    end
end

function removeBuff()
    if onServer() then
        local entity = Entity()
        if entity then
            -- Remove all bonuses added by this script
            entity:removeScriptBonuses()
        end
        -- Terminate script
        terminate()
    end
end
