package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")

local LoreAnomalies = {}

function LoreAnomalies.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function LoreAnomalies.onSectorEntered(playerIndex, x, y, sectorChangeType)
    if sectorChangeType ~= SectorChangeType.Jump then return end

    local player = Player(playerIndex)
    if not player then return end

    -- Only spawn anomalies if the Eclipse hasn't fully awakened yet
    if Server():getValue("eclipse_fully_awake") then return end

    local dist = math.sqrt(x*x + y*y)
    
    -- The closer to the core, the higher the chance of finding a lore anomaly
    local spawnChance = 0.0
    if dist > 350 then
        spawnChance = 0.05 -- Very rare in outer rim
    elseif dist > 200 then
        spawnChance = 0.15 -- Common in mid-game
    elseif dist > 150 then
        spawnChance = 0.30 -- Frequent just outside the barrier
    end

    if random():getFloat() < spawnChance then
        LoreAnomalies.spawnAnomaly(x, y)
    end
end

function LoreAnomalies.spawnAnomaly(x, y)
    local sector = Sector()
    
    -- Only spawn in empty or unexplored sectors to avoid cluttering populated ones
    if sector:getEntitiesByComponent(ComponentType.Station) then return end

    local generator = SectorGenerator(x, y)
    local pos = generator:getPositionInSector(5000)

    -- Pick a random lore snippet
    local snippets = {
        "You detect a derelict massive hull. It has been sliced perfectly in half. The energy signature is completely alien to this galaxy. The black-box reads only: 'The Filter approaches.'",
        "An ancient, corrupted sensor buoy floats here. Translating the static yields a fragmented message: 'They blot out the stars... The Eclipse... Do not open the barrier.'",
        "A shattered asteroid field. The rocks are laced with an unknown black metallic substance. Sensor scans indicate the material was used to absorb and nullify incoming fire.",
        "You find the remnants of an entire civilization's evacuation fleet. Every ship is powered down and dead. There are no signs of battle, only a lingering suppression field.",
        "A massive, jet-black monolithic structure drifts silently in the void. As your ship approaches, your sensors go temporarily blind before the monolith suddenly folds space and vanishes."
    }

    local loreText = snippets[random():getInt(1, #snippets)]

    -- Spawn a generic wreckage (Corrupted Databank / Lost Ship)
    local plan = generator:getBasicWreckagePlan()
    local wreck = sector:createWreckage(plan, pos)
    
    -- Spawn a stash container with loot scaled by distance to core
    local stashPos = pos + vec3(random():getFloat(50, 100), random():getFloat(50, 100), random():getFloat(50, 100))
    local stash = sector:createContainer(MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), stashPos), faction, "")
    stash.title = "Corrupted Databank Stash"%_t
    
    local dist = math.sqrt(x*x + y*y)
    
    -- Scale loot material by distance
    local distMat = 1 -- Iron
    if dist < 150 then distMat = 6 -- Avorion
    elseif dist < 200 then distMat = 5 -- Ogonite
    elseif dist < 250 then distMat = 4 -- Xanion
    elseif dist < 300 then distMat = 3 -- Trinium
    elseif dist < 400 then distMat = 2 -- Naonite
    end
    
    -- Add resources to stash
    local amount = random():getInt(10000, 50000)
    stash:addDrop(Material(distMat), amount)
    
    -- Drop random system upgrades
    local numUpgrades = random():getInt(1, 3)
    for i = 1, numUpgrades do
        stash:addDrop(SystemUpgradeTemplate("data/scripts/systems/randomupgrade.lua", Rarity(random():getInt(1, 3)), Seed(1)))
    end

    -- Send the lore directly to the player's chat
    Player():sendChatMessage("Ship Sensors", 3, loreText)
end

return LoreAnomalies
