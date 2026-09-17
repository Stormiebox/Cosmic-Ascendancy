package.path = package.path .. ";data/scripts/lib/?.lua"

local EclipseChoir = {}

local PUBLISHER = {
    schemaVersion = 1,
    publisherId = "cosmic_ascendancy",
    displayName = "Cosmic Ascendancy",
    shortName = "ASC",
    color = {r = 0.72, g = 0.45, b = 1.0},
}

local TIERS = {
    awakening = {
        {lineId = "cosmic_ascendancy:eclipse:awakening:monolith-coverup",
            text = "I heard a massive jet-black monolith wiped out an entire sector near the core... but the Galactic News is covering it up."},
        {lineId = "cosmic_ascendancy:eclipse:awakening:forge",
            text = "The Ascendants built a Forge that runs on war and bloodshed. With the Eclipse awake, who knows what they're building in there?"},
        {lineId = "cosmic_ascendancy:eclipse:awakening:eyes",
            text = "Keep your voice down. The Eclipse has eyes everywhere, and they don't leave survivors."},
    },
    unleashed = {
        {lineId = "cosmic_ascendancy:eclipse:unleashed:guardian-answer",
            text = "Something answered the Guardian's death. I don't know what, but it's listening now.",
            conditions = {maxDistanceToCenter = 250}},
        {lineId = "cosmic_ascendancy:eclipse:unleashed:quiet-crew",
            text = "My cousin's crew went quiet near the core last week. Not destroyed. Just... quiet.",
            conditions = {maxDistanceToCenter = 250}},
    },
    fully_awake = {
        {lineId = "cosmic_ascendancy:eclipse:fully-awake:no-negotiation",
            text = "They don't broadcast. They don't negotiate. Whatever's out there, it doesn't want anything from us except gone."},
        {lineId = "cosmic_ascendancy:eclipse:fully-awake:no-solo-flight",
            text = "I've stopped flying solo. I don't care how much it cuts into the haul."},
    },
    fallen_empire = {
        {lineId = "cosmic_ascendancy:eclipse:fallen-empire:counting",
            text = "It's not raiding anymore. It's counting. Sectors, ships, us. It's counting."},
        {lineId = "cosmic_ascendancy:eclipse:fallen-empire:campaign",
            text = "Whatever the Eclipse used to be, it isn't improvising anymore. This is a campaign now."},
    },
}

local function buildEntry(tier, definition)
    return {
        schemaVersion = 2,
        lineId = definition.lineId,
        category = "rumor",
        text = definition.text,
        weight = 1,
        tags = {"ascendancy", "eclipse", tier},
        conditions = definition.conditions or {},
    }
end

function EclipseChoir.registerChoirLines(tier)
    if not onServer() then return nil, "server_only" end
    local definitions = TIERS[tier]
    if not definitions then return nil, "invalid_tier" end
    local dialogue = include("cosmicvaultdialogue")
    if not dialogue then return nil, "manager_unavailable" end
    local _, publisherError = dialogue.RegisterPublisher(PUBLISHER)
    if publisherError then return nil, publisherError end
    local entries = {}
    for _, definition in ipairs(definitions) do
        entries[#entries + 1] = buildEntry(tier, definition)
    end
    return dialogue.RegisterEntries(PUBLISHER.publisherId, entries)
end

function EclipseChoir.getTierEntries(tier)
    local entries = {}
    for _, definition in ipairs(TIERS[tier] or {}) do
        entries[#entries + 1] = buildEntry(tier, definition)
    end
    return entries
end

return EclipseChoir
