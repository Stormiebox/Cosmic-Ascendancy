
package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicAscendancyServer = {}

function CosmicAscendancyServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")

        -- Start the Cosmic Ascendancy Sector Keep-Alive Engine
        if not Galaxy():hasScript("galaxy/ascendancykeepalive.lua") then
            Galaxy():addScriptOnce("galaxy/ascendancykeepalive.lua")
        end

        -- Start The Eclipse Awakening Engine
        if not Galaxy():hasScript("galaxy/eclipse_awakes.lua") then
            Galaxy():addScriptOnce("galaxy/eclipse_awakes.lua")
        end

        -- Start Dynamic Faction Expansion
        if not Galaxy():hasScript("galaxy/ca_expansion_manager.lua") then
            Galaxy():addScriptOnce("galaxy/ca_expansion_manager.lua")
        end


    end
end

local old_onPlayerLogIn = onPlayerLogIn
function onPlayerLogIn(playerIndex)
    if old_onPlayerLogIn then old_onPlayerLogIn(playerIndex) end
    CosmicAscendancyServer.onPlayerLogIn(playerIndex)
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



