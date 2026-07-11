package.path = package.path .. ";data/scripts/lib/?.lua"

local Detonation = {}
Detonation.posX = 0
Detonation.posY = 0
Detonation.posZ = 0
Detonation.timer = 0
Detonation.factionIndex = 0

function Detonation.initialize(x, y, z, factionIndex)
    if not onServer() then return end
    Detonation.posX = x
    Detonation.posY = y
    Detonation.posZ = z
    Detonation.factionIndex = factionIndex or -1

    local sector = Sector()
    sector:createGlow(vec3(x, y, z), 1500, ColorRGB(1.0, 0.0, 0.0))
end

function Detonation.getUpdateInterval()
    -- Fast interval for gravity pull
    return 0.2
end

function Detonation.updateServer(timeStep)
    Detonation.timer = Detonation.timer + timeStep
    local sector = Sector()
    local pos = vec3(Detonation.posX, Detonation.posY, Detonation.posZ)

    -- Gravitational Pull Phase (Windup)
    if Detonation.timer < 3.0 then
        local ships = {sector:getEntitiesByType(EntityType.Ship)}
        for _, ship in pairs(ships) do
            if valid(ship) and ship.factionIndex ~= Detonation.factionIndex then
                local dist = distance(ship.translationf, pos)
                if dist <= 1500.0 then
                    local dir = normalize(pos - ship.translationf)
                    local vel = Velocity(ship.id)
                    if valid(vel) then
                        -- Pull them into the core and cripple their escape velocity
                        vel.velocity = vel.velocity + (dir * 250.0 * timeStep)
                        vel.velocity = vel.velocity * 0.5
                    end
                end
            end
        end
    else
        -- Detonation Phase
        sector:createExplosion(pos, 1500, true)
        sector:createGlow(pos, 3000, ColorRGB(1.0, 0.0, 0.0))

        local function blastTarget(target)
            if valid(target) and target.factionIndex ~= Detonation.factionIndex and not target.invincible then
                local dist = distance(target.translationf, pos)
                if dist <= 1500.0 then
                    target.durability = math.max(1, target.durability - 250000)
                end
            end
        end

        local ships = {sector:getEntitiesByType(EntityType.Ship)}
        local stations = {sector:getEntitiesByType(EntityType.Station)}
        for _, s in pairs(ships) do blastTarget(s) end
        for _, s in pairs(stations) do blastTarget(s) end

        sector:removeScript("ca_singularity_detonation.lua")
    end
end

function Detonation.secure()
    return {
        posX = Detonation.posX,
        posY = Detonation.posY,
        posZ = Detonation.posZ,
        timer = Detonation.timer,
        factionIndex = Detonation.factionIndex
    }
end

function Detonation.restore(data)
    data = data or {}
    Detonation.posX = data.posX or 0
    Detonation.posY = data.posY or 0
    Detonation.posZ = data.posZ or 0
    Detonation.timer = data.timer or 0
    Detonation.factionIndex = data.factionIndex or -1
end

function initialize(...)
    if Detonation.initialize then return Detonation.initialize(...) end
end
function getUpdateInterval(...)
    if Detonation.getUpdateInterval then return Detonation.getUpdateInterval(...) end
end
function updateServer(...)
    if Detonation.updateServer then return Detonation.updateServer(...) end
end
function secure(...)
    if Detonation.secure then return Detonation.secure(...) end
end
function restore(...)
    if Detonation.restore then return Detonation.restore(...) end
end
