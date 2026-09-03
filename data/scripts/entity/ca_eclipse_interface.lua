package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")

-- The Eclipse: Command Interface -- a standalone Player UI window opened by interacting
-- with your own ship, following the exact same pattern already proven in Cosmic Overhaul's
-- TrashMan.lua/fleetstatus.lua (interactionPossible/getIcon/initUI, attached via
-- data/scripts/entity/init.lua). Reads the same EclipseStatus.getSnapshot() function
-- /eclipsestatus uses -- one source of truth for both surfaces.

-- namespace CAEclipseInterface
CAEclipseInterface = {}

function CAEclipseInterface.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local craft = player.craft
    if craft == nil then return false end
    return craft.index == Entity().index
end

function CAEclipseInterface.getIcon()
    return "data/textures/icons/EclipseInterface.png"
end

local labels = {}
local bars = {}

function CAEclipseInterface.initUI()
    local res = getResolution()
    local size = vec2(700, 560)
    local menu = ScriptUI()
    CAEclipseInterface.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    CAEclipseInterface.window.caption = "The Eclipse: Command Interface"%_t
    CAEclipseInterface.window.showCloseButton = 1
    CAEclipseInterface.window.moveable = 1
    menu:registerWindow(CAEclipseInterface.window, "Eclipse Interface"%_t)

    local tabs = CAEclipseInterface.window:createTabbedWindow(Rect(vec2(0, 0), CAEclipseInterface.window.size))

    local overview = tabs:createTab("Overview"%_t, "", "General awakening status and expansion threat"%_t)
    local territory = tabs:createTab("Territory"%_t, "", "Holdings, Fallen Empire, Crusades, Suppression and Grace windows"%_t)
    local threats = tabs:createTab("Threats"%_t, "", "Remnant Escalation, Nemesis and the Silent Choir"%_t)
    local personal = tabs:createTab("Personal"%_t, "", "Your own standing with The Eclipse"%_t)

    -- Overview
    labels.status = overview:createLabel(vec2(15, 20), "Loading..."%_t, 16)
    overview:createLabel(vec2(15, 60), "Expansion Threat:"%_t, 14)
    bars.threat = overview:createProgressBar(Rect(15, 85, 400, 105), ColorRGB(0.7, 0.1, 0.1))
    labels.threatPct = overview:createLabel(vec2(410, 85), "--", 14)
    labels.summary = overview:createLabel(vec2(15, 130), "", 13)

    -- Territory
    labels.holdings = territory:createLabel(vec2(15, 20), "", 14)
    labels.fallenEmpire = territory:createLabel(vec2(15, 50), "", 14)
    labels.lastCrusade = territory:createLabel(vec2(15, 80), "", 13)
    territory:createFrame(Rect(15, 110, 685, 112))
    territory:createLabel(vec2(15, 120), "Citadel Suppression Field:"%_t, 14)
    labels.suppression = territory:createLabel(vec2(15, 145), "", 13)
    territory:createLabel(vec2(15, 180), "World-Eater Grace Period:"%_t, 14)
    labels.grace = territory:createLabel(vec2(15, 205), "", 13)

    -- Threats
    labels.remnant = threats:createLabel(vec2(15, 20), "", 14)
    labels.killCounts = threats:createLabel(vec2(15, 50), "", 13)
    threats:createFrame(Rect(15, 80, 685, 82))
    labels.nemesis = threats:createLabel(vec2(15, 95), "", 14)
    labels.silentChoir = threats:createLabel(vec2(15, 130), "", 14)

    -- Personal
    labels.killScore = personal:createLabel(vec2(15, 20), "", 14)
    labels.ward = personal:createLabel(vec2(15, 50), "", 14)

    CAEclipseInterface.requestRefresh()
end

function CAEclipseInterface.getUpdateInterval()
    return 5.0
end

-- Only re-requests a fresh snapshot while the window is actually open, rather than polling
-- continuously for as long as the player is in their ship -- fleetstatus.lua's own HUD overlay
-- needs a constant tick for a different reason (live rendering), but a status dashboard closed
-- most of the time shouldn't generate server/client traffic while nobody's looking at it.
function CAEclipseInterface.updateClient(timeStep)
    if CAEclipseInterface.window and CAEclipseInterface.window.visible then
        CAEclipseInterface.requestRefresh()
    end
end

function CAEclipseInterface.requestRefresh()
    if onServer() then return end
    invokeServerFunction("provideSnapshot")
end

