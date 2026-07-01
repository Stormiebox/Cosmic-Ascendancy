package.path = package.path .. ";data/scripts/lib/?.lua"

local Detonation = {}
Detonation.posX = 0
Detonation.posY = 0
Detonation.posZ = 0
Detonation.timer = 0

function Detonation.initialize(x, y, z)
    if not onServer() then return end
    Detonation.posX = x
    Detonation.posY = y
    Detonation.posZ = z

    -- Visual warning indicator at the core location
    local sector = Sector()
    sector:createGlow(vec3(x, y, z), 300, ColorRGB(1.0, 0.0, 0.0))
end

function Detonation.getUpdateInterval()
    return 3.0
end

function Detonation.updateServer(timeStep)
    Detonation.timer = Detonation.timer + timeStep

    if Detonation.timer >= 3.0 then
        local sector = Sector()
        local pos = vec3(Detonation.posX, Detonation.posY, Detonation.posZ)

        -- Create massive visual explosion
        sector:createExplosion(pos, 300, true)
        sector:createGlow(pos, 600, ColorRGB(1.0, 0.0, 0.0))

        -- Deal massive true damage in a 3km radius
        local players = {sector:getPlayers()}
        for _, p in pairs(players) do
            local ship = p.craft
            if ship then
                local dist = distance(ship.translationf, pos)
                if dist <= 300.0 then
                    ship.durability = math.max(1, ship.durability - 50000) -- True damage, leaves them at 1 HP minimum
                end
            end
        end

        -- Detonation complete, remove script from Sector
        sector:removeScript("ca_singularity_detonation.lua")
    end
end

function Detonation.secure()
    return {
        posX = Detonation.posX,
        posY = Detonation.posY,
        posZ = Detonation.posZ,
        timer = Detonation.timer
    }
end

function Detonation.restore(data)
    data = data or {}
    Detonation.posX = data.posX or 0
    Detonation.posY = data.posY or 0
    Detonation.posZ = data.posZ or 0
    Detonation.timer = data.timer or 0
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
