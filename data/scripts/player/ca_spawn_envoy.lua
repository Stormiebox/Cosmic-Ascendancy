package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    if onServer() then
        local player = Player()
        player:addScriptOnce("data/scripts/player/missions/ca_story0_meet_aegis.lua")
        terminate()
    end
end
