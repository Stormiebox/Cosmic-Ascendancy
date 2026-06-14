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
    
    -- Only generate inside the barrier
    local d2 = x*x + y*y
    if d2 > 150 * 150 then return end
    
    -- 25% chance to be an Eclipse Stronghold
    local seed = server.seed
    local random = Random(Seed(seed + x + y))
    
    if random:getFloat() < 0.25 then
        local EclipseGenerator = include("eclipsegenerator")
        local Placer = include("placer")
        local SectorTurretGenerator = include("sectorturretgenerator")
        
        local sector = Sector()
        sector.name = "Eclipse Stronghold"%_T
        
        -- Wipe any existing generated structures since this is Eclipse territory now
        local entities = {sector:getEntities()}
        for _, entity in pairs(entities) do
            if entity.type == EntityType.Station or entity.type == EntityType.Ship then
                sector:deleteEntity(entity)
            end
        end

        local spawned = {}
        
        -- Center Citadel
        local citadel = EclipseGenerator.createStation(Matrix())
        table.insert(spawned, citadel)
        
        -- Spawn defending fleet
        local numDefenders = random():getInt(5, 8)
        local dir = normalize(vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)))
        local up = vec3(0, 1, 0)
        local right = normalize(cross(dir, up))
        local pos = dir * 500
        
        for i = 1, numDefenders do
            local shipPos = MatrixLookUpPosition(-dir, up, pos + right * random:getFloat(-200, 200))
            local r = random:getFloat()
            local ship
            if r < 0.125 then
                ship = EclipseGenerator.createCarrier(shipPos)
            elseif r < 0.25 then
                ship = EclipseGenerator.createAssassin(shipPos)
            elseif r < 0.375 then
                ship = EclipseGenerator.createArtillery(shipPos)
            elseif r < 0.5 then
                ship = EclipseGenerator.createJuggernaut(shipPos)
            elseif r < 0.625 then
                ship = EclipseGenerator.createInterceptor(shipPos)
            elseif r < 0.75 then
                ship = EclipseGenerator.createHarvester(shipPos)
            elseif r < 0.875 then
                ship = EclipseGenerator.createDefiler(shipPos)
            else
                ship = EclipseGenerator.createShip(shipPos, "pyramid")
            end
            table.insert(spawned, ship)
        end
        
        Placer.resolveIntersections(spawned)
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
    local players = {Server():getPlayers()}
    for _, player in pairs(players) do
        -- 60% chance to invade a player's sector
        if random():getFloat(0, 1) > 0.4 then
            player:addScript("data/scripts/player/events/eclipseinvasion.lua")
        end
    end
end

return EclipseAwakes
