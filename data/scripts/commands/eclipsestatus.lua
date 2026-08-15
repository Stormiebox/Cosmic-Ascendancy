package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, ...)
    local server = Server()
    local player = Player(sender)
    if not player then return 0, "", "" end

    if not server:getValue("eclipse_fully_awake") then
        player:sendChatMessage("Server", 0, "The Eclipse has not yet awakened.")
        return 0, "", ""
    end

    local msg = "=== The Eclipse: Global Status ===\n\n"

    -- 1. Check Citadel Suppression Field
    local citadelDestroyed = server:getValue("eclipse_citadel_destroyed_time") or 0
    local conqueredCount = server:getValue("eclipse_conquered_sectors") or 0
    local suppressionDuration = (6 + math.floor(conqueredCount / 10) * 2) * 3600
    
    local timeSinceDestroyed = server.unpausedRuntime - citadelDestroyed

    if timeSinceDestroyed < suppressionDuration then
        local remaining = suppressionDuration - timeSinceDestroyed
        local hours = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        msg = msg .. "[Citadel Suppression Field]: ACTIVE\n"
        msg = msg .. string.format("Eclipse invasions are halted for another %d hour(s) and %d minute(s).\n\n", hours, mins)
    else
        msg = msg .. "[Citadel Suppression Field]: INACTIVE\n"
        msg = msg .. "The Eclipse is currently free to launch invasions.\n\n"
    end
    
    -- 2. Check World-Eater Grace Period
    local graceEnd = server:getValue("eclipse_world_eater_grace_end") or 0
    if server.unpausedRuntime < graceEnd then
        local remaining = graceEnd - server.unpausedRuntime
        local hours = math.floor(remaining / 3600)
        local mins = math.floor((remaining % 3600) / 60)
        msg = msg .. "[World-Eater Grace Period]: ACTIVE\n"
        msg = msg .. string.format("The Doomsday clock is paused for another %d hour(s) and %d minute(s).\n", hours, mins)
    else
        msg = msg .. "[World-Eater Grace Period]: INACTIVE\n"
        msg = msg .. "The Eclipse is actively constructing the next World-Eater.\n"
    end
    
    player:sendChatMessage("Server", 0, msg)
    return 0, "", ""
end

function getDescription()
    return "Checks the current suppression cooldowns and grace periods for The Eclipse."
end

function getHelp()
    return "Usage: /eclipsestatus\nDisplays the remaining cooldown timers for the Citadel Suppression Field and the World-Eater Grace Period."
end
