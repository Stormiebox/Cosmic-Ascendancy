package.path = package.path .. ";data/scripts/lib/?.lua"

local WorldEaterEvent = {}
WorldEaterEvent.worldEaterId = nil

function WorldEaterEvent.initialize(timeLeft)
    if not onServer() then return end

    local EclipseGenerator = include("eclipsegenerator")
    -- Spawn far away
    local mat = MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), vec3(10000, 5000, -10000))
    local ship = EclipseGenerator.createWorldEater(mat)

    if not valid(ship) then 
        WorldEaterEvent.onWorldEaterDestroyed()
        return 
    end

    -- Spawn the Royal Escort Fleet
    local dir = mat.look
    local right = mat.right
    local up = mat.up
    local center = mat.translation

    -- 2 Carriers
    for i = 1, 2 do
        local pos = center + (right * (i == 1 and 2000 or -2000)) + (dir * -1000)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        EclipseGenerator.createCarrier(cMat)
    end

    -- 2 Artillery Ships
    for i = 1, 2 do
        local pos = center + (up * (i == 1 and 1500 or -1500)) + (dir * -2000)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        EclipseGenerator.createArtillery(cMat)
    end

    -- 4 Defilers
    for i = 1, 4 do
        local pos = center + (right * ((i%2 == 0 and 1 or -1) * (1000 + i*500))) + (dir * 500)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        EclipseGenerator.createDefiler(cMat)
    end

    -- 8 Interceptors
    for i = 1, 8 do
        local rx = (random():getFloat(-1, 1) * 3000)
        local ry = (random():getFloat(-1, 1) * 3000)
        local rz = (random():getFloat(500, 2500))
        local pos = center + vec3(rx, ry, rz)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        EclipseGenerator.createInterceptor(cMat)
    end

    ship:registerCallback("onDestroyed", "onWorldEaterDestroyed")
    WorldEaterEvent.worldEaterId = ship.id.string
    
    Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    -- Start music for players already present
    for _, player in pairs({Sector():getPlayers()}) do
        player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
        player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerBossMusic", 1)
    end
end

function WorldEaterEvent.onPlayerEntered(playerIndex)
    local player = Player(playerIndex)
    player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
    player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerBossMusic", 1)
end

function WorldEaterEvent.onWorldEaterDestroyed()
    if not onServer() then return end
    local galaxy = Galaxy()
    galaxy:invokeFunction("data/scripts/galaxy/ca_world_eater_manager.lua", "cancelEvent")
    terminate()
end

function WorldEaterEvent.secure()
    return {worldEaterId = WorldEaterEvent.worldEaterId}
end

function WorldEaterEvent.restore(data)
    if data then
        WorldEaterEvent.worldEaterId = data.worldEaterId
        
        if WorldEaterEvent.worldEaterId then
            local ship = Entity(Uuid(WorldEaterEvent.worldEaterId))
            if valid(ship) then
                ship:registerCallback("onDestroyed", "onWorldEaterDestroyed")
            else
                -- Boss is dead/missing upon loading the sector
                WorldEaterEvent.onWorldEaterDestroyed()
            end
        end
    end
end

function initialize(...)
    if WorldEaterEvent.initialize then return WorldEaterEvent.initialize(...) end
end

function secure(...)
    if WorldEaterEvent.secure then return WorldEaterEvent.secure(...) end
end

function restore(...)
    if WorldEaterEvent.restore then return WorldEaterEvent.restore(...) end
end

-- Global Event Callbacks
function onWorldEaterDestroyed(...)
    if WorldEaterEvent.onWorldEaterDestroyed then return WorldEaterEvent.onWorldEaterDestroyed(...) end
end

function onPlayerEntered(...)
    if WorldEaterEvent.onPlayerEntered then return WorldEaterEvent.onPlayerEntered(...) end
end
