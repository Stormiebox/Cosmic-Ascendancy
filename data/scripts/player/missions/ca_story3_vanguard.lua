package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Vanguard Assault"
mission._Debug = 0

mission.data.description = "The Eclipse are mounting a massive assault against your position. They have tracked the energy signature of the Ascendancy Forge blueprints."
mission.data.title = "The Vanguard Assault"

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description = "A massive Eclipse Vanguard Juggernaut is warping in! Defend the sector at all costs."
    
    local EclipseGenerator = require("eclipsegenerator")
    local faction = EclipseGenerator.getFaction()
    
    -- Spawn Boss
    local dir = normalize(vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1)))
    local pos = dir * 1500
    local boss = EclipseGenerator.createJuggernaut(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
    
    boss:setValue("ca_eclipse_boss", true)
    
    -- Add 4 Interceptors as escorts
    for i = 1, 4 do
        local escortPos = MatrixLookUpPosition(-dir, vec3(0,1,0), pos + vec3(random():getFloat(-200, 200), random():getFloat(-200, 200), random():getFloat(-200, 200)))
        local escort = EclipseGenerator.createInterceptor(escortPos)
        escort:setValue("ca_eclipse_ambush", true)
    end
    
    Player():sendChatMessage("The Eclipse", 2, "Your primitive constructs are an insult to the void. The Forge belongs to us. Relinquish it, and your eradication will be swift.")
end

mission.phases[1].updateServer = function()
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #boss == 0 then
        Player():sendChatMessage("Ship Computer", 0, "The Juggernaut is destroyed! Its core is destabilizing... wait, it's beaming a data packet to the rest of their fleet!")
        Player():sendChatMessage("The Eclipse", 2, "Vanguard lost. Assessing biological resistance... Threat level updated. Full galactic cleanse authorized.")
        
        Player():setValue("ca_campaign_completed", true)
        
        -- Give Reward
        local system = SystemUpgradeTemplate("data/scripts/systems/ascendanteclipsebane.lua", Rarity(5), Seed(123))
        Player():getInventory():add(system)
        Player():sendChatMessage("Reward", 2, "Recovered 'The Eclipse Bane' artifact from the wreckage!")
        
        finish()
    end
end