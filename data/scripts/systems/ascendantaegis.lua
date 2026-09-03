package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
local cv_buffs = include("cosmicvaultbuffs")

function getUpdateInterval()
    return 15
end

function updateServer(timeStep)
    applyDynamicBuffs()
end

-- Keys returned by addMultiplyableBias/addBaseMultiplier below, so removeDynamicBuffs() can strip
-- exactly these two bonuses via removeBonus(key) instead of entity:removeScriptBonuses(), which
-- clears EVERY script-added bonus on the entity -- including unrelated ones another Cosmic mod may
-- have applied to the same ship (e.g. Cosmic Overhaul's captainelitetraits.lua "CommodoreShield"/
-- "CommodoreFireRate" buffs, or Cosmic Starfall's bastionSystem.lua buffs), which the previous
-- blanket call would silently wipe every 15s while this system is installed. Not persisted via
-- secure()/restore() -- these locals start nil on every fresh script load, which is exactly what a
-- volatile bonus key needs (see Avorion_Modding_Codex.md's warning on persisting bonus keys).
local shieldBiasKey = nil
local rechargeBiasKey = nil

function applyDynamicBuffs()
    removeDynamicBuffs()

    local entity = Entity()
    if not entity then return end

    local finalMultiplier = 1.0
    if cv_buffs and type(cv_buffs.getDynamicRelicMultiplier) == "function" then
        finalMultiplier = cv_buffs.getDynamicRelicMultiplier(entity.id)
    end

    -- Both are genuine percentage bonuses (+500%/+300%) -- addBaseMultiplier is the correct
    -- primitive for both (see eclipsegenerator.lua's applyDamageMultiplier for the full writeup of
    -- why addMultiplyableBias is the wrong one here, and Changelog.md's "DPS Scaling Desync"
    -- entries for this exact bug pattern already fixed elsewhere in the mod). This function had the
    -- same bug on its ShieldDurability call while its own ShieldRecharge call right below it was
    -- already correct -- an inconsistency within the same function that's a strong tell this was a
    -- copy-paste-before-the-fix-was-known artifact rather than an intentional difference.
    shieldBiasKey = entity:addBaseMultiplier(StatsBonuses.ShieldDurability, 5.0 * finalMultiplier)
    rechargeBiasKey = entity:addBaseMultiplier(StatsBonuses.ShieldRecharge, 3.0 * finalMultiplier)
end

function removeDynamicBuffs()
    local entity = Entity()
    if not entity then return end
    if shieldBiasKey then entity:removeBonus(shieldBiasKey); shieldBiasKey = nil end
    if rechargeBiasKey then entity:removeBonus(rechargeBiasKey); rechargeBiasKey = nil end
end

function onInstalled(seed, rarity, permanent)
    if onServer() then applyDynamicBuffs() end
end

function onUninstalled(seed, rarity, permanent)
    if onServer() then removeDynamicBuffs() end
end

local base_secure = secure
function secure()
    local data = {}
    if base_secure then data = base_secure() or {} end
    return data
end

local base_restore = restore
function restore(data)
    if base_restore then base_restore(data) end
end

function getName(seed, rarity)
    return "Ascendant Aegis Matrix"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/AscendantAegis.png"
end

function getEnergy(seed, rarity)
    return 0
end

function getPrice(seed, rarity)
    return 1000000000
end

function getTooltipLines(seed, rarity, permanent)
    local texts = {}
    table.insert(texts, {ltext = "Base Shield Durability"%_t, rtext = "+500%", icon = "data/textures/icons/health-normal.png", boosted = false})
    table.insert(texts, {ltext = "Base Shield Recharge"%_t, rtext = "+300%", icon = "data/textures/icons/health-normal.png", boosted = false})

    table.insert(texts, {ltext = "", rtext = "", icon = ""})
    table.insert(texts, {ltext = "\\c(e44)LIVING RELIC\\c()"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Stats multiply based on"%_t, rtext = "", icon = ""})
    table.insert(texts, {ltext = "Core Proximity & War Heat!"%_t, rtext = "", icon = ""})

    return texts
end
