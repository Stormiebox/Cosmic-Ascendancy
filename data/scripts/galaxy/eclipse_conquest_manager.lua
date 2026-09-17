package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- stringutility installs the %_T/%_t metamethod on the string metatable; it is also pulled in
-- transitively via cosmicvaultterritory.lua below, but declared directly here too (matching the
-- explicit-include convention used elsewhere in this mod, e.g. eclipse_awakes.lua) so this file's
-- %_T usage below doesn't silently depend on a Cosmic Vault internal staying unchanged.
include("stringutility")

local CosmicVaultTerritory = nil
local cv_goods = include("cosmicvaultgoods")
local CosmicAscendancyNews = include("ca_news")
local FactionEradicationUtility = include("factioneradicationutility")
CosmicVaultTerritory = include("cosmicvaultterritory")
local CosmicVaultData = include("cosmicvaultdata")
local OWNER = "data/scripts/galaxy/eclipse_conquest_manager.lua"
local COORDINATOR = "data/scripts/galaxy/ca_state_coordinator.lua"
local EncounterBridge = include("ca_encounter_bridge")

-- namespace EclipseConquestManager
EclipseConquestManager = {}

-- These coordinate lists only delimit entries with a trailing comma (e.g. "25_10,5_10,"), so a
-- plain substring search for "5_10," would false-positive inside "25_10,". Anchor both sides by
-- also requiring the leading comma so entries can't match as a substring of a longer coordinate.
local function canonicalState()
    return CosmicVaultData.GetRecord(Server(), "ca_state_v2", 2)
end

local function mutateState(action, payload)
    local state = canonicalState()
    if not state then return nil, "state_unavailable" end
    local resultCode, revision, err = Galaxy():invokeFunction(
        COORDINATOR, "requestTerritoryState", OWNER, state.revision, action, payload)
    if resultCode ~= 0 then return nil, "coordinator_unavailable" end
    return revision, err
end

