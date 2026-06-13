package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

mission._Name = "Forging the Defense"
mission._Debug = 0

mission.data.description = "The Eclipse are real. You must build the Ascendancy Forge to prepare for the invasion."
mission.data.title = "Forging the Defense"

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description = "The Adventurer has given you the blueprints. Gather 50,000 Avorion to power the Ascendancy Forge."
end

mission.phases[1].updateServer = function()
    local player = Player()
    local avorion = player:getInventory():getAmount(Material(6).value)
    if avorion >= 50000 then
        player:getInventory():remove(Material(6).value, 50000)
        Player():sendChatMessage("Ship Computer", 0, "Materials gathered. Ascendancy Forge blueprints unlocked!")
        Player():setValue("ca_forge_unlocked", true)
        Player():addScriptOnce("data/scripts/player/missions/ca_story3_vanguard.lua")
        finish()
    end
end
