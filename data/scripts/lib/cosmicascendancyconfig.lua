package.path = package.path .. ";data/scripts/lib/?.lua"

local ccm = include("ccm")
local config = ccm and ccm.bind("Cosmic_Ascendancy") or nil

CosmicAscendancyConfig = CosmicAscendancyConfig or {}

if ccm then
    ccm.register("Cosmic_Ascendancy", {
        pages = {
            {
                title = "Dynamic Expansion",
                options = {
                    { key = "enableExpansion", type = "bool", title = "Enable Dynamic Expansion", description = "Allows AI Factions and Pirates to naturally expand their territory into unexplored sectors.", default = true },
                    { key = "expansionInterval", type = "number", title = "Expansion Interval (min)", description = "WARNING: Modifies server workload! How often the server attempts an expansion roll. Lower numbers mean faster galaxy filling but more frequent background sector loading.", default = 20, min = 10, max = 180 },
                    { key = "expansionChance", type = "number", title = "Expansion Chance (%)", description = "Percent chance an expansion roll succeeds every interval.", default = 25, min = 1, max = 100 },
                    { key = "allowPirateExpansion", type = "bool", title = "Allow Pirate Expansion", description = "If true, local Pirate factions will slowly establish hidden bases and smuggling outposts in empty space.", default = true },
                },
            },
        },
    })
end

local defaults =
{
    enableExpansion = true,
    expansionInterval = 20,
    expansionChance = 25,
    allowPirateExpansion = true,
}

local function clampNumber(v, minV, maxV, fallback)
    if type(v) ~= "number" then return fallback end
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function readNumber(key, minV, maxV, fallback)
    if not config then return fallback end
    local value = config.get(key)
    return clampNumber(value, minV, maxV, fallback)
end

local function readBool(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if value == nil then return fallback end
    if type(value) == "boolean" then return value end
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" then return true end
        if lower == "false" or lower == "0" then return false end
    end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    return fallback
end

local function build()
    local out = {}

    out.enableExpansion = readBool("enableExpansion", defaults.enableExpansion)
    out.expansionInterval = readNumber("expansionInterval", 10, 180, defaults.expansionInterval)
    out.expansionChance = readNumber("expansionChance", 1, 100, defaults.expansionChance)
    out.allowPirateExpansion = readBool("allowPirateExpansion", defaults.allowPirateExpansion)

    return out
end

function CosmicAscendancyConfig.get()
    return build()
end

return CosmicAscendancyConfig
