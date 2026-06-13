package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

mission._Name = "The Vanguard Assault"
mission._Debug = 0

mission.data.description = "The Eclipse are mounting a massive assault. Defend the sector!"
mission.data.title = "The Vanguard Assault"

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description = "A massive Eclipse Vanguard Dreadnought is warping in! Destroy it."
    
    local generator = require("shipgenerator")
    local faction = Galaxy():getFaction("The Eclipse") or Faction(1)
    local boss = generator.createMilitaryShip(faction, Matrix(), Sector():getCoordinates())
    boss.title = "Eclipse Vanguard Dreadnought"
    boss:setValue("ca_eclipse_boss", true)
    
    local d = boss.damageMultiplier or 1
    boss.damageMultiplier = d * 5
end

mission.phases[1].updateServer = function()
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #boss == 0 then
        Player():sendChatMessage("Ship Computer", 0, "The Dreadnought is destroyed! The sector is safe.")
        Player():setValue("ca_campaign_completed", true)
        
        -- Give Reward
        local system = SystemUpgradeTemplate("data/scripts/systems/ascendanteclipsebane.lua", Rarity(5), Seed(123))
        Player():getInventory():add(system)
        Player():sendChatMessage("Reward", 2, "Received The Eclipse Bane artifact!")
        
        finish()
    end
end
