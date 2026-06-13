package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local EclipseGenerator = include("eclipsegenerator")
local Placer = include ("placer")

local minute = 0

if onServer() then

function initialize()
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

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    local spawned = {}
    
    -- Spawn 1 Harbinger (Boss)
    local harbinger = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), "obelisk")
    table.insert(spawned, harbinger)
    pos = pos + right * 200

    -- Spawn 3 randomized heavy/specialized ships (Obliterator, Void-Weaver, Singularity)
    local heavyTypes = {"monolith", "voidweaver", "singularity"}
    for i = 1, 3 do
        local hType = heavyTypes[math.random(1, #heavyTypes)]
        local heavy
        if hType == "voidweaver" then heavy = EclipseGenerator.createCarrier(MatrixLookUpPosition(-dir, up, pos))
        elseif hType == "singularity" then heavy = EclipseGenerator.createArtillery(MatrixLookUpPosition(-dir, up, pos))
        else heavy = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), hType) end
        
        table.insert(spawned, heavy)
        pos = pos + right * 200
    end

    -- Spawn 4 randomized light/specialized ships (Nullifier, Phantom)
    local lightTypes = {"pyramid", "phantom"}
    for i = 1, 4 do
        local lType = lightTypes[math.random(1, #lightTypes)]
        local light
        if lType == "phantom" then light = EclipseGenerator.createAssassin(MatrixLookUpPosition(-dir, up, pos))
        else light = EclipseGenerator.createShip(MatrixLookUpPosition(-dir, up, pos), lType) end
        
        table.insert(spawned, light)
        pos = pos + right * 150
    end

    Placer.resolveIntersections(spawned)
    AlertAbsentPlayers(ChatMessageType.Warning, "The Eclipse has invaded sector \\s(%1%:%2%)!"%_t, sector:getCoordinates())
end

end
