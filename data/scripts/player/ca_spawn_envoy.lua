package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("sectorgenerator")
local ShipUtility = include ("shiputility")

function initialize()
    if onServer() then
        -- Wait 10 seconds before spawning the Envoy
        deferredCallback(10.0, "spawnAegis")
    end
end

function spawnAegis()
    if not onServer() then return end

    local sector = Sector()
    if not sector then return end

    local player = Player()
    if player then
        player:setValue("ca_ready_for_debrief_intro", true)
    end

    -- Check if Aegis was already spawned by another player to prevent duplicates in multiplayer
    if sector:getValue("ca_aegis_spawned") then
        terminate()
        return
    end
    sector:setValue("ca_aegis_spawned", true)

    -- Generate Aegis, The Ascendant Envoy
    local generator = SectorGenerator(sector:getCoordinates())

    local faction = Galaxy():getNearestFaction(0, 0) -- Or a specific neutral lore faction if preferred. Usually Adventurer uses a neutral faction.

    local name = "Aegis, The Ascendant Envoy"%_T

    local ship = generator:createShip(faction, "data/scripts/entity/story/ca_ascendant_envoy.lua")
    ship.name = name
    ship.title = "Ascendant AI Construct"%_T

    -- Make Aegis invincible and non-collidable like a ghost/hologram
    ship:setInvincible(true)
    ship.dockable = false
    ship.crew = ship.minCrew -- prevent crew shortage

    -- Assign the Aegis .xml plan
    local plan = LoadPlanFromFile("data/plans/ascendant/ca_aegis.xml")
    if plan then
        ship:setPlan(plan)
    end

    ShipUtility.addTurretsToCraft(ship, nil, 0, 0) -- No weapons
    ship:addScriptOnce("entity/ca_envoy_despawn.lua")

    local player = Player()
    if player then
        player:sendChatMessage(ship.name, 0, "Commander. Do not be alarmed. I am Aegis. We must speak immediately."%_T)
    end

    -- Remove this spawner script from the player
    terminate()
end
