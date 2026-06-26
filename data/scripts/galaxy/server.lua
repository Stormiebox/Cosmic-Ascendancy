
package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicAscendancyServer = {}

function CosmicAscendancyServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")

        -- Start the Cosmic Ascendancy Sector Keep-Alive Engine
        if not Galaxy():hasScript("galaxy/ascendancykeepalive.lua") then
            Galaxy():addScript("galaxy/ascendancykeepalive.lua")
        end

        -- Start The Eclipse Awakening Engine
        if not Galaxy():hasScript("galaxy/eclipse_awakes.lua") then
            Galaxy():addScript("galaxy/eclipse_awakes.lua")
        end

        -- Start Dynamic Faction Expansion
        if not Galaxy():hasScript("galaxy/ca_expansion_manager.lua") then
            Galaxy():addScript("galaxy/ca_expansion_manager.lua")
        end

        Server():registerCallback("onSectorGenerated", "onSectorGenerated")
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

function CosmicAscendancyServer.onSectorGenerated(x, y)
    -- If the Eclipse is fully awake, there is a chance they have conquered this newly generated sector
    if Server():getValue("eclipse_fully_awake") then
        if random():getFloat() < 0.05 then -- 5% chance per sector to be an Eclipse Stronghold
            local EclipseGenerator = include("eclipsegenerator")
            local faction = EclipseGenerator.getFaction()

            -- IMPORTANT ARCHITECTURE NOTE:
            -- We cannot physically spawn stations or ships here. Calling `Sector()` during
            -- `onSectorGenerated` inside `server.lua` crashes the game because this script
            -- is not bound to a physical sector instance.
            -- Instead, we flag the coordinates globally. When a player physically enters
            -- these coordinates, `ascendancyplayer.lua` reads this flag and spawns the stronghold.
            Server():setValue("eclipse_stronghold_" .. x .. "_" .. y, true)
        end
    end
end

if onServer() then
    local oldInit = initialize or function() end
    function initialize()
        oldInit()
        CosmicAscendancyServer.initialize()
    end
end


-- Global Event Callbacks
local old_onSectorGenerated = onSectorGenerated
function onSectorGenerated(...)
    if old_onSectorGenerated then old_onSectorGenerated(...) end
    if CosmicAscendancyServer.onSectorGenerated then return CosmicAscendancyServer.onSectorGenerated(...) end
end
