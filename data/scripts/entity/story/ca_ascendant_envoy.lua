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

-- addScriptOnce swallows a failure inside the target script's own initialize() -- the engine logs
-- "Error while adding file X: <error>" and moves on rather than propagating the error back into
-- the caller (confirmed against a real crash log elsewhere in this project). Without verifying the
-- next mission actually attached, every onAcceptX handler below would clear its debrief flag (and,
-- for the story handlers, grant rewards) even if the mission grant silently failed, leaving the
-- player stuck on the generic fallback dialog forever with no mission and no way to recover. See
-- the Modding Codex's "🔄 Self-Healing Systems" section for the general pattern.
local function missionScriptAttached(player, scriptName)
    for _, path in pairs({player:getScripts()}) do
        if type(path) == "string" and string.find(path, scriptName, 1, true) then
            return true
        end
    end
    return false
end

function CAAegisEnvoy.getDialog()
    return CAAegisEnvoy.makeDialog()
end

-- npcapi/singleinteraction's globalInteractionKey marks the player as "already interacted" the
-- first time ANY dialog here auto-opens (see SingleInteraction.rememberSuccessfulInteractionWithPlayer),
-- and that flag is permanent and keyed on the player, not on this specific ship. Since a fresh Aegis
-- ship spawns for every debrief (story1 through story5), the auto-hail in SingleInteraction.updateClient
-- would only ever fire once in total, for the very first intro conversation, then silently refuse to
-- open the dialog on every later Aegis encounter for the rest of the campaign. Vanilla's own reference
-- implementation of this same framework (entity/story/adventurer1.lua, cited above for the RPC-forwarding
-- pattern) pairs it with a manual interaction option for exactly this reason. Mirrored here so the player
-- always has a way to talk to Aegis, auto-hail or not.
function CAAegisEnvoy.initUI()
    ScriptUI():registerInteraction("Talk"%_t, "onGreet")
end

