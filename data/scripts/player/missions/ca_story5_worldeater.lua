package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The World-Eater"
mission._Debug = 0

mission.data.description = "The destruction of the Citadel has triggered a massive response. An Eclipse World-Eater—a ship designed to consume entire stars—has breached our dimension."
mission.data.title = "The World-Eater"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Aegis has locked onto the World-Eater's dimensional wake. Jump to (" .. targetX .. ":" .. targetY .. ") and destroy it before it reaches the core systems!"
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Aegis", 0, "It is here. The scale is... unprecedented. Focus all Ascendancy weapons on its core!")
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "Destroy the Eclipse World-Eater!"
    
    local EclipseGenerator = include("eclipsegenerator")
    local faction = EclipseGenerator.getFaction()
    
    -- Spawn World Eater
    local dir = normalize(vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1)))
    local pos = dir * 2500
    -- Assuming createWorldEater exists or we use Juggernaut
    local boss = nil
    if EclipseGenerator.createWorldEater then
        boss = EclipseGenerator.createWorldEater(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
    else
        boss = EclipseGenerator.createJuggernaut(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
    end
    
    boss.title = "Eclipse World-Eater"
    boss:setValue("ca_eclipse_worldeater", true)
    
    -- Add heavy escorts
    for i = 1, 8 do
        local escortPos = MatrixLookUpPosition(-dir, vec3(0,1,0), pos + vec3(random():getFloat(-600, 600), random():getFloat(-600, 600), random():getFloat(-600, 600)))
        local escort = EclipseGenerator.createInterceptor(escortPos)
        escort:setValue("ca_eclipse_ambush", true)
    end
    
    Player():sendChatMessage("The Eclipse", 2, "Absolute zero. Absolute silence. Absolute order.")
end

mission.phases[2].updateServer = function()
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_worldeater")}
    if #boss == 0 then
        Player():sendChatMessage("Aegis", 0, "The World-Eater is destroyed! Commander, you have proven yourself worthy. We must meet one final time.")
        Player():setValue("ca_campaign_completed", true)
        
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ") for your final briefing."
end

mission.phases[3].onSectorEntered = function(x, y)
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
        Player():setValue("ca_ready_for_debrief_5", true)
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
