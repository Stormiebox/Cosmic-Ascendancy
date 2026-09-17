package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
local CosmicAscendancyNews = include("ca_news")

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed(index, lastDamageInflictor)
    if not onServer() then return end
    
    if not lastDamageInflictor then return end
    
    local destroyer = Entity(lastDamageInflictor)
    if not valid(destroyer) then return end
    
    local faction = Faction(destroyer.factionIndex)
    if faction and (faction.isPlayer or faction.isAlliance) then
        local x, y = Sector():getCoordinates()
        local defendedEntity = Entity()
        local entityId = defendedEntity.id.string
        local sourceEncounterId = defendedEntity:getValue("ca_encounter_id")
        local newsThreadId = defendedEntity:getValue("ca_news_thread_id")
        Server():broadcastChatMessage("Galactic News"%_T, 0, "Heroic forces have destroyed the Eclipse Obliterator in sector (" .. x .. ":" .. y .. ")!")

        -- Worded as "secured the wreckage," not "halted the annihilation" -- the sector wipe this
        -- guardian was left to watch over already ran to completion before it ever spawned
        -- (ca_delayed_annihilation.lua), so there's nothing left for killing it to actually undo.
        CosmicAscendancyNews.Publish({
            kind = "encounter",
            eventId = "heroic-defense:" .. tostring(entityId),
            threadId = newsThreadId or sourceEncounterId or ("obliterator:" .. tostring(entityId)),
            eventType = "ascendancy.obliterator.destroyed",
            topic = "conflict",
            severity = "info",
            location = {x = x, y = y, radius = 0},
            recordType = sourceEncounterId and "ca_encounters_v1" or "entity_destruction",
            recordId = sourceEncounterId or entityId,
            sourceRevision = 1,
            sourceState = "destroyed_by_player_faction",
            provenance = {
                recordType = sourceEncounterId and "ca_encounters_v1" or "entity_destruction",
                recordId = tostring(sourceEncounterId or entityId),
                entityId = tostring(entityId),
                destroyerFactionIndex = faction.index,
                sourceRevision = 1,
                sourceState = "destroyed_by_player_faction",
            },
            article = {
                title = "Heroic Forces Secure The Wreckage!",
                content = "Against all odds, forces led by " .. faction.name .. " have destroyed the Eclipse Obliterator guarding the ruins of [" .. x .. ":" .. y .. "], clearing the way for the sector to be reclaimed.",
                category = "Heroic Victories"
            },
        })
    end
end
