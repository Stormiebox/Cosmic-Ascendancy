package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace WorldEaterEvent
WorldEaterEvent = {}
WorldEaterEvent.worldEaterId = nil
WorldEaterEvent.encounterId = nil
WorldEaterEvent.engaged = false
local MANAGER = "data/scripts/galaxy/ca_world_eater_manager.lua"

-- ca_world_eater_manager.lua's injectSectorScript still passes the remaining countdown as an
-- extra addScriptOnce argument (for a possible future "time remaining" HUD display), but nothing
-- here reads it -- the manager keeps its own separate authoritative timeLeft in activeEvent.
function WorldEaterEvent.initialize(timeLeft, encounterId)
    if not onServer() then return end
    if type(encounterId) ~= "string" then
        terminate()
        return
    end
    WorldEaterEvent.encounterId = encounterId

    local EclipseGenerator = include("eclipsegenerator")
    -- Spawn far away
    local mat = MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), vec3(10000, 5000, -10000))
    local ship = EclipseGenerator.createWorldEater(mat)

    if not valid(ship) then
        Galaxy():invokeFunction(MANAGER, "reportMaterializationFailure", encounterId, "boss_spawn_failed")
        terminate()
        return
    end

    -- See EclipseGenerator.applyWorldEaterMultiplayerScaling for why this runs here rather than
    -- inside createWorldEater() itself (also called from ca_raid_summoner.lua for the same reason).
    EclipseGenerator.applyWorldEaterMultiplayerScaling(ship)
    local spawnedEntities = {ship}

    -- Spawn the Royal Escort Fleet
    local dir = mat.look
    local right = mat.right
    local up = mat.up
    local center = mat.translation

    -- 2 Carriers
    for i = 1, 2 do
        local pos = center + (right * (i == 1 and 2000 or -2000)) + (dir * -1000)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        local escort = EclipseGenerator.createCarrier(cMat)
        if valid(escort) then
            escort:setValue("ca_encounter_id", encounterId)
            table.insert(spawnedEntities, escort)
        end
    end

    -- 2 Artillery Ships
    for i = 1, 2 do
        local pos = center + (up * (i == 1 and 1500 or -1500)) + (dir * -2000)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        local escort = EclipseGenerator.createArtillery(cMat)
        if valid(escort) then
            escort:setValue("ca_encounter_id", encounterId)
            table.insert(spawnedEntities, escort)
        end
    end

    -- 4 Defilers
    for i = 1, 4 do
        local pos = center + (right * ((i%2 == 0 and 1 or -1) * (1000 + i*500))) + (dir * 500)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        local escort = EclipseGenerator.createDefiler(cMat)
        if valid(escort) then
            escort:setValue("ca_encounter_id", encounterId)
            table.insert(spawnedEntities, escort)
        end
    end

    -- 8 Interceptors
    for i = 1, 8 do
        local rx = (random():getFloat(-1, 1) * 3000)
        local ry = (random():getFloat(-1, 1) * 3000)
        local rz = (random():getFloat(500, 2500))
        local pos = center + vec3(rx, ry, rz)
        local cMat = MatrixLookUpPosition(up, dir, pos)
        local escort = EclipseGenerator.createInterceptor(cMat)
        if valid(escort) then
            escort:setValue("ca_encounter_id", encounterId)
            table.insert(spawnedEntities, escort)
        end
    end

    WorldEaterEvent.worldEaterId = ship.id.string
    ship:setValue("ca_encounter_id", encounterId)
    if ship:getValue("ca_encounter_id") ~= encounterId then
        for _, spawned in ipairs(spawnedEntities) do
            if valid(spawned) then Sector():deleteEntity(spawned) end
        end
        WorldEaterEvent.worldEaterId = nil
        Galaxy():invokeFunction(MANAGER, "reportMaterializationFailure", encounterId, "boss_tag_failed")
        terminate()
        return
    end
    ship:registerCallback("onDestroyed", "onWorldEaterDestroyed")
    local resultCode, confirmed = Galaxy():invokeFunction(
        MANAGER, "confirmEngaged", encounterId, WorldEaterEvent.worldEaterId)
    WorldEaterEvent.engaged = resultCode == 0 and confirmed == true
    
    Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    -- Start music for players already present
    for _, player in pairs({Sector():getPlayers()}) do
        player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
        player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerBossMusic", 1)
    end
end

function WorldEaterEvent.onPlayerEntered(playerIndex)
    local player = Player(playerIndex)
    -- If the boss already enraged before this player arrived (see the p35 branch in
    -- ca_worldeater_behavior.lua), start them on the enraged track instead of always defaulting to phase 1.
    local phase = Sector():getValue("ca_worldeater_enraged") and 2 or 1
    player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
    player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerBossMusic", phase)
end

function WorldEaterEvent.onWorldEaterDestroyed()
    if not onServer() then return end
    if not WorldEaterEvent.engaged then return end
    local resultCode, resolved = Galaxy():invokeFunction(
        MANAGER, "resolveEvent", WorldEaterEvent.encounterId, WorldEaterEvent.worldEaterId)
    if resultCode == 0 and resolved then terminate() end
end

function WorldEaterEvent.getUpdateInterval()
    return WorldEaterEvent.engaged and 60 or 5
end

function WorldEaterEvent.updateServer(timeStep)
    if WorldEaterEvent.engaged or not WorldEaterEvent.encounterId
            or not WorldEaterEvent.worldEaterId then return end
    local ship = Entity(Uuid(WorldEaterEvent.worldEaterId))
    if not valid(ship) then return end
    local resultCode, confirmed = Galaxy():invokeFunction(
        MANAGER, "confirmEngaged", WorldEaterEvent.encounterId, WorldEaterEvent.worldEaterId)
    WorldEaterEvent.engaged = resultCode == 0 and confirmed == true
end

function WorldEaterEvent.secure()
    return {
        worldEaterId = WorldEaterEvent.worldEaterId,
        encounterId = WorldEaterEvent.encounterId,
        engaged = WorldEaterEvent.engaged
    }
end

function WorldEaterEvent.restore(data)
    if data then
        WorldEaterEvent.worldEaterId = data.worldEaterId
        WorldEaterEvent.encounterId = data.encounterId
        WorldEaterEvent.engaged = data.engaged == true
        
        if WorldEaterEvent.worldEaterId then
            local ship = Entity(Uuid(WorldEaterEvent.worldEaterId))
            if valid(ship) then
                ship:registerCallback("onDestroyed", "onWorldEaterDestroyed")
            else
                -- A loaded sector with an absent registered boss is ambiguous; it is never victory.
                Galaxy():invokeFunction(MANAGER, "reportMissingBoss",
                    WorldEaterEvent.encounterId, WorldEaterEvent.worldEaterId)
            end
        end
    end
end

