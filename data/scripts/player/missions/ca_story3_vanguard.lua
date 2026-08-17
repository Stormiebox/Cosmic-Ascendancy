package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Vanguard Assault"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "The Eclipse are mounting a massive assault against your position. They have tracked the energy signature of the Ascendancy Forge blueprints."
mission.data.title = "The Vanguard Assault"

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    mission.data.custom.targetX = x
    mission.data.custom.targetY = y
    
    mission.data.description = "A massive Eclipse Vanguard Juggernaut is warping in! Defend the sector at all costs."
    
    local EclipseGenerator = include("eclipsegenerator")
    local faction = EclipseGenerator.getFaction()
    
    local existingBoss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #existingBoss == 0 then
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
        
        Player():sendChatMessage("The Eclipse", 2, "Your primitive, chaotic constructs are an insult to absolute order. The Ascendants' Forge belongs to us. Relinquish it, and your sanitation will be swift.")
    end
    mission.data.custom.bossSpawned = true
end

mission.phases[1].updateServer = function()
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then return end
    
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_boss")}
    if #boss == 0 then
        Player():sendChatMessage("Ship Computer", 0, "The Juggernaut is destroyed! Its core is destabilizing... wait, it's beaming a data packet to the rest of their fleet!")
        Player():sendChatMessage("The Eclipse", 2, "Vanguard lost. Biological chaotic resistance exceeds parameters... Threat level updated. Full galactic sanitation authorized.")
        
        Player():setValue("ca_campaign_completed", nil) -- We no longer end the campaign here
        
        -- Give Reward
        local system = SystemUpgradeTemplate("data/scripts/systems/ascendanteclipsebane.lua", Rarity(5), Seed(123))
        Player():getInventory():add(system)
        Player():sendChatMessage("Reward", 2, "Recovered 'The Eclipse Bane' artifact from the wreckage!")
        
        Player():sendChatMessage("Aegis", 0, "The Vanguard is destroyed, but their transmission went through. We must prepare for what comes next. Meet me at these coordinates.")
        
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ")."
end

mission.phases[2].onSectorEntered = function(x, y)
    if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
        local aegisExists = false
        local entities = {Sector():getEntitiesByScript("entity/story/ca_ascendant_envoy.lua")}
        if #entities > 0 then
            aegisExists = true
        end
        if not aegisExists then
            local generator = include("SectorGenerator")(Sector():getCoordinates())
            local faction = Galaxy():getNearestFaction(0, 0)
            local ship = generator:createShip(faction, "data/scripts/entity/story/ca_ascendant_envoy.lua")
            ship.name = "Aegis, The Ascendant Envoy"
            ship.title = "Ascendant AI Construct"
            ship:setInvincible(true)
            ship.dockable = false
            ship:addScriptOnce("entity/ca_envoy_despawn.lua")
            local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
            if plan then ship:setPlan(plan) end
            local ShipUtility = include("shiputility")
            ShipUtility.addTurretsToCraft(ship, nil, 0, 0)
            Player():sendChatMessage(ship.name, 0, "Commander. Approach my projection and initiate contact.")
        end
        Player():setValue("ca_ready_for_debrief_3", true)
    end
end

function getTargetSector(x, y)
    local MissionUT = include("missionutility")
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local targetX, targetY = MissionUT.getEmptySector(x, y, 5, 30, insideBarrier)
    
    if not targetX or not targetY then 
        local random = Random()
        return x + random:getInt(-30, 30), y + random:getInt(-30, 30)
    end
    
    return targetX, targetY
end