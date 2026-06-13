package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local EclipseAwakes = {}
EclipseAwakes.invasionTimer = 0

function EclipseAwakes.getUpdateInterval()
    return 5.0
end

function EclipseAwakes.initialize()
end

function EclipseAwakes.updateServer(timeStep)
    local server = Server()
    
    local unleashed = server:getValue("the_eclipse_unleashed")
    if not unleashed then
        -- Check if any player killed the guardian
        for _, player in pairs({server:getPlayers()}) do
            if player:getValue("wormhole_guardian_destroyed") then
                server:setValue("the_eclipse_unleashed", true)
                server:setValue("eclipse_awaken_time", server.unpausedRuntime + 10 * 60)
                server:broadcastChatMessage("Server", 2, "An ominous shudder ripples through the fabric of subspace... The Guardian's death has broken an ancient seal."%_T)
                break
            end
        end
        return
    end
    
    local awakenTime = server:getValue("eclipse_awaken_time")
    if awakenTime then
        local timeRemaining = awakenTime - server.unpausedRuntime
        
        if timeRemaining > 0 then
            -- 3 minutes in (7 mins remaining)
            if timeRemaining <= 7 * 60 and not server:getValue("eclipse_warning_1") then
                server:setValue("eclipse_warning_1", true)
                server:broadcastChatMessage("Server", 3, "WARNING: Massive hyperspace anomalies detected across all sectors. Something ancient is waking up."%_T)
            end
            -- 8 minutes in (2 mins remaining)
            if timeRemaining <= 2 * 60 and not server:getValue("eclipse_warning_2") then
                server:setValue("eclipse_warning_2", true)
                server:broadcastChatMessage("Server", 3, "CRITICAL WARNING: The anomalies are stabilizing into jump signatures. Black Avorion reading off the charts!"%_T)
            end
            return
        else
            if not server:getValue("eclipse_fully_awake") then
                server:setValue("eclipse_fully_awake", true)
                server:broadcastChatMessage("The Eclipse", 2, "Your ignorance has doomed this galaxy. We are The Eclipse. You will be erased."%_T)
            end
        end
    end
    
    -- The Eclipse is fully awake. Handle Global Player Invasions.
    if server:getValue("eclipse_fully_awake") then
        EclipseAwakes.invasionTimer = EclipseAwakes.invasionTimer + timeStep
        
        -- Every 25 to 45 minutes, attempt an invasion
        if EclipseAwakes.invasionTimer > math.random(25, 45) * 60 then
            EclipseAwakes.invasionTimer = 0
            EclipseAwakes.triggerInvasion()
        end
    end
end

function EclipseAwakes.triggerInvasion()
    local players = {Server():getPlayers()}
    for _, player in pairs(players) do
        -- 60% chance to invade a player's sector
        if math.random() > 0.4 then
            player:addScript("data/scripts/player/events/eclipseinvasion.lua")
        end
    end
end

return EclipseAwakes
