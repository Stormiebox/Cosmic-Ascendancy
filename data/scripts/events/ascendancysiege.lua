package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local PirateGenerator = include("pirategenerator")
local Xsotan = include("story/xsotan")
local ShipGenerator = include("shipgenerator")
local Placer = include("placer")

local cv_news = include("cosmicvaultnews")
local cw_bridge = include("cosmicwarbridge")
local cv_fleet = include("cosmicvaultfleet")

-- namespace AscendancySiege
AscendancySiege = {}

local tier = 1
local targetFactionIndex = 0
local attackers = {}
local attackerFaction = 0
local typeName = "Pirates"
local active = false
local EncounterBridge = include("ca_encounter_bridge")
local OWNER = "data/scripts/events/ascendancysiege.lua"
local encounterId
local attackersDestroyedVerified = false
local spawnAttempts = 0
local nextSpawnAttempt

local function attemptMaterialization()
    if not encounterId then return end
    local encounter = EncounterBridge.Get(encounterId)
    if encounter and encounter.state == "retryable" then
        if not EncounterBridge.Transition(OWNER, encounterId, "prepared") then return end
    end
    if not EncounterBridge.Transition(OWNER, encounterId, "materializing", {
            attempts = spawnAttempts}) then return end
    spawnAttempts = spawnAttempts + 1
    local spawnedShips = AscendancySiege.spawnFleet()
    local expected = 3 + (tier * 2) + math.max(0, tier - 2)
    if #spawnedShips == 0 then
        if spawnAttempts < 5 then
            nextSpawnAttempt = Server().unpausedRuntime + (spawnAttempts * 10)
            EncounterBridge.Transition(OWNER, encounterId, "retryable", {
                attempts = spawnAttempts, nextAttemptAt = nextSpawnAttempt,
                lastError = "beacon_siege_spawn_failed"
            })
        else
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                attempts = spawnAttempts,
                lastError = "beacon_siege_spawn_failed_after_five_attempts"
            })
        end
        return
    end
    local ids = {}
    for _, ship in ipairs(spawnedShips) do
        ship:setValue("ca_encounter_id", encounterId)
        table.insert(ids, ship.id.string)
    end
    if #spawnedShips ~= expected then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            entityIds = ids, attempts = spawnAttempts,
            lastError = "beacon_siege_partial_spawn"
        })
        return
    end
    for _, ship in ipairs(spawnedShips) do
        ship:registerCallback("onDestroyed", "onAttackerDestroyed")
    end
    local activated = EncounterBridge.Transition(OWNER, encounterId, "active", {
        entityIds = ids, attempts = spawnAttempts, engagedAt = Server().unpausedRuntime
    })
    if not activated then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            entityIds = ids, attempts = spawnAttempts,
            lastError = "beacon_siege_registration_failed"
        })
        return
    end
    nextSpawnAttempt = nil
    active = true
    AscendancySiege.broadcastWarning()
end

function AscendancySiege.initialize(t, ownerIndex)
    if not onServer() then return end
    -- Defensive-in-depth: addScriptOnce is idempotent while the sector stays loaded and this
    -- script's own secure()/restore() correctly re-applies state on a reload, so this shouldn't be
    -- reachable in practice -- but nothing else in this call chain guards against a second
    -- initialize() firing while a siege is still active, unlike updateServer() right below, which
    -- already defends itself with "if not active then return end".
    if active then return end
    tier = t or 1
    targetFactionIndex = ownerIndex or 0
    local x, y = Sector():getCoordinates()
    encounterId = EncounterBridge.MakeId("beacon_siege", "sector", x, y,
        math.floor(Server().unpausedRuntime))
    local prepared = EncounterBridge.Create(OWNER, {
        encounterId = encounterId, kind = "beacon_siege",
        concurrencyKey = "beacon_siege:" .. x .. ":" .. y,
        scope = "sector", x = x, y = y, state = "prepared"
    })
    if not prepared then return end

    -- Choose attacker type
    local r = random():getFloat()
    if cw_bridge.getFactionWarHeat then
        local factions = {Sector():getPresentFactions()}
        local warFaction = nil
        for _, fIndex in pairs(factions) do
            local f = Faction(fIndex)
            if f and f.isAIFaction and f:getRelations(targetFactionIndex) < -40000 then
                warFaction = f
                break
            end
        end
        if warFaction and r < 0.4 then
            attackerFaction = warFaction.index
            typeName = warFaction.name
        elseif r < 0.7 then
            typeName = "Xsotan"
        else
            typeName = "Pirates"
        end
    else
        if r < 0.5 then typeName = "Xsotan" else typeName = "Pirates" end
    end

    attemptMaterialization()
end

