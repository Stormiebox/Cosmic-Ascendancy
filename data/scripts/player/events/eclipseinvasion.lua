package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("player")
include("randomext")
local EclipseGenerator = include("eclipsegenerator")
local Placer = include ("placer")

local cv_fleet = include("cosmicvaultfleet")

local minute = 0
-- Eclipse Remembers: how many extra heavy-class ships this specific ambush gets, driven by the
-- targeted player's own eclipse_kill_score (see EclipseConquestManager.expandEmpire()'s Personal
-- Ambush Logic, the only caller that ever passes this). Defaults to 0 (the original fixed
-- composition) for any other caller/legacy save that attaches this without an argument.
local extraHeavies = 0

if onServer() then

function initialize(extraHeaviesArg)
    extraHeavies = extraHeaviesArg or 0
    deferredCallback(1.0, "update", 1.0)
end

function getUpdateInterval()
    return 60
end

function update(timeStep)
    minute = minute + 1

    if minute == 1 then
        Player():sendChatMessage("Server", 3, "Your sensors are screaming... Subspace is tearing apart!"%_t)
    elseif minute == 2 then
        Player():sendChatMessage("Server", 3, "WARNING: Massive Eclipse signatures detected! Brace for impact!"%_t)
    elseif minute == 3 then
        createEnemies()
        Player():sendChatMessage("Server", 2, "The Eclipse have arrived! Defend yourself!"%_t)
        terminate()
    end
end

function createEnemies()
    local sector = Sector()
    if not sector then return end


    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    local spawned = {}

    -- Spawn 1 Harbinger (Boss)
    local harbinger = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), "ca_harbinger")
    table.insert(spawned, harbinger)
    pos = pos + right * 200

    -- Spawn 3 randomized heavy/specialized ships, plus extraHeavies more if Eclipse Remembers
    -- this player specifically (capped so a maxed-out kill score can't spawn an unbounded fleet).
    local heavyTypes = {"ca_voidweaver", "ca_singularity", "ca_juggernaut", "ca_defiler"}
    local heavyCount = 3 + math.min(extraHeavies, 4)
    for i = 1, heavyCount do
        local hType = heavyTypes[random():getInt(1, #heavyTypes)]
        local heavy
        if hType == "ca_voidweaver" then heavy = EclipseGenerator.createCarrier(MatrixLookUpPosition(-dir, up, pos))
        elseif hType == "ca_singularity" then heavy = EclipseGenerator.createArtillery(MatrixLookUpPosition(-dir, up, pos))
        elseif hType == "ca_juggernaut" then heavy = EclipseGenerator.createJuggernaut(MatrixLookUpPosition(-dir, up, pos))
        elseif hType == "ca_defiler" then heavy = EclipseGenerator.createDefiler(MatrixLookUpPosition(-dir, up, pos))
        else heavy = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), hType) end

        table.insert(spawned, heavy)
        pos = pos + right * 200
    end

    -- Spawn 4 randomized light/specialized ships
    local lightTypes = {"ca_obliterator", "ca_phantom", "ca_interceptor", "ca_harvester"}
    for i = 1, 4 do
        local lType = lightTypes[random():getInt(1, #lightTypes)]
        local light
        if lType == "ca_phantom" then light = EclipseGenerator.createAssassin(MatrixLookUpPosition(-dir, up, pos))
        elseif lType == "ca_interceptor" then light = EclipseGenerator.createInterceptor(MatrixLookUpPosition(-dir, up, pos))
        elseif lType == "ca_harvester" then light = EclipseGenerator.createHarvester(MatrixLookUpPosition(-dir, up, pos))
        else light = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), lType) end

        table.insert(spawned, light)
        pos = pos + right * 150
    end

    Placer.resolveIntersections(spawned)

    -- Cosmic Ascendancy - The Eclipse Rift Spillage
    -- 10% chance to weaponize subspace during an invasion
    if random():test(0.1) then
        local stabilizerPos = MatrixLookUpPosition(-dir, up, pos + right * 300)
        local stabilizer = EclipseGenerator.createStation(stabilizerPos)
        stabilizer.title = "Eclipse Rift Stabilizer"
        -- createStation() is the mod's only station factory, so it's also the only option here, but
        -- it unconditionally attaches the Lockdown Matrix (entity/ca_citadel_blocker.lua), which
        -- prevents jumping out of the sector until the structure is destroyed. That's the correct
        -- behavior for an actual Citadel siege objective, but this Stabilizer is a random 10% side
        -- effect of a single-player personal ambush, not a deliberate invasion the player chose to
        -- engage. The WIKI's own description of Rift Spillage only promises a shield-draining
        -- hazard, never being trapped in the sector by a full 200M-HP structure. Remove just the
        -- trapping behavior so the hazard matches what's actually documented. The rest of
        -- createStation()'s stats and loot are left as-is.
        stabilizer:removeScript("entity/ca_citadel_blocker.lua")
        stabilizer:addScriptOnce("entity/ca_rift_stabilizer.lua")
        table.insert(spawned, stabilizer)

        -- Start the environmental hazard
        sector:addScriptOnce("sector/ca_rift_hazard.lua")
        sector:broadcastChatMessage("System", 3, "WARNING: The Eclipse have weaponized a subspace tear! Local shields are draining!"%_t)
    end

    if cv_fleet.orderAttackEnemies then
        for _, ship in pairs(spawned) do
            if valid(ship) then
                cv_fleet.orderAttackEnemies(ship.index, true)
            end
        end
    end

    AlertAbsentPlayers(ChatMessageType.Warning, "The Eclipse has invaded sector \\s(%1%:%2%)!"%_t, sector:getCoordinates())
end

end