function CAEclipseInterface.provideSnapshot()
    if not onServer() then return end
    local EclipseStatus = include("ca_eclipse_status")
    local player = Player(callingPlayer)
    if not player then return end
    invokeClientFunction(player, "receiveSnapshot", EclipseStatus.getSnapshot(player))
end
callable(CAEclipseInterface, "provideSnapshot")

function CAEclipseInterface.receiveSnapshot(snap)
    if not snap or not labels.status then return end
    local EclipseStatus = include("ca_eclipse_status")

    if not snap.fullyAwake then
        if snap.unleashed then
            labels.status.caption = "The Eclipse has been unleashed and is awakening."%_t
        else
            labels.status.caption = "The Eclipse has not yet been disturbed."%_t
        end
        labels.summary.caption = ""
        bars.threat.progress = 0
        labels.threatPct.caption = "--"
        labels.holdings.caption = ""
        labels.fallenEmpire.caption = ""
        labels.lastCrusade.caption = ""
        labels.suppression.caption = ""
        labels.grace.caption = ""
        labels.remnant.caption = ""
        labels.killCounts.caption = ""
        labels.nemesis.caption = ""
        labels.silentChoir.caption = ""
    else
        labels.status.caption = "The Eclipse is fully awake."%_t
        bars.threat.progress = snap.threatPercent / 100.0
        labels.threatPct.caption = snap.threatPercent .. "%"
        labels.summary.caption = string.format("%d sector(s) conquered or annihilated so far.", snap.conqueredSectors)

        labels.holdings.caption = string.format("Eclipse Holdings: %d sector(s)", snap.conqueredSectors)
        if snap.fallenEmpire then
            labels.fallenEmpire.caption = "Fallen Empire: ACTIVE"%_t
            if snap.lastCrusade then
                local hours, mins = EclipseStatus.formatDuration(snap.lastCrusade.secondsAgo)
                local kindText = (snap.lastCrusade.kind == "player") and "a player/alliance sector"%_t or "an AI faction capital"%_t
                labels.lastCrusade.caption = string.format("Last Crusade: (%d:%d), %s, %dh %dm ago", snap.lastCrusade.x, snap.lastCrusade.y, kindText, hours, mins)
            else
                labels.lastCrusade.caption = ""
            end
        else
            labels.fallenEmpire.caption = string.format("Fallen Empire: INACTIVE (%d/75)", snap.conqueredSectors)
            labels.lastCrusade.caption = ""
        end

        if snap.citadelSuppressed then
            local hours, mins = EclipseStatus.formatDuration(snap.citadelSuppressionRemaining)
            labels.suppression.caption = string.format("ACTIVE -- %dh %dm remaining", hours, mins)
        else
            labels.suppression.caption = "INACTIVE"%_t
        end

        if snap.worldEaterGraceActive then
            local hours, mins = EclipseStatus.formatDuration(snap.worldEaterGraceRemaining)
            labels.grace.caption = string.format("ACTIVE -- %dh %dm remaining", hours, mins)
        else
            labels.grace.caption = "INACTIVE"%_t
        end

        if snap.remnantTier > 0 then
            labels.remnant.caption = "Remnant Escalation: TIER " .. snap.remnantTier
        else
            labels.remnant.caption = "Remnant Escalation: TIER 0"%_t
        end
        labels.killCounts.caption = string.format("Confirmed kills: %d World-Eater(s), %d Citadel(s)", snap.worldEatersKilled, snap.citadelsKilled)

        if snap.nemesisHunt then
            labels.nemesis.caption = string.format("Nemesis Signature: DETECTED near (%d:%d)", snap.nemesisHunt.x, snap.nemesisHunt.y)
        else
            labels.nemesis.caption = "Nemesis Signature: NONE"%_t
        end

        if snap.silentChoir then
            labels.silentChoir.caption = string.format("The Silent Choir: SIGHTED near (%d:%d) -- %d encounter(s)", snap.silentChoir.lastX or 0, snap.silentChoir.lastY or 0, snap.silentChoir.encounters or 0)
        else
            labels.silentChoir.caption = "The Silent Choir: UNKNOWN"%_t
        end
    end

    labels.killScore.caption = "Eclipse Kill Score: " .. (snap.killScore or 0)
    if snap.wardActive then
        local hours, mins = EclipseStatus.formatDuration(snap.wardRemaining)
        labels.ward.caption = string.format("Ascendant Ward: ACTIVE -- %dh %dm remaining", hours, mins)
    else
        labels.ward.caption = "Ascendant Ward: INACTIVE"%_t
    end
end
