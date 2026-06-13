package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

mission._Name = "The Eclipse Awakening"
mission._Debug = 0

mission.data.description = "The Wormhole Guardian was a seal. Now that it is broken, investigate the anomalous energy readings the Hermit provided."
mission.data.title = "The Eclipse Awakening"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Jump to the coordinates the Hermit provided: (" .. targetX .. ":" .. targetY .. ")"
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "An Eclipse Vanguard ambush! Survive the attack."
    -- Spawn Eclipse enemies
    local generator = require("shipgenerator")
    local faction = Galaxy():getFaction("The Eclipse") or Faction(1)
    for i = 1, 3 do
        local ship = generator.createMilitaryShip(faction, Matrix(), Sector():getCoordinates())
        ship.title = "Eclipse Vanguard Scout"
        ship:setValue("ca_eclipse_ambush", true)
    end
end

mission.phases[2].updateServer = function(timeStep)
    local enemies = {Sector():getEntitiesByScriptValue("ca_eclipse_ambush")}
    if #enemies == 0 then
        Player():sendChatMessage("Ship Computer", 0, "Hostiles eliminated. Returning to base.")
        Player():addScriptOnce("data/scripts/player/missions/ca_story2_forge.lua")
        finish()
    end
end

function getTargetSector(x, y)
    local random = Random()
    return x + random:getInt(-5, 5), y + random:getInt(-5, 5)
end