function CAAegisEnvoy.onGreet()
    ScriptUI():showDialog(CAAegisEnvoy.makeDialog(), false)
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
    -- ScriptUI():interactShowDialog() only exists client-side, so dialog onEnd handlers
    -- always fire on the client first and must be forwarded to the server (vanilla does
    -- this in every onEnd handler, e.g. Adventurer1.givePlayerGoodie in adventurer1.lua).
    if onClient() then
        invokeServerFunction("onAcceptIntro")
        return
    end

    if data.given["intro" .. callingPlayer] then return end
    data.given["intro" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:addScriptOnce("data/scripts/player/missions/ca_story1_awakening.lua")

    if not missionScriptAttached(player, "ca_story1_awakening.lua") then
        data.given["intro" .. callingPlayer] = nil -- allow retry via the manual "Talk" option
        return
    end

    player:setValue("ca_ready_for_debrief_intro", nil)
    -- Removed warpAway() to allow other players in the sector to interact.
end

-- ==========================================
-- END OF STORY 1 (Grants Mission 2 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory1()
    local d0_Hail = {}
    d0_Hail.text = "You survived the Vanguard ambush. Exceptional combat performance, Commander. The anomaly you investigated was merely a scouting beacon, but it proves The Eclipse are massing forces."%_t
    d0_Hail.answers = {{answer = "What's our next move?"%_t, followUp = {
        text = "Conventional weapons are inefficient against their dimensional plating. I am uploading the coordinates to the dormant Ascendancy Forge. You must secure it. I have transferred emergency supplies to aid your journey."%_t,
        answers = {{answer = "I'm on my way."%_t, onEnd = "onAcceptStory1"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory1()
    if onClient() then
        invokeServerFunction("onAcceptStory1")
        return
    end

    if data.given["story1" .. callingPlayer] then return end
    data.given["story1" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:addScriptOnce("data/scripts/player/missions/ca_story2_forge.lua")

    if not missionScriptAttached(player, "ca_story2_forge.lua") then
        data.given["story1" .. callingPlayer] = nil
        return
    end

    player:setValue("ca_ready_for_debrief_1", nil)

    -- Rewards (2.5M, 2 Turrets, 1 System)
    player:receive("Ascendant Support Funding", 2500000)
    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator(Sector().seed)
    for i=1, 2 do
        local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
        player:getInventory():add(InventoryTurret(turret))
    end
    player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Rare)))
end

-- ==========================================
-- END OF STORY 2 (Grants Mission 3 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory2()
    local d0_Hail = {}
    d0_Hail.text = "The Ascendancy Forge is fully operational! We now possess the means to retaliate. However... I detect a massive energy spike warping directly to our location!"%_t
    d0_Hail.answers = {{answer = "What is it?"%_t, followUp = {
        text = "An Eclipse Vanguard Juggernaut. It must have tracked the Forge's energy signature! Defend this sector at all costs. I am transferring emergency combat supplies to your hold."%_t,
        answers = {{answer = "We will hold them off!"%_t, onEnd = "onAcceptStory2"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory2()
    if onClient() then
        invokeServerFunction("onAcceptStory2")
        return
    end

    if data.given["story2" .. callingPlayer] then return end
    data.given["story2" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:addScriptOnce("data/scripts/player/missions/ca_story3_vanguard.lua")

    if not missionScriptAttached(player, "ca_story3_vanguard.lua") then
        data.given["story2" .. callingPlayer] = nil
        return
    end

    player:setValue("ca_ready_for_debrief_2", nil)

    -- Rewards (5M, 2 Turrets, 2 Systems)
    player:receive("Ascendant Support Funding", 5000000)
    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator(Sector().seed)
    for i=1, 2 do
        local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exceptional))
        player:getInventory():add(InventoryTurret(turret))
    end
    for i=1, 2 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exceptional))) end
end

-- ==========================================
-- END OF STORY 3 (Grants Mission 4 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory3()
    local d0_Hail = {}
    d0_Hail.text = "The Vanguard assault is repelled. Exceptional work. However... I have intercepted a terrifying transmission. An Eclipse Citadel is attempting to anchor itself into our dimension."%_t
    d0_Hail.answers = {{answer = "A Citadel?"%_t, followUp = {
        text = "A massive mobile fortress capable of suppressing all hyperspace activity in the region. If it fully anchors, we will lose this sector entirely. You must destroy it. Take these supplies."%_t,
        answers = {{answer = "It won't survive."%_t, onEnd = "onAcceptStory3"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory3()
    if onClient() then
        invokeServerFunction("onAcceptStory3")
        return
    end

    if data.given["story3" .. callingPlayer] then return end
    data.given["story3" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:addScriptOnce("data/scripts/player/missions/ca_story4_citadel.lua")

    if not missionScriptAttached(player, "ca_story4_citadel.lua") then
        data.given["story3" .. callingPlayer] = nil
        return
    end

    player:setValue("ca_ready_for_debrief_3", nil)

    -- Rewards (7.5M, 2 Turrets, 1 System)
    player:receive("Ascendant Support Funding", 7500000)
    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator(Sector().seed)
    for i=1, 2 do
        local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exotic))
        player:getInventory():add(InventoryTurret(turret))
    end
    player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exotic)))
end

-- ==========================================
-- END OF STORY 4 (Grants Mission 5 + Rewards)
-- ==========================================
function CAAegisEnvoy.makeDialogStory4()
    local d0_Hail = {}
    d0_Hail.text = "The Citadel has fallen! A monumental victory! But do not celebrate yet... The destruction of the Citadel has triggered a Level Omega incursion alert. A World-Eater has entered the galaxy."%_t
    d0_Hail.answers = {{answer = "A World-Eater? Explain."%_t, followUp = {
        text = "An apocalyptic dreadnought. It consumes entire star systems to fuel its dimensional engines. If it is not stopped, there will be no galaxy left to save. This is the final stand, Commander. Everything rests on you."%_t,
        answers = {{answer = "I will finish this."%_t, onEnd = "onAcceptStory4"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory4()
    if onClient() then
        invokeServerFunction("onAcceptStory4")
        return
    end

    if data.given["story4" .. callingPlayer] then return end
    data.given["story4" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:addScriptOnce("data/scripts/player/missions/ca_story5_worldeater.lua")

    if not missionScriptAttached(player, "ca_story5_worldeater.lua") then
        data.given["story4" .. callingPlayer] = nil
        return
    end

    player:setValue("ca_ready_for_debrief_4", nil)

    -- Rewards (10M, 3 Turrets, 2 Systems)
    player:receive("Ascendant Support Funding", 10000000)
    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator(Sector().seed)
    for i=1, 3 do
        local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Exotic))
        player:getInventory():add(InventoryTurret(turret))
    end
    for i=1, 2 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Exotic))) end
end

-- ==========================================
-- END OF STORY 5 (Campaign Complete)
-- ==========================================
function CAAegisEnvoy.makeDialogStory5()
    local d0_Hail = {}
    d0_Hail.text = "The World-Eater is destroyed... The dimensional rifts are sealing. You have done the impossible, Commander. You have stopped the sanitation protocol and saved the galaxy."%_t
    d0_Hail.answers = {{answer = "Is it over?"%_t, followUp = {
        text = "The Eclipse is broken, scattered. Their remnants will linger, but the immediate threat of annihilation has passed. My creators would be proud. As a token of the Ascendants' gratitude, accept this ultimate cache."%_t,
        answers = {{answer = "Thank you, Aegis."%_t, onEnd = "onAcceptStory5"}}
    }}}
    return d0_Hail
end

function CAAegisEnvoy.onAcceptStory5()
    if onClient() then
        invokeServerFunction("onAcceptStory5")
        return
    end

    if data.given["story5" .. callingPlayer] then return end
    data.given["story5" .. callingPlayer] = true

    local player = Player(callingPlayer)
    player:setValue("ca_ready_for_debrief_5", nil)

    -- Rewards (25M, 5 Legendary Turrets, 3 Legendary Systems)
    player:receive("Ascendant Heritage", 25000000)
    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator(Sector().seed)
    for i=1, 5 do
        local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Legendary))
        player:getInventory():add(InventoryTurret(turret))
    end
    for i=1, 3 do player:getInventory():add(UpgradeGenerator():generateSectorSystem(x, y, Rarity(RarityType.Legendary))) end
end

-- Ensure it's globally callable in the namespace
callable(CAAegisEnvoy, "onAcceptIntro")
callable(CAAegisEnvoy, "onAcceptStory1")
callable(CAAegisEnvoy, "onAcceptStory2")
callable(CAAegisEnvoy, "onAcceptStory3")
callable(CAAegisEnvoy, "onAcceptStory4")
callable(CAAegisEnvoy, "onAcceptStory5")
