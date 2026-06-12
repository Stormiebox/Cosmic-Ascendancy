package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicAscendancyServer = {}

function CosmicAscendancyServer.initialize()
    if onServer() then
        Galaxy():addScriptOnce("galaxy/ascendancykeepalive.lua")
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicAscendancyServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:addScriptOnce("data/scripts/player/ascendancyplayer.lua")
    end
end

if onServer() then
    local oldInit = initialize or function() end
    function initialize()
        oldInit()
        CosmicAscendancyServer.initialize()
    end
end
