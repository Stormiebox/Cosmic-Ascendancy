package.path = package.path .. ";data/scripts/lib/?.lua"

-- Key returned by addBaseMultiplier below, so removeBuff() can strip exactly this bonus via
-- entity:removeBonus(key) instead of entity:removeScriptBonuses(), which clears EVERY script-added
-- bonus on the entity -- including this ship's own Ascendant Slipstream Core persistent bonuses
-- (Velocity/Jump Range/Hyperspace Cooldown), which are added via the same unscoped-looking calls.
-- Every jump with the Core installed was wiping the Core's own bonuses for up to 10 seconds
-- afterward. Not persisted via secure()/restore() -- this script's whole lifetime is under 10
-- seconds, so there's nothing to persist across a reload.
local velocityKey = nil

function initialize()
    if onServer() then
        local entity = Entity()
        if not entity then return end

        -- Add +50% velocity boost
        velocityKey = entity:addBaseMultiplier(StatsBonuses.Velocity, 0.5)

        -- Set a timer to remove the buff after 10 seconds
        deferredCallback(10, "removeBuff")

        -- Notify player
        Sector():broadcastChatMessage("Ship Computer", 3, "Slipstream Drift active. Velocity significantly increased for 10 seconds.")
    end
end

function removeBuff()
    if onServer() then
        local entity = Entity()
        if entity and velocityKey then
            entity:removeBonus(velocityKey)
            velocityKey = nil
        end
        -- Terminate script
        terminate()
    end
end
