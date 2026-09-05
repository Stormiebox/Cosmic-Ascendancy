package.path = package.path .. ";data/scripts/lib/?.lua"

-- Required before any %_T/%_t usage below: stringutility.lua's top level installs the __mod
-- metamethod on the string metatable that routes "..."%_T/%_t through translation at all.
include("stringutility")

local EclipseStatus = include("ca_eclipse_status")

function execute(sender, commandName, ...)
    local server = Server()
    local player = Player(sender)
    if not player then return 0, "", "" end

    local snap = EclipseStatus.getSnapshot(player)

    if not snap.fullyAwake then
        -- "The Eclipse has not yet awakened" used to fire identically whether the Guardian-kill
        -- trigger had NEVER fired at all, or had fired and was mid-countdown -- the single most
        -- unhelpful moment for this command to be ambiguous, since a player checking specifically
        -- because they're worried nothing happened gets no way to tell "still counting down, wait"
        -- apart from "genuinely stuck, something is wrong." snap.unleashed (set the instant ANY
        -- player's kill is first detected, well before fullyAwake) distinguishes them.
        if snap.unleashed then
            local progress = "The Eclipse has been unleashed and is awakening."%_T
            if snap.warning2 then
                progress = "The Eclipse has been unleashed and is in the final minutes of awakening."%_T
            elseif snap.warning1 then
                progress = "The Eclipse has been unleashed and is well into its awakening."%_T
            end
            player:sendChatMessage("Server"%_T, 0, progress .. " This resolves automatically -- no action needed."%_T)
        else
            player:sendChatMessage("Server"%_T, 0, "The Eclipse has not yet been disturbed. Nothing has triggered its awakening on this server."%_T)
        end
        return 0, "", ""
    end

    local msg = "=== The Eclipse: Global Status ===\n\n"

    if snap.citadelSuppressed then
        local hours, mins = EclipseStatus.formatDuration(snap.citadelSuppressionRemaining)
        msg = msg .. "[Citadel Suppression Field]: ACTIVE\n"
        msg = msg .. string.format("Eclipse invasions are halted for another %d hour(s) and %d minute(s).\n\n", hours, mins)
    else
        msg = msg .. "[Citadel Suppression Field]: INACTIVE\n"
        msg = msg .. "The Eclipse is currently free to launch invasions.\n\n"
    end

    if snap.worldEaterGraceActive then
        local hours, mins = EclipseStatus.formatDuration(snap.worldEaterGraceRemaining)
        msg = msg .. "[World-Eater Grace Period]: ACTIVE\n"
        msg = msg .. string.format("The Doomsday clock is paused for another %d hour(s) and %d minute(s).\n\n", hours, mins)
    else
        msg = msg .. "[World-Eater Grace Period]: INACTIVE\n"
        msg = msg .. "The Eclipse is actively constructing the next World-Eater.\n\n"
    end

    msg = msg .. "[Eclipse Holdings]: " .. snap.conqueredSectors .. " sector(s) conquered or annihilated.\n"
    msg = msg .. "[Expansion Threat]: " .. snap.threatPercent .. "% toward the next expansion attempt.\n\n"

    if snap.fallenEmpire then
        msg = msg .. "[Fallen Empire]: ACTIVE\n"
        msg = msg .. "The Eclipse has consolidated into a unified empire and now launches deliberate Crusades.\n"

        if snap.lastCrusade then
            local hours, mins = EclipseStatus.formatDuration(snap.lastCrusade.secondsAgo)
            local kindText = (snap.lastCrusade.kind == "player") and "a player/alliance sector" or "an AI faction capital"
            msg = msg .. string.format("Last Crusade target: (%d:%d), %s, %d hour(s) and %d minute(s) ago.\n\n", snap.lastCrusade.x, snap.lastCrusade.y, kindText, hours, mins)
        else
            msg = msg .. "\n"
        end
    else
        msg = msg .. "[Fallen Empire]: INACTIVE (" .. snap.conqueredSectors .. "/75 sectors)\n\n"
    end

    if snap.nemesisHunt then
        msg = msg .. "[Nemesis Signature]: DETECTED\n"
        msg = msg .. string.format("A wounded Eclipse Dread-Lord was last tracked to sector (%d:%d).\n\n", snap.nemesisHunt.x, snap.nemesisHunt.y)
    else
        msg = msg .. "[Nemesis Signature]: NONE\n"
        msg = msg .. "No Eclipse Dread-Lord is currently known to be fleeing at reduced strength.\n\n"
    end

    if snap.remnantTier > 0 then
        msg = msg .. "[Remnant Escalation]: TIER " .. snap.remnantTier .. "\n"
        msg = msg .. "Surviving Eclipse World-Eaters and Citadels are measurably stronger and more frequent as a result.\n"
    else
        msg = msg .. "[Remnant Escalation]: TIER 0\n"
    end
    msg = msg .. string.format("Confirmed kills: %d World-Eater(s), %d Citadel(s).\n\n", snap.worldEatersKilled, snap.citadelsKilled)

    if snap.silentChoir then
        msg = msg .. "[The Silent Choir]: SIGHTED\n"
        msg = msg .. string.format("A presence was last sighted near sector (%d:%d) -- %d encounter(s) so far.\n\n", snap.silentChoir.lastX or 0, snap.silentChoir.lastY or 0, snap.silentChoir.encounters or 0)
    else
        msg = msg .. "[The Silent Choir]: UNKNOWN\n"
        msg = msg .. "Nothing has been sighted. That is not the same as nothing being there.\n\n"
    end

    msg = msg .. "[Your Eclipse Kill Score]: " .. snap.killScore .. "\n"
    if snap.wardActive then
        local hours, mins = EclipseStatus.formatDuration(snap.wardRemaining)
        msg = msg .. string.format("[Ascendant Ward]: ACTIVE (%d hour(s) %d minute(s) remaining)\n", hours, mins)
    else
        msg = msg .. "[Ascendant Ward]: INACTIVE\n"
    end

    player:sendChatMessage("Server"%_T, 0, msg)
    return 0, "", ""
end

function getDescription()
    return "Checks the current status of The Eclipse, including territory, threat, Fallen Empire crusades, any tracked Nemesis, Remnant Escalation, and your own standing with it."
end

function getHelp()
    return "Usage: /eclipsestatus\nDisplays the Eclipse's current holdings, expansion threat, Citadel Suppression Field and World-Eater Grace Period cooldowns, Fallen Empire Crusade status, any currently tracked wounded Nemesis or Silent Choir sighting, the current Remnant Escalation Tier, and your personal kill score and Ward status."
end
