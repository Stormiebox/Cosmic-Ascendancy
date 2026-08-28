package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Eclipse Awakening"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"
mission._Debug = 0

mission.data.description = "Aegis, an Ascendant AI, revealed that the Wormhole Guardian was a keystone holding back the algorithmic plague known as The Eclipse. Now that the seal is broken, you must investigate the first detected subspace anomaly."
mission.data.title = "The Eclipse Awakening"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Jump to the anomaly coordinates Aegis provided: (" .. targetX .. ":" .. targetY .. ")\n\nAegis warned that The Eclipse does not conquer—it sanitizes. Be prepared for anything."
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        Player():sendChatMessage("Ship Sensors", 3, "WARNING: Massive subspace rupture detected. Energy signatures match nothing in our database. It's... purely dark energy.")
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description = "Investigate the anomaly at (" .. mission.data.custom.targetX .. ":" .. mission.data.custom.targetY .. ")."

    local sector = Sector()
    -- Spawn a monolith to investigate
    local generator = include("SectorGenerator")(Sector():getCoordinates())
    local pos = generator:getPositionInSector(5000)

    local plan = LoadPlanFromFile("data/plans/ascendant/ascendancy_anomaly.xml")
    if not plan then
        plan = generator:getBasicWreckagePlan()
    end

    local wreck = generator:createWreckage(nil, plan, 10, pos)
    if wreck then mission.data.custom.wreckId = wreck.index.string end
end

mission.phases[2].updateServer = function(timeStep)
    local player = Player()
    local craft = player.craft
    if not craft then return end

    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end

    local wreck = Sector():getEntity(Uuid(mission.data.custom.wreckId))
    if not wreck then
        -- Player destroyed it or it despawned
        nextPhase()
        return
    end

    if distance(craft.translationf, wreck.translationf) < 500 then
        Player():sendChatMessage("Aegis", 0, "The anomaly is a subspace beacon. It's activating... Commander, prepare yourself. A Vanguard fleet has locked onto your position.")
        wreck:addScriptOnce("entity/delete.lua") -- Delete the wreck
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description = "An Eclipse Vanguard ambush! Survive the attack."
    -- Spawn Eclipse enemies
    local generator = include("shipgenerator")
    local EclipseGenerator = include("eclipsegenerator")
    local faction = EclipseGenerator.getFaction()

    local existing = {Sector():getEntitiesByScriptValue("ca_eclipse_ambush")}
    if #existing == 0 then
        Player():sendChatMessage("Unknown Transmission", 2, "Chaotic biological variables detected. Sanitation protocol initiated. We are The Eclipse.")

        for i = 1, 3 do
            local ship = EclipseGenerator.createInterceptor(Matrix())
            ship.title = "Eclipse Vanguard Scout"
            ship:setValue("ca_eclipse_ambush", true)
        end
    end
    mission.data.custom.bossSpawned = true
end

mission.phases[3].updateServer = function(timeStep)
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end
    if not mission.data.custom.bossSpawned then return end

    local enemies = {Sector():getEntitiesByScriptValue("ca_eclipse_ambush")}
    if #enemies == 0 then
        Player():sendChatMessage("Aegis", 0, "Hostiles eliminated. More will come. We must meet. I am transmitting secure rendezvous coordinates.")
        local rx, ry = getTargetSector(x, y)
        mission.data.custom.aegisX = rx
        mission.data.custom.aegisY = ry
        nextPhase()
    end
end

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBeginServer = function()
    mission.data.description = "Rendezvous with Aegis at (" .. mission.data.custom.aegisX .. ":" .. mission.data.custom.aegisY .. ")."
end

mission.phases[4].onSectorEntered = function(x, y)
    if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
        local aegisExists = false
        local entities = {Sector():getEntitiesByScript("entity/story/ca_ascendant_envoy.lua")}
        if #entities > 0 then
            aegisExists = true
        end
        if not aegisExists then
            local faction = Galaxy():getNearestFaction(0, 0)
            local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
            if not plan then
                plan = BlockPlan()
                plan:addBlock(vec3(0,0,0), vec3(2,2,2), BlockDefaults.GetHullBlockIndex(), -1, ColorRGB(1,1,1), Material(0), Matrix(), BlockType.Hull)
            end
            
            local ship = Sector():createShip(faction, "", plan, Matrix())
            if ship then
                ship.name = "Aegis, The Ascendant Envoy"%_T
                ship.title = "Ascendant AI Construct"%_T
                ship:setInvincible(true)
                ship.dockable = false
                ship.crew = ship.minCrew
                
                local ShipUtility = include("shiputility")
                ShipUtility.addTurretsToCraft(ship, nil, 0, 0)
                ship:addScriptOnce("entity/ca_envoy_despawn.lua")
                ship:addScriptOnce("entity/story/ca_ascendant_envoy.lua")
                
                Player():sendChatMessage(ship.name, 0, "Commander. Approach my projection and initiate contact."%_T)
            end
        end
        Player():setValue("ca_ready_for_debrief_1", true)
    end
end

mission.phases[4].updateServer = function()
    local player = Player()
    if mission.data.custom.aegisX and mission.data.custom.aegisY then
        local x, y = player:getSectorCoordinates()
        if x == mission.data.custom.aegisX and y == mission.data.custom.aegisY then
            if player:getValue("ca_ready_for_debrief_1") == nil then
                finish()
            end
        end
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