function AscendancySiege.spawnFleet()
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    local numShips = 3 + (tier * 2)
    local numBosses = math.max(0, tier - 2)

    local faction
    if typeName == "Xsotan" then
        faction = Xsotan.getFaction()
    elseif typeName == "Pirates" then
        faction = PirateGenerator.getFaction()
    else
        faction = Faction(attackerFaction)
    end

    -- Collect the ship objects actually spawned this call, so resolveIntersections() below only
    -- untangles overlap among THIS fleet -- calling it with no argument at all (as this file
    -- previously did) makes it default to every BoundingSphere entity in the sector, which is both
    -- a needless sector-wide TPS hit and can shove around unrelated entities (the player's own
    -- ship, the Beacon capital itself) that happen to be near the fleet's spawn point.
    local spawnedShips = {}

    -- Spawn Bosses (Battleships/Dreadnoughts) — tier 3+ only
    for i = 1, numBosses do
        local shipPos = MatrixLookUpPosition(-dir, up, pos + right * getFloat(-500, 500) + up * getFloat(-500, 500))
        local ship
        if typeName == "Xsotan" then
            ship = Xsotan.createGuardian(shipPos)
        elseif typeName == "Pirates" then
            ship = PirateGenerator.createBoss(shipPos)
        else
            local volume = ShipGenerator.getMilitaryShipVolume(faction, 10) * (1 + (tier * 0.5))
            ship = ShipGenerator.createMilitaryShip(faction, shipPos, volume)
        end
        -- or if an internal error occurs. Always nil-check before accessing any property.
        if ship then
            ship:addScriptOnce("ai/patrol.lua")
            ship:setValue("is_ascendancy_siege", true)
            table.insert(attackers, ship.id.string)
            table.insert(spawnedShips, ship)
            if cv_fleet.orderAttackEnemies then
                cv_fleet.orderAttackEnemies(ship.index, true)
            end
        end
    end

    -- Spawn Standard Fleet
    for i = 1, numShips do
        local shipPos = MatrixLookUpPosition(-dir, up, pos + right * getFloat(-500, 500) + up * getFloat(-500, 500))
        local ship
        if typeName == "Xsotan" then
            ship = Xsotan.createShip(shipPos)
        elseif typeName == "Pirates" then
            ship = PirateGenerator.createPirate(shipPos)
        else
            local volume = ShipGenerator.getMilitaryShipVolume(faction, 5) * (1 + (tier * 0.2))
            ship = ShipGenerator.createMilitaryShip(faction, shipPos, volume)
        end
        if ship then
            ship:addScriptOnce("ai/patrol.lua")
            ship:setValue("is_ascendancy_siege", true)
            table.insert(attackers, ship.id.string)
            table.insert(spawnedShips, ship)
            if cv_fleet.orderAttackEnemies then
                cv_fleet.orderAttackEnemies(ship.index, true)
            end
        end
    end

    Placer.resolveIntersections(spawnedShips)
    return spawnedShips
end

function AscendancySiege.onAttackerDestroyed()
    for _, id in ipairs(attackers) do
        if valid(Entity(Uuid(id))) then return end
    end
    attackersDestroyedVerified = true
end

function AscendancySiege.broadcastWarning()
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 1, "WARNING! Massive %1% siege fleet detected entering the sector!"%_t, typeName)

    if cv_news.publishArticle then
        local owner = Faction(targetFactionIndex)
        local ownerName = owner and owner.name or "Unknown"
        cv_news.publishArticle({
            title = "Capital Siege: " .. typeName .. " Invade " .. ownerName .. " Empire",
            content = "A gargantuan fleet belonging to the " .. typeName .. " has initiated a massive siege against the Ascendant Capital in sector [" .. x .. ":" .. y .. "]. Defense fleets are scrambling.",
            category = "Galactic War"
        })
    end
end

function AscendancySiege.getUpdateInterval()
    return 5
end

function AscendancySiege.updateServer(timeStep)
    if not active then
        if nextSpawnAttempt and Server().unpausedRuntime >= nextSpawnAttempt then
            attemptMaterialization()
        end
        return
    end

    -- Check if beacon is still alive
    local beaconAlive = false
    local entities = {Sector():getEntitiesByScript("data/scripts/entity/ascendancybeacon.lua")}
    for _, entity in pairs(entities) do
        if entity.factionIndex == targetFactionIndex then
            beaconAlive = true
            break
        end
    end

    if not beaconAlive then
        -- Beacon was destroyed!
        AscendancySiege.onDefeat()
        return
    end

    -- Check attackers
    local attackersAlive = false
    local newAttackers = {}
    for _, id in pairs(attackers) do
        local ship = Entity(Uuid(id))
        if valid(ship) then
            table.insert(newAttackers, id)
            attackersAlive = true
        end
    end
    attackers = newAttackers

    if not attackersAlive then
        if attackersDestroyedVerified then
            AscendancySiege.onVictory()
        else
            active = false
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "siege_attackers_missing_without_destroy_callback"
            })
        end
    end
end

