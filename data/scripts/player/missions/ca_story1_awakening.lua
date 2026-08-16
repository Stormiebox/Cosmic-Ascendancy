package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

function getUpdateInterval()
    return 1.0
end


mission._Name = "The Eclipse Awakening"
mission._Debug = 0

mission.data.description = "The Wormhole Guardian was not a final boss. It was the keystone of the Ascendants' ancient dimensional prison. Now that the knot is unraveled, investigate the anomalous dark energy readings the Hermit provided."
mission.data.title = "The Eclipse Awakening"

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local x, y = Sector():getCoordinates()
    local targetX, targetY = getTargetSector(x, y)
    mission.data.custom.targetX = targetX
    mission.data.custom.targetY = targetY
    mission.data.description = "Jump to the coordinates the Hermit provided: (" .. targetX .. ":" .. targetY .. ")\n\nThe Hermit's last transmission was filled with static. 'The lock is broken. The algorithm... The Eclipse... they are returning to sanitize the galaxy. You must see it for yourself.'"
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

    local plan = LoadPlanFromFile("data/plans/Ascendant/ascendancy_anomaly.xml")
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
        Player():sendChatMessage("Ship Computer", 0, "Scanning monolithic structure... Architecture is older than the Xsotan. It's functioning as a subspace beacon... Wait. It's activating!")
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

    Player():sendChatMessage("Unknown Transmission", 2, "Chaotic biological variables detected. Sanitation protocol initiated. We are The Eclipse.")

    for i = 1, 3 do
        local ship = generator.createMilitaryShip(faction, Matrix(), Sector():getCoordinates())
        ship.title = "Eclipse Vanguard Scout"
        ship:setValue("ca_eclipse_ambush", true)
    end
end

mission.phases[3].updateServer = function(timeStep)
    local x, y = Sector():getCoordinates()
    if x ~= mission.data.custom.targetX or y ~= mission.data.custom.targetY then return end

    local enemies = {Sector():getEntitiesByScriptValue("ca_eclipse_ambush")}
    if #enemies == 0 then
        Player():sendChatMessage("Ship Computer", 0, "Hostiles eliminated. Their shielding tech is unbelievable. We need to find a way to upgrade our weapons if we are to survive this.")
        Player():addScriptOnce("data/scripts/player/missions/ca_story2_forge.lua")
        finish()
    end
end

function getTargetSector(x, y)
    local random = Random()
    return x + random:getInt(-5, 5), y + random:getInt(-5, 5)
end