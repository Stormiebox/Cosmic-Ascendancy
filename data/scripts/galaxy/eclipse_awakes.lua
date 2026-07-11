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
    
    local cv_dialogue = include("cosmicvaultdialogue")
    if cv_dialogue then
        cv_dialogue.registerLine({
            category = "rumor",
            text = "I heard a massive jet-black monolith wiped out an entire sector near the core... but the Galactic News is covering it up.",
            conditions = { } 
        })
        cv_dialogue.registerLine({
            category = "rumor",
            text = "The Ascendants built a Forge that runs on war and bloodshed. With the Eclipse awake, who knows what they're building in there?",
            conditions = { } 
        })
        cv_dialogue.registerLine({
            category = "rumor",
            text = "Keep your voice down. The Eclipse has eyes everywhere, and they don't leave survivors.",
            conditions = { } 
        })
    end
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
        -- Flag coordinates globally instead of spawning stations immediately. 
        -- `onSectorGenerated` lacks a physical sector instance context, so `ascendancyplayer.lua` 
        -- handles the physical spawning when a player jumps in.
        Server():setValue("eclipse_stronghold_" .. x .. "_" .. y, true)
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
            -- 15 seconds in (585 secs remaining) - Trigger the Forge the Ascendant OST
            if timeRemaining <= (10 * 60) - 15 and not server:getValue("eclipse_music_triggered") then
                server:setValue("eclipse_music_triggered", true)
                for _, p in pairs({server:getPlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "playGuardianFellMusic")
                end
            end

            -- 3 minutes in (7 mins remaining)
            if timeRemaining <= 7 * 60 and not server:getValue("eclipse_warning_1") then
                server:setValue("eclipse_warning_1", true)
                server:broadcastChatMessage("Server", 3, "WARNING: Massive hyperspace anomalies detected across all sectors. Something ancient is waking up."%_T)
                for _, p in pairs({server:getPlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "showCinematicBanner", "MASSIVE HYPERSPACE ANOMALY", "data/sounds/siren.ogg")
                end
            end
            -- 8 minutes in (2 mins remaining)
            if timeRemaining <= 2 * 60 and not server:getValue("eclipse_warning_2") then
                server:setValue("eclipse_warning_2", true)
                server:broadcastChatMessage("Server", 3, "CRITICAL WARNING: The anomalies are stabilizing into jump signatures. Black Avorion reading off the charts!"%_T)
                for _, p in pairs({server:getPlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "showCinematicBanner", "BLACK AVORION SIGNATURES DETECTED", "data/sounds/siren.ogg")
                end
            end
            return
        else
            if not server:getValue("eclipse_fully_awake") then
                server:setValue("eclipse_fully_awake", true)
                server:broadcastChatMessage("The Eclipse", 2, "Your ignorance has doomed this galaxy. We are The Eclipse. You will be erased."%_T)
                Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_roaming_boss.lua")
                Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_conquest_manager.lua")
                Galaxy():addScriptOnce("data/scripts/galaxy/ca_world_eater_manager.lua")
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
        -- 60% chance to personally ambush a player in their sector
        if random():getFloat(0, 1) > 0.4 then
            -- before the first one finishes (e.g., if invasion timer fires while one is still running).
            -- addScriptOnce is idempotent — safe to call multiple times; will not stack.
            player:addScriptOnce("data/scripts/player/events/eclipseinvasion.lua")
        end
    end
end

function EclipseAwakes.secure()
    return {invasionTimer = EclipseAwakes.invasionTimer}
end

function EclipseAwakes.restore(data)
    if data then
        EclipseAwakes.invasionTimer = data.invasionTimer or 0
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
function secure(...)
    if EclipseAwakes.secure then return EclipseAwakes.secure(...) end
end
function restore(...)
    if EclipseAwakes.restore then return EclipseAwakes.restore(...) end
end

-- Global Event Callbacks
function onSectorGenerated(...)
    if EclipseAwakes.onSectorGenerated then return EclipseAwakes.onSectorGenerated(...) end
end
