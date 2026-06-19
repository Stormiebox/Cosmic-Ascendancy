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
        local EclipseGenerator = include("eclipsegenerator")
        local Placer = include("placer")

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
        local citadel = EclipseGenerator.createShip(Matrix(), "monolith")
        citadel:setTitle("Eclipse Citadel", {})
        table.insert(spawned, citadel)

        -- Spawn defending fleet
        local numDefenders = random:getInt(5, 8)
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
                ship = EclipseGenerator.createShip(shipPos, "monolith")
            elseif r < 0.875 then
                ship = EclipseGenerator.createShip(shipPos, "obelisk")
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
                Galaxy():addScriptOnce("data/scripts/galaxy/eclipse_conquest_manager.lua")
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
        -- 60% chance to invade a player's sector personally
        if random():getFloat(0, 1) > 0.4 then
            player:addScript("data/scripts/player/events/eclipseinvasion.lua")
        end
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

-- Global Event Callbacks
function onSectorGenerated(...)
    if EclipseAwakes.onSectorGenerated then return EclipseAwakes.onSectorGenerated(...) end
end
