package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news_success, cv_news = pcall(require, "cosmicvaultnews")

function initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function onDestroyed(index, lastDamageInflictor)
    if not onServer() then return end
    
    local destroyer = Entity(lastDamageInflictor)
    if not destroyer then return end
    
    local faction = Faction(destroyer.factionIndex)
    if faction and (faction.isPlayer or faction.isAlliance) then
        local x, y = Sector():getCoordinates()
        Server():broadcastChatMessage("Galactic News", 0, "Heroic forces have destroyed the Eclipse Obliterator in sector (" .. x .. ":" .. y .. ")!")
        
        if cv_news_success and cv_news.publishArticle then
            cv_news.publishArticle({
                title = "Heroic Defense Halts The Eclipse Advance!",
                content = "Against all odds, forces led by " .. faction.name .. " have destroyed an Eclipse Obliterator at [" .. x .. ":" .. y .. "], halting the sector annihilation sequence.",
                category = "Heroic Victories"
            })
        end
    end
end
