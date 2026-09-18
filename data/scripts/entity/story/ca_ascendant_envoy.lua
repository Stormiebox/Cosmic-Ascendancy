package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CAAegisEnvoy
CAAegisEnvoy = {}

CAAegisEnvoy = include("npcapi/singleinteraction")
include("stringutility")
include("data/scripts/lib/callable")
local CosmicVaultData = include("cosmicvaultdata")

local data = CAAegisEnvoy.data

data.given = {}
data.hail = false
data.closeableDialog = false
data.globalInteractionKey = "ca_aegis_envoy"

local CONTROLLER = "data/scripts/player/background/ca_campaign_controller.lua"

local function campaignSnapshot(player)
    local snapshot = CosmicVaultData.GetRecord(player, "ca_campaign_v2", 2)
    return snapshot
end

local function acceptDebrief(chapter, key)
    if onClient() then
        invokeServerFunction(key)
        return
    end

    local guardKey = key .. tostring(callingPlayer)
    if data.given[guardKey] then return end
    data.given[guardKey] = true

    local player = Player(callingPlayer)
    if not player then
        data.given[guardKey] = nil
        return
    end

    local snapshot = campaignSnapshot(player)
    if not snapshot or snapshot.chapter ~= chapter or snapshot.phase ~= "debrief_pending" then
        data.given[guardKey] = nil
        return
    end

    local resultCode, completed = player:invokeFunction(
        CONTROLLER, "acceptDebrief", chapter, snapshot.revision, callingPlayer)
    if resultCode ~= 0 or not completed then
        data.given[guardKey] = nil
    end
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
    local snapshot = campaignSnapshot(Player())
    if not snapshot or snapshot.phase ~= "debrief_pending" then
        return CAAegisEnvoy.makeDialogFallback()
    end

    if snapshot.chapter == 5 then return CAAegisEnvoy.makeDialogStory5() end
    if snapshot.chapter == 4 then return CAAegisEnvoy.makeDialogStory4() end
    if snapshot.chapter == 3 then return CAAegisEnvoy.makeDialogStory3() end
    if snapshot.chapter == 2 then return CAAegisEnvoy.makeDialogStory2() end
    if snapshot.chapter == 1 then return CAAegisEnvoy.makeDialogStory1() end
    if snapshot.chapter == 0 then return CAAegisEnvoy.makeDialogIntro() end
    return CAAegisEnvoy.makeDialogFallback()
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
    acceptDebrief(0, "onAcceptIntro")
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
    acceptDebrief(1, "onAcceptStory1")
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
    acceptDebrief(2, "onAcceptStory2")
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
    acceptDebrief(3, "onAcceptStory3")
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
    acceptDebrief(4, "onAcceptStory4")
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
    acceptDebrief(5, "onAcceptStory5")
end

-- Ensure it's globally callable in the namespace
callable(CAAegisEnvoy, "onAcceptIntro")
callable(CAAegisEnvoy, "onAcceptStory1")
callable(CAAegisEnvoy, "onAcceptStory2")
callable(CAAegisEnvoy, "onAcceptStory3")
callable(CAAegisEnvoy, "onAcceptStory4")
callable(CAAegisEnvoy, "onAcceptStory5")
