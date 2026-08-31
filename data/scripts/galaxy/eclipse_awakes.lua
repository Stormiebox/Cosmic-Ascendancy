package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include("stringutility")

-- namespace EclipseAwakes
EclipseAwakes = {}
EclipseAwakes.invasionTimer = 0
EclipseAwakes.awakenTimer = 0

function EclipseAwakes.getUpdateInterval()
    return 5.0
end

function EclipseAwakes.initialize()
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



function EclipseAwakes.updateServer(timeStep)
    local server = Server()

    local unleashed = server:getValue("the_eclipse_unleashed")

    -- Vanilla only sets wormhole_guardian_destroyed on players physically present in
    -- Sector():getPlayers() at the exact instant WormholeGuardian.onDestroyed() fires
    -- (data/scripts/entity/story/wormholeguardian.lua). A player who lands the killing
    -- blow and warps out the same tick, or gets finished off by residual/DOT damage after
    -- leaving, can complete the vanilla "Kill the Guardian" mission (which tracks via a much
    -- looser Sector():getEntitiesByScript() poll) without ever receiving that flag, silently
    -- softlocking the entire Eclipse/Envoy/Aegis chain for them.
    -- guardian_respawn_time is set unconditionally and galaxy-wide the moment the Guardian
    -- dies (wormholeguardian.lua:79) and only clears ~2 hours later on respawn, well after
    -- the 10-minute awakening window below always latches "the_eclipse_unleashed" — so it's
    -- a safe, reliable fallback signal that the kill happened even when presence wasn't caught.
    local guardianConfirmedDead = server:getValue("guardian_respawn_time") ~= nil

    -- Check all online players to spawn the Envoy for them individually if they killed the Guardian
    for _, player in pairs({server:getOnlinePlayers()}) do
        if (player:getValue("wormhole_guardian_destroyed") or guardianConfirmedDead) and not player:getValue("ca_envoy_spawned") then
            player:setValue("ca_envoy_spawned", true)
            
            -- Add the player script that will wait 10 seconds and spawn Aegis
            player:addScriptOnce("data/scripts/player/ca_spawn_envoy.lua")

            -- If this is the FIRST time any player has killed it, trigger the global awakening
            if not unleashed then
                server:setValue("the_eclipse_unleashed", true)
                unleashed = true
                EclipseAwakes.awakenTimer = 0
                server:broadcastChatMessage("Server", 2, "An ominous shudder ripples through the fabric of subspace... The Guardian's death has broken an ancient seal."%_T)
                for _, p in pairs({server:getOnlinePlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerCinematicBanner", "THE ECLIPSE AWAKENS", "data/sounds/siren.ogg")
                end
            end
        end
    end

    if not unleashed then
        return
    end

    if not server:getValue("eclipse_fully_awake") then
        EclipseAwakes.awakenTimer = EclipseAwakes.awakenTimer + timeStep
        local timeRemaining = (10 * 60) - EclipseAwakes.awakenTimer

        if timeRemaining > 0 then
            -- Music trigger has been moved to ca_story0_meet_aegis.lua to play when encountering Aegis


            -- 3 minutes in (7 mins remaining)
            if timeRemaining <= 7 * 60 and not server:getValue("eclipse_warning_1") then
                server:setValue("eclipse_warning_1", true)
                server:broadcastChatMessage("Server", 3, "WARNING: Massive hyperspace anomalies detected across all sectors. Something ancient is waking up."%_T)
                for _, p in pairs({server:getOnlinePlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerCinematicBanner", "MASSIVE HYPERSPACE ANOMALY", "data/sounds/siren.ogg")
                end
            end
            -- 8 minutes in (2 mins remaining)
            if timeRemaining <= 2 * 60 and not server:getValue("eclipse_warning_2") then
                server:setValue("eclipse_warning_2", true)
                server:broadcastChatMessage("Server", 3, "CRITICAL WARNING: The anomalies are stabilizing into jump signatures. Black Avorion reading off the charts!"%_T)
                for _, p in pairs({server:getOnlinePlayers()}) do
                    p:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
                    p:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerCinematicBanner", "BLACK AVORION SIGNATURES DETECTED", "data/sounds/siren.ogg")
                end
            end
            return
        else
            server:setValue("eclipse_fully_awake", true)

            -- Explicitly generate The Eclipse faction so it exists in the database
            local EclipseGenerator = include("eclipsegenerator")
            EclipseGenerator.getFaction()

            server:broadcastChatMessage("The Eclipse", 2, "Your ignorance has doomed this galaxy. We are The Eclipse. You will be erased."%_T)
            Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_roaming_boss.lua")
            Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_conquest_manager.lua")
            Galaxy():addScriptOnce("data/scripts/galaxy/ca_world_eater_manager.lua")
        end
    end

    -- The Eclipse is fully awake. (Timer migrated to Threat Economy in eclipse_conquest_manager.lua)
    if server:getValue("eclipse_fully_awake") then
        -- We now rely on the Threat Economy to dictate the pace of invasions.
    end
end


function EclipseAwakes.secure()
    return {
        awakenTimer = EclipseAwakes.awakenTimer
    }
end

function EclipseAwakes.restore(data)
    if data then
        EclipseAwakes.awakenTimer = data.awakenTimer or 0
        
        -- Legacy Timer Migration to Threat Economy
        if data.nextInvasionTime and data.nextInvasionTime > 0 then
            local currentThreat = Server():getValue("eclipse_threat") or 0
            if currentThreat == 0 then
                -- Give them a burst of threat based on how close they were to an invasion
                local remaining = data.nextInvasionTime - Server().unpausedRuntime
                if remaining < 0 then remaining = 0 end
                local threat = 10000 - (remaining * (10000 / 2700)) 
                if threat < 0 then threat = 0 end
                if threat > 10000 then threat = 10000 end
                Server():setValue("eclipse_threat", threat)
            end
        end
    end
end
