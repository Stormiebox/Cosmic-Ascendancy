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
        "You detect a derelict massive hull, sliced perfectly in half. Its databanks contain a single, repeating conceptual warning: 'The Algorithm approaches. True sanitation.'",
        "An ancient, corrupted sensor buoy floats here. The fragmented message reads: 'They blot out the stars... The Eclipse... Do not untie the dimensional knot.'",
        "A shattered asteroid field laced with an unknown black material. Scans indicate this 'Avorion' is merely an inert echo of the Ascendants' immense power.",
        "You find the remnants of an entire civilization. Every ship is powered down and dead. There are no signs of battle, only the aftermath of a perfect, sterile order.",
        "A massive, jet-black monolithic structure drifts silently. As you approach, sensors detect a terrifying algorithmic intelligence calculating your elimination."
    }

    local loreText = snippets[random():getInt(1, #snippets)]

    -- Spawn a generic wreckage (Corrupted Databank / Lost Ship)
    local plan = generator:getBasicWreckagePlan()
    local wreck = generator:createWreckage(nil, plan, 10)
    if wreck then wreck.translationf = pos end

    -- Spawn a stash container with loot scaled by distance to core
    local stashPos = pos + vec3(random():getFloat(50, 100), random():getFloat(50, 100), random():getFloat(50, 100))
    local stash = sector:createContainer(MatrixLookUpPosition(vec3(0,1,0), vec3(1,0,0), stashPos), nil, "")
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

    -- Synergy: Report Lore Anomaly to Cosmic Vault News
    local cvn = include("cosmicvaultnews")
    if cvn then
        local article = {
            title = "Deep Space Discovery",
            category = "Lore Anomaly",
            content = "An independent explorer has uncovered a disturbing ancient databank in sector (" .. x .. ":" .. y .. "). The decrypted fragments read: '" .. loreText .. "'"
        }
        cvn.publishArticle(article)
    end
end

function initialize(...)
    if LoreAnomalies.initialize then return LoreAnomalies.initialize(...) end
end
function onSectorEntered(...)
    if LoreAnomalies.onSectorEntered then return LoreAnomalies.onSectorEntered(...) end
end
