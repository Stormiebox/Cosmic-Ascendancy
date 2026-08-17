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
        terminate()
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
