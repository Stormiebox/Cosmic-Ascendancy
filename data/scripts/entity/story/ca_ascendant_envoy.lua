package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CAAegisEnvoy
CAAegisEnvoy = {}

CAAegisEnvoy = include("npcapi/singleinteraction")
include("stringutility")
include("callable")
local SectorTurretGenerator = include("sectorturretgenerator")
local UpgradeGenerator = include("upgradegenerator")

local data = CAAegisEnvoy.data

data.given = {}
data.hail = false
data.closeableDialog = false
data.globalInteractionKey = "ca_aegis_envoy"

function CAAegisEnvoy.getDialog()
    return CAAegisEnvoy.makeDialog()
end

function CAAegisEnvoy.makeDialog()
    local player = Player()
    
    if player:getValue("ca_ready_for_debrief_5") then
        return CAAegisEnvoy.makeDialogStory5()
    elseif player:getValue("ca_ready_for_debrief_4") then
        return CAAegisEnvoy.makeDialogStory4()
    elseif player:getValue("ca_ready_for_debrief_3") then
        return CAAegisEnvoy.makeDialogStory3()
    elseif player:getValue("ca_ready_for_debrief_2") then
        return CAAegisEnvoy.makeDialogStory2()
    elseif player:getValue("ca_ready_for_debrief_1") then
        return CAAegisEnvoy.makeDialogStory1()
    elseif player:getValue("ca_ready_for_debrief_intro") then
        return CAAegisEnvoy.makeDialogIntro()
    else
        -- Fallback if they already talked to her or have no pending debriefs
        return CAAegisEnvoy.makeDialogFallback()
    end
end

function CAAegisEnvoy.makeDialogFallback()
    local d0 = {}
    d0.text = "Commander. I am currently analyzing subspace anomalies. Continue with your mission."%_t
    d0.answers = {{answer = "Understood."%_t}}
    return d0
end

-- ==========================================
-- INITIAL INTRO (Grants Mission 1)
-- ==========================================
function CAAegisEnvoy.makeDialogIntro()
    local d0_Hail = {}
    local d1_Who = {}
    local d2_What = {}
    local d3_Failsafe = {}
    local d4_Mission = {}
    local d5_Accept = {}

    d0_Hail.text = "Commander. Do not be alarmed by my sudden appearance. I am Aegis, an autonomous archival construct built by the Ascendants. By destroying the Keystone—what you call the Wormhole Guardian—you have unraveled the dimensional knot. The prison is broken."%_t
    d0_Hail.answers = {{answer = "Prison? What did I unleash?"%_t, followUp = d1_Who}}
    
    d1_Who.text = "The Eclipse. A sentient algorithmic plague from outside this reality. Their sole directive is to sanitize this galaxy of all chaotic, biological life. They do not conquer; they exterminate. And they are already here."%_t
    d1_Who.answers = {{answer = "How do we stop them?"%_t, followUp = d2_What}}

    d2_What.text = "My creators, the Ascendants, sacrificed themselves to build the prison. As a contingency, they built the Ascendancy Forge—a factory capable of producing weaponry that defies the Eclipse's dimensional armor."%_t
    d2_What.answers = {{answer = "Where is this Forge?"%_t, followUp = d3_Failsafe}}

    d3_Failsafe.text = "It lies hidden, dormant. To operate, it requires Ascendant Matter, a paradoxical substance found only within the cores of Eclipse vessels. You must seek out the nearest subspace anomaly and harvest it from their wreckage."%_t
    d3_Failsafe.answers = {{answer = "I will find this anomaly."%_t, followUp = d4_Mission}}

    d4_Mission.text = "The destruction of the Keystone imprinted a unique dimensional frequency upon your flagship. You are the designated heir to this ancient war. I am transmitting the coordinates of the first detected anomaly now. May the stars guide your path, Commander."%_t
    d4_Mission.answers = {{answer = "Understood."%_t, followUp = d5_Accept}}

    d5_Accept.text = "I must analyze the spreading incursions. We will speak again when you have secured the Ascendancy Forge."%_t
    d5_Accept.onEnd = "onAcceptIntro"

    return d0_Hail
end

function CAAegisEnvoy.onAcceptIntro()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_intro", nil)
        player:addScriptOnce("data/scripts/player/missions/ca_story1_awakening.lua")
        -- Removed warpAway() to allow other players in the sector to interact.
    end
end

