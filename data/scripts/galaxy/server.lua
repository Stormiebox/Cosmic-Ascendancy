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
        
        Server():registerCallback("onSectorGenerated", "onSectorGenerated")
    end
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
            
            -- Spawn an Eclipse Station (Citadel shape)
            local station = EclipseGenerator.createStation(Matrix())
            station:addScript("entity/deleteonplayersleft.lua")
            
            -- Spawn some defenders (Mix of specialized ships)
            local defenderTypes = {"pyramid", "voidweaver", "phantom", "singularity", "juggernaut", "interceptor", "harvester", "defiler"}
            for i = 1, 4 do
                local typeIdx = random():getInt(1, #defenderTypes)
                local sType = defenderTypes[typeIdx]
                local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random():getInt(-1000, 1000), 0, random():getInt(-1000, 1000)))
                
                local defender
                if sType == "voidweaver" then
                    defender = EclipseGenerator.createCarrier(pos)
                elseif sType == "phantom" then
                    defender = EclipseGenerator.createAssassin(pos)
                elseif sType == "singularity" then
                    defender = EclipseGenerator.createArtillery(pos)
                elseif sType == "juggernaut" then
                    defender = EclipseGenerator.createJuggernaut(pos)
                elseif sType == "interceptor" then
                    defender = EclipseGenerator.createInterceptor(pos)
                elseif sType == "harvester" then
                    defender = EclipseGenerator.createHarvester(pos)
                elseif sType == "defiler" then
                    defender = EclipseGenerator.createDefiler(pos)
                else
                    defender = EclipseGenerator.createShip(pos, sType)
                end
                
                defender:addScript("ai/patrol.lua")
            end
            
            Sector():setValue("is_eclipse_stronghold", true)
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
