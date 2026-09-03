package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- Ascendant Ward: a craftable UsableInventoryItem, granted directly by
-- ascendancyforge.lua's craftWard() (an instant, separate interaction on the Forge window --
-- NOT the 24-hour weapon-forging queue, which has no existing output path for a consumable item
-- and whose type(selectedType) dispatch (string = system upgrade / special sentinel, number =
-- turret) isn't set up to add a third kind of output without risking the existing branches).
--
-- Scoping honesty (documented here for anyone extending this later): using this suppresses what
-- THIS MOD'S OWN scripts check -- EclipseConquestManager's Personal Ambush roll, the Silent
-- Choir's idle-roll target selection, and ca_eclipse_abilities.lua's Void Siphon aura targeting.
-- It does NOT suppress vanilla AI faction hostility in general; a mod script can't safely
-- override that without touching vanilla AI, which is out of scope here.

local WARD_DURATION = 1800 -- 30 minutes

function create(item, rarity)
    item.stackable = true
    item.depleteOnUse = true
    item.name = "Ascendant Ward"%_t
    item.price = 0
    item.icon = "data/textures/icons/AscendantMatter.png"
    item.rarity = rarity

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = TooltipLine(25, 15)
    title.ctext = "Ascendant Ward"%_t
    title.ccolor = rarity.tooltipFontColor
    tooltip:addLine(title)

    tooltip:addLine(TooltipLine(14, 14))

    local desc1 = TooltipLine(18, 14)
    desc1.ltext = "Suppresses The Eclipse's own hunting behavior against you for 30 minutes:"%_t
    tooltip:addLine(desc1)
    local desc2 = TooltipLine(18, 14)
    desc2.ltext = "personal ambushes, the Silent Choir, and Void Siphon targeting."%_t
    tooltip:addLine(desc2)
    local desc3 = TooltipLine(18, 14)
    desc3.ltext = "Does not affect vanilla AI faction hostility."%_t
    tooltip:addLine(desc3)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    if onServer() then
        local player = Player()
        if not player then return false end

        player:setValue("eclipse_ward_until", Server().unpausedRuntime + WARD_DURATION)
        player:sendChatMessage("Ascendant Ward"%_t, 0, "The Ward activates. The Eclipse's attention slides past you -- for now."%_t)
    end

    return true
end
