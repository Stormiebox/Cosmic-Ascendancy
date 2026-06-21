package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local EclipseAwakes = {}
EclipseAwakes.invasionTimer = 0

function EclipseAwakes.getUpdateInterval()
    return 5.0
end

function EclipseAwakes.initialize()
    local server = Server()
    server:registerCallback("onSectorGenerated", "onSectorGenerated")
end

function EclipseAwakes.onSectorGenerated(x, y, regular)
    if not regular then return end

    local server = Server()
    if not server:getValue("eclipse_fully_awake") then return end

    local dist = math.sqrt(x*x + y*y)
    local seed = server.seed
    local random = Random(Seed(seed + x + y))

    local chance = 0.0
    if dist <= 75 then
        -- 1/3rd of the inner core
        chance = 0.50
    elseif dist <= 150 then
        -- Further inside the core
        chance = 0.25
    else
        -- 5% to 15% for the rest of the galaxy
        chance = random:getFloat(0.05, 0.15)
    end

    if random:getFloat() < chance then
        -- IMPORTANT ARCHITECTURE NOTE (Stormbox):
        -- We cannot physically spawn stations or ships here. Calling `Sector()` during
        -- `onSectorGenerated` inside `eclipse_awakes.lua` crashes the game because this script
        -- is not bound to a physical sector instance.
        -- Instead, we flag the coordinates globally. When a player physically enters
        -- these coordinates, `ascendancyplayer.lua` reads this flag and spawns the stronghold.
        Galaxy():setValue("eclipse_stronghold_" .. x .. "_" .. y, true)
    end
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
                Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_roaming_boss.lua")
                Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_conquest_manager.lua")
            end
        end
    end

    -- The Eclipse is fully awake. Handle Global Player Invasions.
    if server:getValue("eclipse_fully_awake") then
        EclipseAwakes.invasionTimer = EclipseAwakes.invasionTimer + timeStep

        -- Every 25 to 45 minutes, attempt an invasion
        if EclipseAwakes.invasionTimer > random():getInt(25, 45) * 60 then
            EclipseAwakes.invasionTimer = 0
            EclipseAwakes.triggerInvasion()
        end
    end
end

function EclipseAwakes.triggerInvasion()
    -- This is now handled globally by eclipse_conquest_manager.lua, but we still trigger personal player ambushes here
    local players = {Server():getPlayers()}
    for _, player in pairs(players) do
        -- 60% chance to invade a player's sector personally
        if random():getFloat(0, 1) > 0.4 then
            player:addScript("data/scripts/player/events/eclipseinvasion.lua")
        end
    end
end

function getUpdateInterval(...)
    if EclipseAwakes.getUpdateInterval then return EclipseAwakes.getUpdateInterval(...) end
end
function initialize(...)
    if EclipseAwakes.initialize then return EclipseAwakes.initialize(...) end
end
function updateServer(...)
    if EclipseAwakes.updateServer then return EclipseAwakes.updateServer(...) end
end

-- Global Event Callbacks
function onSectorGenerated(...)
    if EclipseAwakes.onSectorGenerated then return EclipseAwakes.onSectorGenerated(...) end
end
