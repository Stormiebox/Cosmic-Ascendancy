package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "Forging the Defense"
mission._Debug = 0

mission.data.description = "The Eclipse are real, and they possess shielding technology far beyond our current capabilities. The Adventurer mentioned an ancient schematic for an 'Ascendancy Forge'."
mission.data.title = "Forging the Defense"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "The Adventurer gave you a set of ancient encrypted coordinates. Jump to (" .. targetX .. ":" .. targetY .. ") to investigate."
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Ship Sensors", 3, "Scans indicate massive subterranean ruins on the largest asteroid in this sector. Sending surface rovers to investigate...")
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description = "Rovers are exploring the subterranean ruins. Protect the sector and wait for their report."
    mission.data.custom.waitTime = Server().unpausedRuntime + 30 -- Wait 30 seconds
    
    Player():sendChatMessage("Rover Alpha", 0, "Commander, we're inside the ruins. It's an ancient manufacturing facility. The databanks are mostly corrupted, but we're attempting a direct download of the main schematics now.")
end

mission.phases[2].updateServer = function()
    if Server().unpausedRuntime >= mission.data.custom.waitTime then
        Player():sendChatMessage("Rover Alpha", 0, "Download complete! It's blueprints for an 'Ascendancy Forge'. We're returning to the ship.")
        Player():sendChatMessage("Ship Computer", 0, "Analyzing blueprints... This structure requires an immense amount of raw materials to construct. Specifically, Avorion.")
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description = "To power the Ascendancy Forge's primary reactor, you need to gather an initial supply of 50,000 Avorion."
end

mission.phases[3].updateServer = function()
    local player = Player()
    local iron, tit, nao, tri, xan, ogo, avo = player:getResources()
    if avo >= 50000 then
        player:pay(0, 0, 0, 0, 0, 0, 0, 50000)
        Player():sendChatMessage("Ship Computer", 0, "50,000 Avorion gathered and fed into the primary reactor schematic. Ascendancy Forge blueprints are fully unlocked and ready for construction.")
        Player():setValue("ca_forge_unlocked", true)
        Player():addScriptOnce("data/scripts/player/missions/ca_story3_vanguard.lua")
        finish()
    end
end

function getTargetSector(x, y)
    local random = Random()
    return x + random:getInt(-8, 8), y + random:getInt(-8, 8)
end