package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local Dialog = include("dialogutility")

function interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    if not player:getValue("wormhole_guardian_destroyed") then return false end
    if player:getValue("ca_campaign_completed") then return false end
    if player:hasScript("data/scripts/player/missions/ca_story1_awakening.lua") then return false end
    if player:hasScript("data/scripts/player/missions/ca_story2_forge.lua") then return false end
    if player:hasScript("data/scripts/player/missions/ca_story3_vanguard.lua") then return false end
    
    local x, y = Sector():getCoordinates()
    local dist = math.sqrt(x*x + y*y)
    if dist > 200 then return false end
    
    return true
end

function initUI()
    ScriptUI():registerInteraction("Ask about the Wormhole Guardian", "onInteract")
end

function onInteract()
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    
    d0.text = "You... you defeated the Wormhole Guardian? Fool! Do you know what you've done?"
    d0.answers = {
        {answer = "I freed the galaxy. You're welcome.", followUp = d1},
        {answer = "What do you mean?", followUp = d1}
    }
    
    d1.text = "The Guardian wasn't just hoarding Avorion. It was a lock! A seal holding back an ancient adversary known as The Eclipse. With the Guardian gone, they are waking up."
    d1.answers = {
        {answer = "Who are The Eclipse?", followUp = d3},
        {answer = "Where are they?", followUp = d2}
    }
    
    d3.text = "They are a mechanical plague. An algorithmic nightmare that eradicates biological and chaotic synthetic life. They were sealed away eons ago, but now they are free."
    d3.answers = {
        {answer = "I will stop them. Where do I start?", followUp = d2}
    }
    
    d2.text = "I've detected a massive energy spike nearby. I need you to go investigate it immediately. Be careful... they are not like the Xsotan."
    d2.answers = {
        {answer = "I will investigate. Send me the coordinates.", onSelect = "startCampaign"}
    }
    
    ScriptUI():showDialog(d0)
end

function startCampaign()
    if onClient() then
        invokeServerFunction("startCampaign")
        return
    end
    
    local player = Player(callingPlayer)
    if player then
        player:addScriptOnce("data/scripts/player/missions/ca_story1_awakening.lua")
    end
end
callable(nil, "startCampaign")
