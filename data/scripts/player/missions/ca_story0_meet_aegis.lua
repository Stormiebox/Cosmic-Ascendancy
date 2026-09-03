package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("structuredmission")

mission._Debug = 0
mission._Name = "A Mysterious Summons"

abandon = nil -- this mission is not abandonable
mission.data.brief = mission._Name
mission.data.icon = "data/textures/icons/story-mission.png"

mission.data.autoTrackMission = true
mission.data.title = "A Mysterious Summons"
mission.data.description = "You have received an encrypted transmission from an entity claiming to be 'Aegis'. The destruction of the Wormhole Guardian has seemingly triggered a response. You should investigate the coordinates provided."

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local player = Player()
    local x, y = player:getSectorCoordinates()
    
    -- Target a random nearby empty sector (5 to 30 jumps away)
    local MissionUT = include("missionutility")
    local insideBarrier = false
    if x and y then
        insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    else
        x, y = 0, 0
        insideBarrier = true
    end
    
    local targetX, targetY = MissionUT.getEmptySector(x, y, 5, 30, insideBarrier)
    
    -- Fallback in case the search fails to find one
    if not targetX or not targetY then 
        local random = Random()
        targetX = x + random:getInt(-30, 30)
        targetY = y + random:getInt(-30, 30)
    end
    
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    
    mission.data.description = "Rendezvous with the entity 'Aegis' at sector (" .. targetX .. ":" .. targetY .. ")."
    
    -- Send Mail
    local mail = Mail()
    mail.text = Format("Commander. Do not be alarmed by my intrusion into your systems. I am Aegis.\n\nBy destroying the Keystone, you have unraveled the dimensional knot. We must speak immediately. I have transmitted secure rendezvous coordinates to your ship's computer.\n\nDo not delay."%_T)
    mail.header = Format("Secure Transmission"%_T)
    mail.sender = Format("Aegis"%_T)
    player:addMail(mail)
    
    player:sendChatMessage("Ship Computer"%_T, 3, "New rendezvous coordinates received: \\s(%1%:%2%)"%_T, tostring(targetX), tostring(targetY))
end

function getUpdateInterval()
    return 1.0
end

mission.phases[1].onSectorEntered = function(x, y)
    if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
        local player = Player()
        local sector = Sector()
        
        local aegisExists = false
        local entities = {sector:getEntitiesByScript("entity/story/ca_ascendant_envoy.lua")}
        if #entities > 0 then
            aegisExists = true
        end
        
        if not aegisExists then
            -- Spawn Aegis
            local faction = Galaxy():getNearestFaction(0, 0)
            local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
            -- valid(), not a plain nil check: vanilla's own factionpacks.lua checks
            -- LoadPlanFromFile's result via `if not valid(plan) then`, evidence a failed load may
            -- return a non-nil-but-invalid object (see eclipsegenerator.lua's createShip for the
            -- full writeup). Dormant today since ca_aegis.xml exists on disk, but a plain nil check
            -- would silently skip this fallback if that ever changes.
            if not valid(plan) then
                plan = BlockPlan()
                plan:addBlock(vec3(0,0,0), vec3(2,2,2), BlockDefaults.GetHullBlockIndex(), -1, ColorRGB(1,1,1), Material(0), Matrix(), BlockType.Hull)
            end
            
            local ship = sector:createShip(faction, "", plan, Matrix())
            
            if ship then
                ship.name = "Aegis, The Ascendant Envoy"%_T
                ship.title = "Ascendant AI Construct"%_T
                ship.invincible = true
                ship.dockable = false
                ship.crew = ship.minCrew
                
                local ShipUtility = include("shiputility")
                ShipUtility.addTurretsToCraft(ship, nil, 0, 0)
                ship:addScriptOnce("entity/ca_envoy_despawn.lua")
                ship:addScriptOnce("entity/story/ca_ascendant_envoy.lua")
                aegisExists = true -- mark success so the debrief flag below reflects reality
            end
        end

        player:sendChatMessage("Aegis, The Ascendant Envoy"%_T, 0, "Commander. Approach my projection and initiate contact."%_T)

        -- Play OST just for this player
        player:addScriptOnce("data/scripts/player/ca_boss_audio_hook.lua")
        player:invokeFunction("data/scripts/player/ca_boss_audio_hook.lua", "triggerGuardianFellMusic")

        -- Only mark the player "ready for debrief" once an Aegis ship is actually confirmed to exist
        -- in the sector (either it was already there, or we just created one) -- otherwise, if
        -- createShip() ever returned nil (e.g. Galaxy():getNearestFaction(0, 0) returning nil, per its
        -- own doc comment, for a hypothetical unclaimed core sector), the player would be told to
        -- approach a projection that doesn't exist with no way to recover. Leaving the flag unset
        -- means the next onSectorEntered (re-entering this sector) retries the spawn, since
        -- aegisExists correctly still reads false.
        if aegisExists then
            player:setValue("ca_ready_for_debrief_intro", true)
            mission.data.custom.debriefReady = true
        end

        mission.data.description = "You have found Aegis. Approach the Ascendant AI Construct and initiate contact."
    end
end

mission.phases[1].updateServer = function()
    local player = Player()
    if mission.data.custom.targetX and mission.data.custom.targetY then
        local x, y = player:getSectorCoordinates()
        if x == mission.data.custom.targetX and y == mission.data.custom.targetY then
            -- If Aegis removed the flag, it means the player talked to her and got mission 1.
            -- Gated on debriefReady (only set once Aegis was actually confirmed present) so a
            -- pending/failed spawn retry -- where the flag is nil because it was never set, not
            -- because the player talked to her -- doesn't get misread as a completed debrief and
            -- silently finish() the mission before the player ever got to interact with Aegis.
            if mission.data.custom.debriefReady and player:getValue("ca_ready_for_debrief_intro") == nil then
                finish()
            end
        end
    end
end
