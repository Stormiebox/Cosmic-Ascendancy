package.path = package.path .. ";data/scripts/lib/?.lua"

local cv_news = include("cosmicvaultnews")
include("goods")

function initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed()
    if not onServer() then return end

    local sector = Sector()
    local entity = Entity()
    local pos = entity.translationf
    local citadelX, citadelY = sector:getCoordinates()

    -- Suppression Field: Halt all invasions globally for 6 hours
    Server():setValue("eclipse_citadel_destroyed_time", Server().unpausedRuntime)
    Sector():broadcastChatMessage("Eclipse Citadel", 2, "The Citadel's destruction has generated a massive suppression field. Eclipse invasions halted.")

    -- Eclipse Remnant Escalation: this script is unconditionally attached to every Citadel by
    -- EclipseGenerator.createStation(), so this fires on every real Citadel kill regardless of
    -- source (invasions, story missions, Dark Sectors).
    Server():setValue("eclipse_citadels_killed", (Server():getValue("eclipse_citadels_killed") or 0) + 1)
    local EclipseGenerator = include("eclipsegenerator")
    EclipseGenerator.checkRemnantEscalation()

    -- Push-back: destroying a Citadel is the mod's flagship "fight back" moment, so beyond pausing
    -- the invasion timer above, it should also visibly roll the Eclipse's frontier back. Liberate the
    -- Citadel's own sector plus any held territory within a 15-sector radius of it (matching the
    -- WIKI's documented Citadel suppression radius) and reduce the conquered-sector counter to match.
    local LIBERATION_RADIUS = 15
    local territoryString = Server():getValue("eclipse_held_territory") or ""
    local liberated = 0
    local kept = ""
    for entryX, entryY in string.gmatch(territoryString, "(%-?%d+)_(%-?%d+),") do
        local ex, ey = tonumber(entryX), tonumber(entryY)
        local dx, dy = ex - citadelX, ey - citadelY
        if math.sqrt(dx * dx + dy * dy) <= LIBERATION_RADIUS then
            liberated = liberated + 1
        else
            kept = kept .. ex .. "_" .. ey .. ","
        end
    end

    if liberated > 0 then
        Server():setValue("eclipse_held_territory", kept)
        local conqueredCount = Server():getValue("eclipse_conquered_sectors") or 0
        Server():setValue("eclipse_conquered_sectors", math.max(0, conqueredCount - liberated))
        Sector():broadcastChatMessage("Galactic News", 0, "The Citadel's fall has liberated " .. liberated .. " nearby sector(s) from Eclipse control!")
        if cv_news.publishArticle then
            cv_news.publishArticle({
                title = "Sectors Liberated From The Eclipse!",
                content = "In the wake of an Eclipse Citadel's destruction, " .. liberated .. " nearby sector(s) have been reclaimed from Eclipse control. The frontier has been pushed back, for now.",
                category = "Heroic Victories"
            })
        end
    end

    -- Ascendant Matter massive drop
    local matterAmount = random():getInt(100, 250)
    sector:dropCargo(pos, nil, nil, goods["Ascendant Matter"], 0, matterAmount)
    
    -- Eclipse Datacore drop
    local coreAmount = random():getInt(3, 5)
    for i = 1, coreAmount do
        sector:dropCargo(pos, nil, nil, goods["Eclipse Datacore"], 0, 1)
    end
    
    -- Legendary Weapons and Upgrades
    local SectorTurretGenerator = include("sectorturretgenerator")
    local UpgradeGenerator = include("upgradegenerator")
    local ugen = UpgradeGenerator()
    local tgen = SectorTurretGenerator(sector.seed)

    for i = 1, random():getInt(8, 12) do
        local turret = tgen:generateArmed(citadelX, citadelY, 0, Rarity(RarityType.Legendary))
        if turret then
            -- tech level scales natively with citadelX, citadelY
            sector:dropTurret(pos, nil, nil, turret)
        end
    end

    for i = 1, random():getInt(8, 12) do
        local upgrade = ugen:generateSectorSystem(citadelX, citadelY, Rarity(RarityType.Legendary))
        if upgrade then
            sector:dropUpgrade(pos, nil, nil, upgrade)
        end
    end
end