-- Sanctuary Field: a Tier 3+ Ascendancy Beacon (see ascendancybeacon.lua's updateSanctuaryRegistry)
-- actively repels Eclipse conquest attempts within its radius. The registry lives on Server()
-- rather than the beacon entity itself, since the beacon's own sector may not be loaded when the
-- Eclipse tries to expand nearby.
local function isInsideSanctuaryField(tx, ty)
    local state = canonicalState()
    for _, claim in pairs(state and state.beacons.claims or {}) do
        if claim.state == "active" and (claim.tier or 0) >= 3 then
            local radius = claim.sanctuaryRadius
                or ({[3] = 5, [4] = 8, [5] = 12})[claim.tier] or 0
            local dx, dy = tx - claim.x, ty - claim.y
            if math.sqrt(dx * dx + dy * dy) <= radius then
                return true
            end
        end
    end
    return false
end

-- Recorded so /eclipsestatus (eclipsestatus.lua) can show the Eclipse's last known Crusade target.
-- This is a Fallen Empire-only event (a single-shot pick-and-act, not an ongoing pursuit with its
-- own persistent state), so this simply timestamps the most recent one rather than tracking a
-- currently-in-progress target.
local function recordCrusadeTarget(tx, ty, targetKind)
    mutateState("record_crusade", {x = tx, y = ty, kind = targetKind})
end

function EclipseConquestManager.getUpdateInterval()
    return 60.0
end

function EclipseConquestManager.initialize()
    if cv_goods.registerGood then
        cv_goods.registerGood({
            name = "Ascendant Matter",
            description = "A hyper-dense dark energy composite synthesized by Eclipse Harvesters.",
            price = 250000,
            size = 2.5,
            icon = "data/textures/icons/AscendantMatter.png",
            illegal = true,
            dangerous = true,
            tags = {ascendant = true}
        })
        cv_goods.registerGood({
            name = "Eclipse Datacore",
            description = "An encrypted quantum datacore extracted from a high-ranking Eclipse vessel.",
            price = 1000000,
            size = 5.0,
            icon = "data/textures/icons/EclipseDatacore.png",
            illegal = true,
            tags = {ascendant = true}
        })
        cv_goods.registerGood({
            name = "Ascendant Scrap",
            description = "Failed remnants of an Ascendant forging process. Highly sought after by underground tech brokers.",
            price = 100000,
            size = 1.0,
            icon = "data/textures/icons/AscendantScrap.png",
            illegal = true,
            tags = {ascendant = true}
        })
    end
end
function EclipseConquestManager.updateServer(timeStep)
    local state = canonicalState()
    if not state or state.eclipse.state ~= "fully_awake" then return end

    -- Pause expansion if no players are online (protects 24/7 dedicated servers from offline wipes)
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local conqueredCount = state.territory.conqueredCount or 0
    local threat = state.territory.threat or 0
    
    -- Threat generation: Base 300 per minute + (20 per held sector per minute)
    local threatPerSecond = (300 + (conqueredCount * 20)) / 60.0
    local generated = threatPerSecond * timeStep
    mutateState("add_threat", {amount = generated})
    threat = math.min(10000, threat + generated)

    if threat >= 10000 then
        local consumed = mutateState("consume_threat", {})
        if consumed then EclipseConquestManager.expandEmpire() end
    end
end

function EclipseConquestManager.expandEmpire()
    local EclipseGenerator = include("eclipsegenerator")
    local eclipseFaction = EclipseGenerator.getFaction()

    local state = canonicalState()
    if not state then return end
    local conqueredCount = state.territory.conqueredCount or 0
    local isFallenEmpire = state.territory.fallenEmpire

    -- Suppression Field Logic: Halt invasions dynamically (6 hours base + 2 hours per 10 sectors
    -- owned) after a Citadel dies (set in ca_citadel_loot.lua, only on an actual Citadel kill).
    -- Defaulting the "never happened yet" case to 0 instead of leaving it nil was a real bug: since
    -- Server().unpausedRuntime starts at (or near) 0 for a freshly created galaxy too, "no Citadel
    -- has ever died" and "a Citadel died at the exact moment the galaxy was created" were
    -- indistinguishable, silently suppressing ALL Eclipse expansion for the first 6+ hours of any
    -- galaxy's played time -- even before the Guardian is killed. Threat still accumulated and
    -- got consumed at the threshold, so nothing about this was visible; expansion simply stalled.
    local suppressionUntil = state.timers.citadelSuppressionUntil
    if suppressionUntil and Server().unpausedRuntime < suppressionUntil then
        return
    end

    -- Personal Ambush Logic (Migrated from legacy timer)
    -- Eclipse Remembers: a player's own eclipse_kill_score (credited in ca_eclipse_abilities.lua's
    -- onDestroyed) raises both how often they get personally targeted and how heavy the escort is,
    -- on top of the base 40% chance every player already had. Capped well short of guaranteed/absurd
    -- so this stays "the Eclipse is paying more attention to you," not an unwinnable spiral.
    -- Fetched once and reused for the rest of this function -- expandEmpire() runs synchronously
    -- with no yields, so the online-player list can't change mid-call.
    local players = {Server():getOnlinePlayers()}
    for _, player in pairs(players) do
        local wardUntil = player:getValue("eclipse_ward_until")
        local warded = wardUntil and Server().unpausedRuntime < wardUntil
        if not warded then
            local killScore = player:getValue("eclipse_kill_score") or 0
            local chance = math.min(0.85, 0.4 + killScore * 0.01)
            if random():getFloat(0, 1) < chance then
                local extraHeavies = math.min(4, math.floor(killScore / 10))
                player:addScriptOnce("data/scripts/player/events/eclipseinvasion.lua", extraHeavies)
            end
        end
    end

    -- Check if we should awaken
    if conqueredCount >= 75 and not isFallenEmpire then
        local fallenRevision = mutateState("set_fallen", {value = true})
        if not fallenRevision then return end
        isFallenEmpire = true
        include("ca_eclipse_choir").registerChoirLines("fallen_empire")
        CosmicAscendancyNews.Publish({
            kind = "escalation",
            eventId = "eclipse-fallen-empire",
            threadId = "eclipse-state",
            eventType = "ascendancy.eclipse.fallen_empire",
            topic = "threat",
            severity = "critical",
            breaking = true,
            recordType = "ca_state_v2",
            recordId = "eclipse-state",
            sourceRevision = fallenRevision,
            sourceState = "fallen_empire",
            article = {
                title = "GALACTIC THREAT: The Eclipse Awakens",
                content = "The algorithmic nightmare known as The Eclipse has consolidated enough territory to form a unified, highly organized empire. They have ceased random raids and are now actively launching Crusades to systematically eradicate all major AI faction capitals. We must unite, or we will perish.",
                category = "Galactic Dread"
            },
        })
    end

    local tx, ty
    local crusadeTargetFound = false

    if isFallenEmpire then
        -- Crusade Logic (Players/Alliances): a Fallen Empire also actively hunts player-controlled
        -- sectors that have stations on them, not just AI faction homeworlds, but on its own
        -- cooldown separate from the AI-faction crusade cadence below. Threat re-accumulates fast at
        -- a high conquered-sector count (every ~5-6 minutes once well past 75), so without a
        -- dedicated cooldown here a Fallen Empire could crusade the same online player over and over
        -- and become an unfair, nonstop grind. Also excludes whoever was targeted last time so
        -- consecutive crusades don't repeatedly single out the same player or alliance.
        local PLAYER_CRUSADE_COOLDOWN = 2400 -- 40 minutes between player-targeted crusades
        local lastPlayerCrusadeTime = state.history.lastPlayerCrusadeAt or -PLAYER_CRUSADE_COOLDOWN
        if Server().unpausedRuntime - lastPlayerCrusadeTime >= PLAYER_CRUSADE_COOLDOWN then
            local lastTargetIndex = state.history.lastPlayerCrusadeTarget
            local candidateFactions = {}
            local seenFactionIndex = {}
            for _, p in pairs(players) do
                local pf = p.craftFaction or p
                if pf and pf.index ~= lastTargetIndex and not seenFactionIndex[pf.index] then
                    seenFactionIndex[pf.index] = true
                    table.insert(candidateFactions, pf)
                end
            end

            -- On a solo save, or any server with only one player/alliance faction online, the
            -- exclusion above leaves candidateFactions permanently empty after the very first
            -- player-Crusade ever lands -- there's no OTHER faction to fall back to, so this branch
            -- would silently never fire again for the rest of that galaxy. Re-targeting the same
            -- faction is strictly better than the mechanic quietly disappearing for a whole class of
            -- server; only fall back to allowing lastTargetIndex when it's genuinely the only
            -- online candidate, so a busier server keeps the intended rotation.
            if #candidateFactions == 0 then
                for _, p in pairs(players) do
                    local pf = p.craftFaction or p
                    if pf and not seenFactionIndex[pf.index] then
                        seenFactionIndex[pf.index] = true
                        table.insert(candidateFactions, pf)
                    end
                end
            end

            if #candidateFactions > 0 then
                local targetFaction = candidateFactions[random():getInt(1, #candidateFactions)]

                -- Find one of that faction's own sectors that actually has a station, sourced from
                -- any online player's known-sector list (works whether the target is a solo player
                -- or an alliance, since a member's known sectors include alliance-owned territory).
                local stationSectors = {}
                for _, p in pairs(players) do
                    for _, view in pairs({p:getKnownSectors()}) do
                        if view and view.factionIndex == targetFaction.index and (view.numStations or 0) > 0 then
                            table.insert(stationSectors, view)
                        end
                    end
                end

                if #stationSectors > 0 then
                    local view = stationSectors[random():getInt(1, #stationSectors)]
                    tx, ty = view:getCoordinates()
                    mutateState("record_crusade", {
                        x = tx, y = ty, kind = "player", targetFactionIndex = targetFaction.index
                    })
                    Server():broadcastChatMessage("The Eclipse"%_T, 2, "Crusade designated. Coordinates (" .. tx .. ":" .. ty .. ") flagged for priority assimilation.")
                    crusadeTargetFound = true

                    -- Distress Beacon: alert every online member of the
                    -- targeted faction/alliance so others can converge before the consequence
                    -- actually lands. The real travel window this buys depends on which roll
                    -- happens below: an Annihilation/Siege record only materializes once someone visits
                    -- the sector through the shared durable queue, so a defender who
                    -- gets there first effectively delays it themselves; a Conquest roll starts
                    -- CosmicVaultTerritory's own 120-second contest window immediately, a much
                    -- tighter margin this mail can't extend (that timer belongs to Cosmic Vault,
                    -- not this file, and is genuinely 120 seconds -- see the setContestedZone call
                    -- below, which passes minutes, not seconds).
                    for _, p in pairs(players) do
                        local pf = p.craftFaction or p
                        if pf and pf.index == targetFaction.index then
                            local mail = Mail()
                            mail.header = "DISTRESS BEACON"%_T
                            mail.sender = "The Eclipse Threat Network"%_T
                            mail.text = Format("A Crusade has been designated against your territory at (%1%:%2%). Converge with allies if you can reach it in time."%_T, tx, ty)
                            p:addMail(mail)
                        end
                    end
                end
            end
        end
    end

    if isFallenEmpire and not crusadeTargetFound then
        -- Crusade Logic: Seek out an AI Faction Capital
        -- We randomly sample coordinates to find an active, non-eradicated AI faction
        local targets = {}
        local cpuTimer = HighResolutionTimer()
        cpuTimer:start()
        for i = 1, 100 do
            local sx = random():getInt(-490, 490)
            local sy = random():getInt(-490, 490)
            local faction = Galaxy():getControllingFaction(sx, sy)
            if type(faction) == "number" then faction = Faction(faction) end

            if faction and faction.isAIFaction and not faction:getValue("is_eclipse") and faction.name ~= "The Eclipse" then
                local isEradicated = false
                if FactionEradicationUtility and FactionEradicationUtility.isFactionEradicated then
                    isEradicated = FactionEradicationUtility.isFactionEradicated(faction.index)
                end

                if not isEradicated then
                    local hx, hy = faction:getHomeSectorCoordinates()
                    if hx and hy and (hx ~= 0 or hy ~= 0) then
                        table.insert(targets, {x=hx, y=hy, faction=faction})
                    end
                end
            end

            -- Stop once we have enough valid crusade candidates
            if #targets >= 5 then break end
            
            -- CPU Tick Safety: Abort if loop takes longer than 50ms
            if cpuTimer.seconds > 0.05 then break end
        end

        if #targets > 0 then
            local target = targets[random():getInt(1, #targets)]
            tx, ty = target.x, target.y
            recordCrusadeTarget(tx, ty, "ai_faction")
            Server():broadcastChatMessage("The Eclipse"%_T, 2, "Crusade designated. Sector (" .. tx .. ":" .. ty .. ") has been marked for priority assimilation.")
            crusadeTargetFound = true
        end
    end

    if not crusadeTargetFound then
        -- Normal Logic: Geographic Infection Spread
        local held = state.territory.held or {}
        local coords = {}
        for key in pairs(held) do
            local hx, hy = string.match(key, "^(%-?%d+):(%-?%d+)$")
            if hx then table.insert(coords, {x = tonumber(hx), y = tonumber(hy)}) end
        end

        if #coords == 0 then
            -- First-ever foothold. The lore (WIKI: "The Eclipse immediately begins surging outward
            -- from the galactic core") has them emerging at the core, so their opening conquest
            -- should originate there too, not wherever a random online player happens to have
            -- explored. isInsideBarrier=true keeps the search inside the core ring itself.
            local MissionUT = include("missionutility")
            local coreX, coreY = MissionUT.getEmptySector(0, 0, 10, 40, true)
            if coreX and coreY then
                tx, ty = coreX, coreY
            end
        elseif #coords > 0 then
            local maxAttempts = 10
            local foundNewTarget = false
            for attempt = 1, maxAttempts do
                local target = coords[random():getInt(1, #coords)]
                local ox, oy = target.x, target.y

                -- Bias the spread outward from the core (same lore premise) most of the time: step
                -- away from (0,0) relative to this held sector, with perpendicular jitter so the
                -- frontier isn't a perfect ring, and occasionally fall back to a fully random offset
                -- so some infill still happens behind the advancing edge.
                local distFromCore = math.sqrt(ox * ox + oy * oy)
                if distFromCore > 0.5 and random():getFloat() < 0.7 then
                    local dirX, dirY = ox / distFromCore, oy / distFromCore
                    local perpX, perpY = -dirY, dirX
                    local outward = random():getInt(1, 3)
                    local lateral = random():getInt(-2, 2)
                    tx = ox + math.floor(dirX * outward + perpX * lateral + 0.5)
                    ty = oy + math.floor(dirY * outward + perpY * lateral + 0.5)
                else
                    tx = ox + random():getInt(-3, 3)
                    ty = oy + random():getInt(-3, 3)
                end

                if not held[tostring(tx) .. ":" .. tostring(ty)] then
                    foundNewTarget = true
                    break -- Valid target
                end
            end

            -- Every attempt above collided with already-held territory -- don't hand a duplicate
            -- coordinate downstream. tx/ty are cleared so the known-sector fallback below gets a
            -- chance to pick something else (it's independently guarded against duplicates too, see
            -- the bailout right before the conquest/annihilation branch below).
            if not foundNewTarget then
                tx, ty = nil, nil
            end
        end

        -- Fallback: Random player known sector if no territory is held yet and no core sector could
        -- be found, or if every geographic-spread attempt above collided with existing territory.
        if not tx or not ty then
            if #players == 0 then return end
            local player = players[random():getInt(1, #players)]
            local knownSectors = {player:getKnownSectors()}
            if #knownSectors == 0 then return end
            local targetSector = knownSectors[random():getInt(1, #knownSectors)]
            tx, ty = targetSector:getCoordinates()
        end
    end

    -- Covers all three selection paths above (crusade target, geographic spread, known-sector
    -- fallback) with one check, rather than filtering the candidate pool for each individually.
    if isInsideSanctuaryField(tx, ty) then
        Server():broadcastChatMessage("The Eclipse"%_T, 2, "Assimilation of coordinates (" .. tx .. ":" .. ty .. ") repelled by an Ascendant Sanctuary Field.")
        return
    end

    -- Same one-check-covers-all-three-paths approach: a Crusade retarget (player home/AI capital)
    -- or the known-sector fallback can each independently land on a coordinate Eclipse already
    -- holds -- neither path is filtered against the canonical held-coordinate set the way the
    -- geographic-spread loop above is. Without this, "re-conquering" already-held ground would
    -- increment the canonical count past the real number of distinct sectors held, throwing
    -- off both the Fallen Empire threshold (conqueredCount >= 75) and /eclipsestatus's report.
    -- Simplest correct behavior: skip this tick entirely and let the next 60-second poll re-roll.
    do
        local latest = canonicalState()
        if latest and latest.territory.held[tostring(tx) .. ":" .. tostring(ty)] then
            return
        end
    end

    -- 40% chance to Conquest (Boarding/Siege via Cosmic War)
    -- 60% chance to Annihilation (Total wipe)
    if random():getFloat() < 0.4 then
        -- CONQUEST
        if CosmicVaultTerritory and CosmicVaultTerritory.setContestedZone then
            local defFactionObj = Galaxy():getControllingFaction(tx, ty)
            local defFactionIndex = type(defFactionObj) == "number" and defFactionObj
                or (defFactionObj and defFactionObj.index or 0)
            -- setContestedZone's duration is in MINUTES (Cosmic Vault's cosmicvaultterritory.lua).
            -- The 120-second contest window this file's own Distress Beacon text promises is 2
            -- minutes, not 120 minutes -- passing the literal 120 here opened a 2-hour window instead.
            CosmicVaultTerritory.setContestedZone(tx, ty, eclipseFaction.index, defFactionIndex, 2)
            Server():broadcastChatMessage("The Eclipse"%_T, 2, "Commencing assimilation of coordinates (" .. tx .. ":" .. ty .. "). Resistance is biologically inefficient.")

            -- PROGRESSIVE MATERIALIZATION (Lag Fix)
            local encounterId = EncounterBridge.MakeId("siege", "sector", tx, ty,
                math.floor(Server().unpausedRuntime))
            local prepared = EncounterBridge.Create(OWNER, {
                encounterId = encounterId, kind = "siege",
                concurrencyKey = "siege:" .. tx .. ":" .. ty,
                scope = "sector", x = tx, y = ty, state = "prepared"
            })
            if prepared then
                local queued, queueError = CosmicVaultTerritory.QueueMaterialization("siege", tx, ty, {
                    source = "eclipse_conquest", eclipseFactionIndex = eclipseFaction.index,
                    encounterId = encounterId
                })
                if not queued then
                    EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                        lastError = "siege_queue_failed:" .. tostring(queueError)})
                end
            end
        else
            -- Cosmic War not installed or hooked, fallback to Annihilation
            EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction, conqueredCount)
        end
    else
        -- ANNIHILATION
        EclipseConquestManager.annihilateSector(tx, ty, eclipseFaction, conqueredCount)
    end
end

function EclipseConquestManager.annihilateSector(x, y, eclipseFaction, conqueredCount)
    Server():broadcastChatMessage("The Eclipse"%_T, 2, "Coordinates (" .. x .. ":" .. y .. ") have been judged unworthy of Ascendancy. Initiating total atomic annihilation.")

    local encounterId = EncounterBridge.MakeId("annihilation", "sector", x, y,
        math.floor(Server().unpausedRuntime))
    local prepared = EncounterBridge.Create(OWNER, {
        encounterId = encounterId, kind = "annihilation",
        concurrencyKey = "annihilation:" .. x .. ":" .. y,
        scope = "sector", x = x, y = y, state = "prepared"
    })
    if prepared then
        local queued, queueError = CosmicVaultTerritory.QueueMaterialization("annihilation", x, y, {
            source = "eclipse_conquest", eclipseFactionIndex = eclipseFaction.index,
            encounterId = encounterId
        })
            if not queued then
                EncounterBridge.Transition(OWNER, encounterId, "repair_required", {
                    lastError = "annihilation_queue_failed:" .. tostring(queueError)})
            else
                CosmicAscendancyNews.Publish({
                    kind = "territory",
                    eventId = encounterId,
                    threadId = encounterId,
                    eventType = "ascendancy.territory.annihilation_queued",
                    topic = "threat",
                    severity = "critical",
                    breaking = true,
                    location = {x = x, y = y, radius = 0},
                    recordType = "ca_encounters_v1",
                    recordId = encounterId,
                    sourceRevision = prepared.revision or 1,
                    sourceState = "prepared",
                    provenance = {
                        recordType = "ca_encounters_v1",
                        recordId = tostring(encounterId),
                        materializationId = tostring(queued.id or "unknown"),
                        sourceRevision = prepared.revision or 1,
                        sourceState = "prepared",
                    },
                    article = {
                        title = "Eclipse Annihilation Directive: [" .. x .. ":" .. y .. "]",
                        content = "The Eclipse has queued a total-annihilation operation against sector ["
                            .. x .. ":" .. y .. "]. The sector has not yet been reported destroyed.",
                        category = "Galactic Dread",
                    },
                })
            end
        end
end

-- No secure()/restore() is needed: this manager carries no authoritative in-memory state.
-- Threat, territory, counters, and timers are owned by ca_state_coordinator.lua in ca_state_v2.

