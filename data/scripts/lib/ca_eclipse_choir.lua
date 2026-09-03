package.path = package.path .. ";data/scripts/lib/?.lua"

-- The Choir: escalating ambient dread, shared by eclipse_awakes.lua (unleashed/fully_awake tiers)
-- and eclipse_conquest_manager.lua (fallen_empire tier) -- two separate script instances with no
-- shared Lua scope, hence this being its own include()-able library rather than a local function
-- duplicated in both files.
--
-- cosmicvaultdialogue.registerLine's `conditions` table only checks a fixed, closed set of keys
-- (minWarHeat/maxWarHeat/factionTrait/factionWealth/stationType/minDistanceToCenter/
-- maxDistanceToCenter/minReputation/maxReputation -- confirmed by reading
-- CosmicVaultDialogue.getValidLine directly); there is no custom-predicate support, so a
-- conditions = {eclipseAwake = true}-style entry would be silently ignored and the line would just
-- always be eligible. The correct way to gate a line on "has the Eclipse reached state X" is to
-- not register it AT ALL until that state is real -- call registerChoirLines(tier) once from each
-- one-shot transition point, never unconditionally at any script's initialize(), so lines
-- literally don't exist in the pool a moment before they're true. minDistanceToCenter is layered
-- in as a real, supported secondary filter -- thematically valid since the mod's own lore has the
-- Eclipse surging outward from the galactic core, so rumors about it are more plausible near there.
local EclipseChoir = {}

function EclipseChoir.registerChoirLines(tier)
    local cv_dialogue = include("cosmicvaultdialogue")
    if not cv_dialogue then return end

    if tier == "unleashed" then
        cv_dialogue.registerLine({
            category = "rumor",
            text = "Something answered the Guardian's death. I don't know what, but it's listening now.",
            conditions = { maxDistanceToCenter = 250 }
        })
        cv_dialogue.registerLine({
            category = "rumor",
            text = "My cousin's crew went quiet near the core last week. Not destroyed. Just... quiet.",
            conditions = { maxDistanceToCenter = 250 }
        })
    elseif tier == "fully_awake" then
        cv_dialogue.registerLine({
            category = "rumor",
            text = "They don't broadcast. They don't negotiate. Whatever's out there, it doesn't want anything from us except gone.",
            conditions = { }
        })
        cv_dialogue.registerLine({
            category = "rumor",
            text = "I've stopped flying solo. I don't care how much it cuts into the haul.",
            conditions = { }
        })
    elseif tier == "fallen_empire" then
        cv_dialogue.registerLine({
            category = "rumor",
            text = "It's not raiding anymore. It's counting. Sectors, ships, us. It's counting.",
            conditions = { }
        })
        cv_dialogue.registerLine({
            category = "rumor",
            text = "Whatever the Eclipse used to be, it isn't improvising anymore. This is a campaign now.",
            conditions = { }
        })
    end
end

return EclipseChoir
