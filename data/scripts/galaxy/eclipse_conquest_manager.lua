package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- stringutility installs the %_T/%_t metamethod on the string metatable; it is also pulled in
-- transitively via cosmicvaultterritory.lua below, but declared directly here too (matching the
-- explicit-include convention used elsewhere in this mod, e.g. eclipse_awakes.lua) so this file's
-- %_T usage below doesn't silently depend on a Cosmic Vault internal staying unchanged.
include("stringutility")

local CosmicVaultTerritory = nil
local cv_goods = include("cosmicvaultgoods")
local cv_news = include("cosmicvaultnews")
local FactionEradicationUtility = include("factioneradicationutility")
CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace EclipseConquestManager
EclipseConquestManager = {}

-- These coordinate lists only delimit entries with a trailing comma (e.g. "25_10,5_10,"), so a
-- plain substring search for "5_10," would false-positive inside "25_10,". Anchor both sides by
-- also requiring the leading comma so entries can't match as a substring of a longer coordinate.
local function listHasCoord(list, entry)
    return string.find("," .. list, "," .. entry, 1, true) ~= nil
end

-- Sanctuary Field: a Tier 3+ Ascendancy Beacon (see ascendancybeacon.lua's updateSanctuaryRegistry)
-- actively repels Eclipse conquest attempts within its radius. The registry lives on Server()
-- rather than the beacon entity itself, since the beacon's own sector may not be loaded when the
-- Eclipse tries to expand nearby.
local function isInsideSanctuaryField(tx, ty)
    local registry = Server():getValue("ascendancy_beacon_sanctuary_registry") or {}
    for _, field in pairs(registry) do
        local dx, dy = tx - field.x, ty - field.y
        if math.sqrt(dx * dx + dy * dy) <= field.radius then
            return true
        end
    end
    return false
end

-- Recorded so /eclipsestatus (eclipsestatus.lua) can show the Eclipse's last known Crusade target.
-- This is a Fallen Empire-only event (a single-shot pick-and-act, not an ongoing pursuit with its
-- own persistent state), so this simply timestamps the most recent one rather than tracking a
-- currently-in-progress target.
local function recordCrusadeTarget(tx, ty, targetKind)
    Server():setValue("eclipse_last_crusade_target", {x = tx, y = ty, kind = targetKind, time = Server().unpausedRuntime})
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
    if not Server():getValue("eclipse_fully_awake") then return end

    -- Pause expansion if no players are online (protects 24/7 dedicated servers from offline wipes)
    local players = {Server():getOnlinePlayers()}
    if #players == 0 then return end

    local conqueredCount = Server():getValue("eclipse_conquered_sectors") or 0
    local threat = Server():getValue("eclipse_threat") or 0
    
    -- Threat generation: Base 300 per minute + (20 per held sector per minute)
    local threatPerSecond = (300 + (conqueredCount * 20)) / 60.0
    threat = threat + (threatPerSecond * timeStep)
    Server():setValue("eclipse_threat", threat)

    if threat >= 10000 then
        Server():setValue("eclipse_threat", threat - 10000)
        EclipseConquestManager.expandEmpire()
    end
end

function EclipseConquestManager.expandEmpire()
    local EclipseGenerator = include("eclipsegenerator")
    local eclipseFaction = EclipseGenerator.getFaction()

    local conqueredCount = Server():getValue("eclipse_conquered_sectors") or 0
    local isFallenEmpire = Server():getValue("eclipse_fallen_empire")

    -- Suppression Field Logic: Halt invasions dynamically (6 hours base + 2 hours per 10 sectors
    -- owned) after a Citadel dies (set in ca_citadel_loot.lua, only on an actual Citadel kill).
    -- Defaulting the "never happened yet" case to 0 instead of leaving it nil was a real bug: since
    -- Server().unpausedRuntime starts at (or near) 0 for a freshly created galaxy too, "no Citadel
    -- has ever died" and "a Citadel died at the exact moment the galaxy was created" were
    -- indistinguishable, silently suppressing ALL Eclipse expansion for the first 6+ hours of any
    -- galaxy's played time -- even before the Guardian is killed. eclipse_threat still accumulated
    -- and got reset every time it crossed 10000 (expandEmpire() bails out AFTER that reset already
    -- happened in updateServer()), so nothing about this was visible or loggable; it just looked
    -- like the Eclipse's territorial expansion silently never did anything.
    local citadelDestroyed = Server():getValue("eclipse_citadel_destroyed_time")
    if citadelDestroyed then
        local suppressionDuration = (6 + math.floor(conqueredCount / 10) * 2) * 3600
        if Server().unpausedRuntime - citadelDestroyed < suppressionDuration then
            return -- Suppressed
        end
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
        Server():setValue("eclipse_fallen_empire", true)
        isFallenEmpire = true
        include("ca_eclipse_choir").registerChoirLines("fallen_empire")
        if cv_news.publishArticle then
            cv_news.publishArticle({
                title = "GALACTIC THREAT: The Eclipse Awakens",
                content = "The algorithmic nightmare known as The Eclipse has consolidated enough territory to form a unified, highly organized empire. They have ceased random raids and are now actively launching Crusades to systematically eradicate all major AI faction capitals. We must unite, or we will perish.",
                category = "Galactic Dread"
            })
        end
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
        local lastPlayerCrusadeTime = Server():getValue("eclipse_last_player_crusade_time") or -PLAYER_CRUSADE_COOLDOWN
        if Server().unpausedRuntime - lastPlayerCrusadeTime >= PLAYER_CRUSADE_COOLDOWN then
            local lastTargetIndex = Server():getValue("eclipse_last_player_crusade_target")
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
                    Server():setValue("eclipse_last_player_crusade_time", Server().unpausedRuntime)
                    Server():setValue("eclipse_last_player_crusade_target", targetFaction.index)
                    recordCrusadeTarget(tx, ty, "player")
                    Server():broadcastChatMessage("The Eclipse"%_T, 2, "Crusade designated. Coordinates (" .. tx .. ":" .. ty .. ") flagged for priority assimilation.")
                    crusadeTargetFound = true

                    -- Distress Beacon: alert every online member of the
                    -- targeted faction/alliance so others can converge before the consequence
                    -- actually lands. The real travel window this buys depends on which roll
                    -- happens below: an Annihilation/Siege roll only executes once someone visits
                    -- the sector (the existing eclipse_pending_annihilations/eclipse_pending_sieges
                    -- progressive-materialization queue, already in this file), so a defender who
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
        local territoryString = Server():getValue("eclipse_held_territory") or ""
        local coords = {}
        for match in string.gmatch(territoryString, "(%-?%d+_%-?%d+),") do
            table.insert(coords, match)
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
                local ox, oy = string.match(target, "(%-?%d+)_(%-?%d+)")
                ox, oy = tonumber(ox), tonumber(oy)

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

                local checkString = tx .. "_" .. ty .. ","
                if not listHasCoord(territoryString, checkString) then
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
    -- holds -- neither path is filtered against eclipse_held_territory the way the geographic-spread
    -- loop above is. Without this, "re-conquering" already-held ground would unconditionally
    -- increment eclipse_conquered_sectors past the real number of distinct sectors held, throwing
    -- off both the Fallen Empire threshold (conqueredCount >= 75) and /eclipsestatus's report.
    -- Simplest correct behavior: skip this tick entirely and let the next 60-second poll re-roll.
    do
        local held = Server():getValue("eclipse_held_territory") or ""
        if listHasCoord(held, tx .. "_" .. ty .. ",") then
            return
        end
    end

    -- 40% chance to Conquest (Boarding/Siege via Cosmic War)
    -- 60% chance to Annihilation (Total wipe)
    if random():getFloat() < 0.4 then
        -- CONQUEST
        if CosmicVaultTerritory and CosmicVaultTerritory.setContestedZone then
            local defFactionObj = Galaxy():getControllingFaction(tx, ty)
            local defFactionIndex = defFactionObj and defFactionObj.index or 0
            -- setContestedZone's duration is in MINUTES (Cosmic Vault's cosmicvaultterritory.lua).
            -- The 120-second contest window this file's own Distress Beacon text promises is 2
            -- minutes, not 120 minutes -- passing the literal 120 here opened a 2-hour window instead.
            CosmicVaultTerritory.setContestedZone(tx, ty, eclipseFaction.index, defFactionIndex, 2)
            Server():broadcastChatMessage("The Eclipse"%_T, 2, "Commencing assimilation of coordinates (" .. tx .. ":" .. ty .. "). Resistance is biologically inefficient.")

            -- PROGRESSIVE MATERIALIZATION (Lag Fix)
            local pendingSieges = Server():getValue("eclipse_pending_sieges") or ""
            local entry = tx .. "_" .. ty .. ","
            if not listHasCoord(pendingSieges, entry) then
                Server():setValue("eclipse_pending_sieges", pendingSieges .. entry)
            end

            -- Increment counter since it's a conquest attempt that will turn the sector
            Server():setValue("eclipse_conquered_sectors", conqueredCount + 1)

            -- Track for geographic expansion
            local held = Server():getValue("eclipse_held_territory") or ""
            if not listHasCoord(held, entry) then
                Server():setValue("eclipse_held_territory", held .. entry)
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

    if cv_news.publishArticle then
        cv_news.publishArticle({
            title = "Sector Annihilated: [" .. x .. ":" .. y .. "]",
            content = "The Eclipse has completely wiped coordinates [" .. x .. ":" .. y .. "] from the map. Billions are feared dead as all stations and ships were atomically disintegrated.",
            category = "Galactic Dread"
        })
    end

    -- Increment global conquest tracker
    Server():setValue("eclipse_conquered_sectors", (conqueredCount or Server():getValue("eclipse_conquered_sectors") or 0) + 1)

    -- PROGRESSIVE MATERIALIZATION (Lag Fix)
    -- Instead of forcefully loading the sector and causing CPU spikes, we append it to the pending list.
    local pending = Server():getValue("eclipse_pending_annihilations") or ""
    local entry = x .. "_" .. y .. ","
    if not listHasCoord(pending, entry) then
        Server():setValue("eclipse_pending_annihilations", pending .. entry)
    end

    -- Also track for geographic expansion
    local held = Server():getValue("eclipse_held_territory") or ""
    if not listHasCoord(held, entry) then
        Server():setValue("eclipse_held_territory", held .. entry)
    end
end

-- No secure()/restore() needed: this script carries no in-memory state of its own -- everything
-- that matters (eclipse_threat, eclipse_conquered_sectors, eclipse_held_territory, etc.) is already
-- persisted via Server():setValue(), which survives a reload independently of this script's
-- lifecycle hooks. (A dead EclipseConquestManager.timer field that round-tripped through these two
-- functions with nothing ever reading or writing it otherwise has been removed.)