function AscendancySiege.onVictory()
    active = false
    local resolving = EncounterBridge.Transition(OWNER, encounterId, "resolving", {
        resolution = {reason = "attackers_destroyed"}
    })
    if not resolving then return end
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 3, "Siege Defeated! The Ascendant Capital stands strong."%_t)
    local owner = Faction(targetFactionIndex)
    local operationId
    if owner then
        operationId = encounterId .. ":faction:" .. targetFactionIndex .. ":reward"
        local receipt = EncounterBridge.PrepareReceipt(OWNER, {
            operationId = operationId, kind = "beacon_siege_reward",
            encounterId = encounterId, recipient = {factionIndex = targetFactionIndex},
            reissue = {mode = "coordinator_credit", credits = tier * 2500000,
                reason = "Capital Siege Defense Reward"}
        })
        if not receipt then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_receipt_prepare_failed:" .. operationId})
            return
        end
    end

    -- Spawn massive loot explosion at sector center
    -- generateSectorSystem(x, y, rarity) is used deliberately over generateSystem(rarity) so the
    -- material tier of dropped upgrades scales with this sector's location, like the turret loot below.
    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local turretGen = SectorTurretGenerator(Sector().seed)          -- Use correct object constructor
    local upgradeGen = UpgradeGenerator()
    local lootRarity = Rarity(math.min(5, tier + 1)) -- Cap at Exotic (5) rarity
    local lootPos = vec3(0, 0, 0)                    -- Drop at sector center
    for i = 1, 5 + tier * 2 do
        Sector():dropTurret(lootPos, nil, nil, turretGen:generateArmed(x, y, 0, lootRarity))
        Sector():dropUpgrade(lootPos, nil, nil, upgradeGen:generateSectorSystem(x, y, lootRarity))
    end

    if owner then
        -- Reward the defending faction for surviving the siege
        local before = owner.money or 0
        owner:receive("Capital Siege Defense Reward"%_t, tier * 2500000)
        if (owner.money or 0) < before + tier * 2500000 then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_delivery_unverified:" .. operationId})
            return
        end
        if not EncounterBridge.CompleteReceipt(OWNER, operationId, {
                credits = tier * 2500000, before = before, after = owner.money}) then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "reward_receipt_completion_ambiguous:" .. operationId})
            return
        end
    end

    local succeeded = EncounterBridge.Transition(OWNER, encounterId, "succeeded", {
        resolution = {reason = "attackers_destroyed"}
    })
    if not succeeded then
        EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
            lastError = "siege_terminal_transition_failed"
        })
    end

    terminate()
end

function AscendancySiege.onDefeat()
    active = false
    EncounterBridge.Transition(OWNER, encounterId, "abandoned", {
        resolution = {reason = "beacon_destroyed"}
    })
    local x, y = Sector():getCoordinates()
    Sector():broadcastChatMessage("System"%_t, 1, "The Ascendant Capital has fallen..."%_t)

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Capital Falls to " .. typeName,
            content = "The Ascendancy Beacon in sector [" .. x .. ":" .. y .. "] has been completely destroyed. The surrounding empire's global power has collapsed.",
            category = "Galactic War"
        })
    end

    -- Jump the attackers away since they won
    for _, id in pairs(attackers) do
        local ship = Entity(Uuid(id))
        if valid(ship) then
            ship:addScriptOnce("data/scripts/entity/deletejumped.lua")
        end
    end

    terminate()
end


function AscendancySiege.secure()
    return {
        tier = tier,
        targetFactionIndex = targetFactionIndex,
        attackers = attackers,
        attackerFaction = attackerFaction,
        typeName = typeName,
        active = active,
        encounterId = encounterId,
        attackersDestroyedVerified = attackersDestroyedVerified,
        spawnAttempts = spawnAttempts,
        nextSpawnAttempt = nextSpawnAttempt
    }
end

function AscendancySiege.restore(data_in)
    data_in = data_in or {}
    tier = data_in.tier or 1
    targetFactionIndex = data_in.targetFactionIndex or 0
    attackers = data_in.attackers or {}
    attackerFaction = data_in.attackerFaction or 0
    typeName = data_in.typeName or "Pirates"
    active = data_in.active or false
    encounterId = data_in.encounterId
    attackersDestroyedVerified = data_in.attackersDestroyedVerified == true
    spawnAttempts = data_in.spawnAttempts or 0
    nextSpawnAttempt = data_in.nextSpawnAttempt
    if active and encounterId then
        for _, id in ipairs(attackers) do
            local ship = Entity(Uuid(id))
            if valid(ship) and ship:getValue("ca_encounter_id") == encounterId then
                ship:registerCallback("onDestroyed", "onAttackerDestroyed")
            end
        end
    elseif encounterId then
        local encounter = EncounterBridge.Get(encounterId)
        if encounter and encounter.state == "retryable" then
            nextSpawnAttempt = Server().unpausedRuntime + 5
        elseif encounter and encounter.state == "materializing" then
            EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                lastError = "restart_during_beacon_siege_materialization"
            })
            nextSpawnAttempt = nil
        end
    end
end