-- ==========================================
-- END OF STORY 1 (Grants Mission 2 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory1()
    local d0_Hail = {}
    d0_Hail.text = "You survived the Vanguard ambush. Exceptional combat performance, Commander. The anomaly you investigated was merely a scouting beacon, but it proves The Eclipse are massing forces."%_t
    d0_Hail.answers = {{answer = "What's our next move?"%_t, followUp = {
        text = "Conventional weapons are inefficient against their dimensional plating. I am uploading the coordinates to the dormant Ascendancy Forge. You must secure it. I have transferred emergency supplies to aid your journey.",
        answers = {{answer = "I'm on my way.", onEnd = "onAcceptStory1"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory1()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_1", nil)

        player:addScriptOnce("data/scripts/player/missions/ca_story2_forge.lua")
        
        -- Rewards (2.5M, 2 Turrets, 1 System)
        player:receive("Ascendant Support Funding", 2500000)
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator(Seed(x + y))
        for i=1, 2 do
            local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
            player:getInventory():add(InventoryTurret(turret))
        end
        player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Rare)))
    end
end

-- ==========================================
-- END OF STORY 2 (Grants Mission 3 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory2()
    local d0_Hail = {}
    d0_Hail.text = "The Ascendancy Forge is fully operational! We now possess the means to retaliate. However... I detect a massive energy spike warping directly to our location!"%_t
    d0_Hail.answers = {{answer = "What is it?"%_t, followUp = {
        text = "An Eclipse Vanguard Juggernaut. It must have tracked the Forge's energy signature! Defend this sector at all costs. I am transferring emergency combat supplies to your hold.",
        answers = {{answer = "We will hold them off!", onEnd = "onAcceptStory2"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory2()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_2", nil)

        player:addScriptOnce("data/scripts/player/missions/ca_story3_vanguard.lua")
        
        -- Rewards (5M, 2 Turrets, 2 Systems)
        player:receive("Ascendant Support Funding", 5000000)
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator(Seed(x + y))
        for i=1, 2 do
            local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exceptional))
            player:getInventory():add(InventoryTurret(turret))
        end
        for i=1, 2 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exceptional))) end
    end
end

-- ==========================================
-- END OF STORY 3 (Grants Mission 4 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory3()
    local d0_Hail = {}
    d0_Hail.text = "The Vanguard assault is repelled. Exceptional work. However... I have intercepted a terrifying transmission. An Eclipse Citadel is attempting to anchor itself into our dimension."%_t
    d0_Hail.answers = {{answer = "A Citadel?"%_t, followUp = {
        text = "A massive mobile fortress capable of suppressing all hyperspace activity in the region. If it fully anchors, we will lose this sector entirely. You must destroy it. Take these supplies.",
        answers = {{answer = "It won't survive.", onEnd = "onAcceptStory3"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory3()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_3", nil)

        player:addScriptOnce("data/scripts/player/missions/ca_story4_citadel.lua")
        
        -- Rewards (7.5M, 2 Turrets, 1 System)
        player:receive("Ascendant Support Funding", 7500000)
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator(Seed(x + y))
        for i=1, 2 do
            local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exotic))
            player:getInventory():add(InventoryTurret(turret))
        end
        player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exotic)))
    end
end

-- ==========================================
-- END OF STORY 4 (Grants Mission 5 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory4()
    local d0_Hail = {}
    d0_Hail.text = "The Citadel has fallen! A monumental victory! But do not celebrate yet... The destruction of the Citadel has triggered a Level Omega incursion alert. A World-Eater has entered the galaxy."%_t
    d0_Hail.answers = {{answer = "A World-Eater? Explain."%_t, followUp = {
        text = "An apocalyptic dreadnought. It consumes entire star systems to fuel its dimensional engines. If it is not stopped, there will be no galaxy left to save. This is the final stand, Commander. Everything rests on you.",
        answers = {{answer = "I will finish this.", onEnd = "onAcceptStory4"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory4()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_4", nil)

        player:addScriptOnce("data/scripts/player/missions/ca_story5_worldeater.lua")
        
        -- Rewards (10M, 3 Turrets, 2 Systems)
        player:receive("Ascendant Support Funding", 10000000)
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator(Seed(x + y))
        for i=1, 3 do
            local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exotic))
            player:getInventory():add(InventoryTurret(turret))
        end
        for i=1, 2 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exotic))) end
    end
end

-- ==========================================
-- END OF STORY 5 (Campaign Complete)
-- ==========================================
function CAAegisEnvoy.makeDialogStory5()
    local d0_Hail = {}
    d0_Hail.text = "The World-Eater is destroyed... The dimensional rifts are sealing. You have done the impossible, Commander. You have stopped the sanitation protocol and saved the galaxy."%_t
    d0_Hail.answers = {{answer = "Is it over?"%_t, followUp = {
        text = "The Eclipse is broken, scattered. Their remnants will linger, but the immediate threat of annihilation has passed. My creators would be proud. As a token of the Ascendants' gratitude, accept this ultimate cache.",
        answers = {{answer = "Thank you, Aegis.", onEnd = "onAcceptStory5"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory5()
    if onServer() then
        local player = Player()
        player:setValue("ca_ready_for_debrief_5", nil)

        
        -- Rewards (25M, 5 Legendary Turrets, 3 Legendary Systems)
        player:receive("Ascendant Heritage", 25000000)
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator(Seed(x + y))
        for i=1, 5 do
            local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Legendary))
            player:getInventory():add(InventoryTurret(turret))
        end
        for i=1, 3 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Legendary))) end
    end
end

-- Ensure it's globally callable in the namespace
callable(CAAegisEnvoy, "onAcceptIntro")
callable(CAAegisEnvoy, "onAcceptStory1")
callable(CAAegisEnvoy, "onAcceptStory2")
callable(CAAegisEnvoy, "onAcceptStory3")
callable(CAAegisEnvoy, "onAcceptStory4")
callable(CAAegisEnvoy, "onAcceptStory5")
