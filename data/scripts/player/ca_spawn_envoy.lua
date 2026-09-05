package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local timer = 0

function getUpdateInterval()
    return 1.0
end

function updateServer(timeStep)
    timer = timer + timeStep
    if timer >= 10 then
        local player = Player()
        player:addScriptOnce("data/scripts/player/missions/ca_story0_meet_aegis.lua")
        -- addScriptOnce swallows a failure inside the target's own initialize() rather than
        -- propagating it back here (see ca_ascendant_envoy.lua's identical verification for the
        -- fuller writeup) -- confirm the mission actually attached before terminating this script.
        -- If it didn't, retry on the next tick instead of leaving the player stranded with neither
        -- script running and eclipse_awakes.lua's own outer retry loop as the only remaining
        -- (slower, message-repeating) recovery path.
        if player:hasScript("data/scripts/player/missions/ca_story0_meet_aegis.lua") then
            terminate()
        else
            timer = 0
        end
    end
end

function secure()
    return {timer = timer}
end

function restore(data)
    if data then
        timer = data.timer or 0
    end
end
