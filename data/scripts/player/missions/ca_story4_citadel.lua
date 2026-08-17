package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Citadel Threat"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "Aegis has detected a massive localized space-time distortion. The Eclipse are attempting to anchor a Citadel in a nearby sector to begin mass sterilization."
mission.data.title = "The Citadel Threat"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Jump to (" .. targetX .. ":" .. targetY .. ") and destroy the Eclipse Citadel before it can fully anchor itself to this dimension."
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Aegis", 0, "The Citadel is here. Target its structural nodes. Do not let it complete its dimensional lock!")
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "Destroy the Eclipse Citadel!"
    
    local EclipseGenerator = include("eclipsegenerator")
    local faction = EclipseGenerator.getFaction()
    
    local existingBoss = {Sector():getEntitiesByScriptValue("ca_eclipse_citadel")}
    if #existingBoss == 0 then
        -- Spawn Citadel Boss
        local dir = normalize(vec3(random():getFloat(-1, 1), random():getFloat(-1, 1), random():getFloat(-1, 1)))
        local pos = dir * 2000
        -- Spawn Citadel Boss using the proper station generator and xml plan
        local boss = EclipseGenerator.createStation(MatrixLookUpPosition(-dir, vec3(0,1,0), pos))
        
        boss.title = "Eclipse Citadel Prototype"
        boss:setValue("ca_eclipse_citadel", true)
        
        -- Add Interceptors as escorts
        for i = 1, 6 do
            local escortPos = MatrixLookUpPosition(-dir, vec3(0,1,0), pos + vec3(random():getFloat(-400, 400), random():getFloat(-400, 400), random():getFloat(-400, 400)))
            local escort = EclipseGenerator.createInterceptor(escortPos)
            escort:setValue("ca_eclipse_ambush", true)
        end
        
        Player():sendChatMessage("The Eclipse", 2, "Sanitation node establishing. Resistance is a chaotic anomaly that will be rectified.")
    end
    mission.data.custom.bossSpawned = true
end

mission.phases[2].updateServer = function()
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then return end
    
    local boss = {Sector():getEntitiesByScriptValue("ca_eclipse_citadel")}
    if #boss == 0 then
        Player():sendChatMessage("Aegis", 0, "The Citadel has collapsed! Incredible work, Commander. But the dimensional shockwave... oh no. Something much larger is riding the wake. We must meet at these coordinates immediately.")
        
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ")."
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
        Player():setValue("ca_ready_for_debrief_4", true)
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
