package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news = include("cosmicvaultnews")

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
        Server():broadcastChatMessage("Galactic News"%_T, 0, "Heroic forces have destroyed the Eclipse Obliterator in sector (" .. x .. ":" .. y .. ")!")

        -- Worded as "secured the wreckage," not "halted the annihilation" -- the sector wipe this
        -- guardian was left to watch over already ran to completion before it ever spawned
        -- (ca_delayed_annihilation.lua), so there's nothing left for killing it to actually undo.
        if cv_news.publishArticle then
            cv_news.publishArticle({
                title = "Heroic Forces Secure The Wreckage!",
                content = "Against all odds, forces led by " .. faction.name .. " have destroyed the Eclipse Obliterator guarding the ruins of [" .. x .. ":" .. y .. "], clearing the way for the sector to be reclaimed.",
                category = "Heroic Victories"
            })
        end
    end
end
