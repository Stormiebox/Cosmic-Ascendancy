local VaultNews = include("cosmicvaultnews")
local NewsSchema = include("cosmicvaultnews_schema")

local CosmicAscendancyNews = {}

local PUBLISHER = {
    schemaVersion = 1,
    publisherId = "cosmic_ascendancy",
    displayName = "Cosmic Ascendancy",
    shortName = "ASC",
    color = {r = 0.72, g = 0.45, b = 1.0},
}

local KINDS = {
    encounter = true,
    territory = true,
    beacon = true,
    escalation = true,
    anomaly = true,
}

local MUTABLE_FIELDS = {
    "title", "content", "category", "topic", "severity", "breaking", "author",
    "location", "audience", "lead", "expiresAt", "provenance",
}

local function stableId(kind, rawIdentity)
    if type(kind) ~= "string" or not KINDS[kind] or rawIdentity == nil then
        return nil, "invalid_arguments"
    end
    local hash, hashError = NewsSchema.StableHash(tostring(rawIdentity))
    if hashError then return nil, hashError end
    return "ascendancy-" .. kind .. ":" .. hash, nil
end

local function stableThreadId(rawIdentity)
    if rawIdentity == nil then return nil, nil end
    local hash, hashError = NewsSchema.StableHash(tostring(rawIdentity))
    if hashError then return nil, hashError end
    return "ascendancy-thread:" .. hash, nil
end

local function equivalent(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do
        if not equivalent(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function buildRequest(options)
    if type(options) ~= "table" or type(options.article) ~= "table"
            or type(options.kind) ~= "string" or not KINDS[options.kind]
            or options.eventId == nil or type(options.eventType) ~= "string" then
        return nil, "invalid_arguments"
    end

    local eventId, eventError = stableId(options.kind, options.eventId)
    if not eventId then return nil, eventError end
    local threadId
    if options.threadId ~= nil then
        threadId, eventError = stableThreadId(options.threadId)
        if not threadId then return nil, eventError end
    end

    local article = options.article
    local location = options.location
    return {
        schemaVersion = 2,
        publisherId = "cosmic_ascendancy",
        eventId = eventId,
        threadId = threadId,
        eventType = options.eventType,
        topic = options.topic or NewsSchema.MapCategory(article.category or "Galactic Dread"),
        category = article.category or "Galactic Dread",
        severity = options.severity or (article.breaking == true and "critical" or "warning"),
        breaking = article.breaking == true or options.breaking == true,
        title = article.title,
        content = article.content,
        author = article.author or "Cosmic Ascendancy",
        location = location,
        audience = options.audience or {mode = "galaxy"},
        lead = location and {kind = "location", x = location.x, y = location.y,
            expiresAt = options.expiresAt} or nil,
        expiresAt = options.expiresAt,
        provenance = options.provenance or {
            recordType = options.recordType or "ascendancy_state",
            recordId = tostring(options.recordId or options.eventId),
            sourceRevision = options.sourceRevision or 0,
            sourceState = options.sourceState or "verified",
        },
    }, nil
end

local function ensurePublisher()
    local _, registerError = VaultNews.RegisterPublisher(PUBLISHER)
    return registerError == nil and true or nil, registerError
end

function CosmicAscendancyNews.StableId(kind, rawIdentity)
    return stableId(kind, rawIdentity)
end

function CosmicAscendancyNews.Publish(options)
    if not onServer() then return nil, "server_only" end
    local ready, publisherError = ensurePublisher()
    if not ready then return nil, publisherError end
    local request, requestError = buildRequest(options)
    if not request then return nil, requestError end
    return VaultNews.Publish(request)
end

function CosmicAscendancyNews.Upsert(options)
    if not onServer() then return nil, "server_only" end
    local ready, publisherError = ensurePublisher()
    if not ready then return nil, publisherError end
    local request, requestError = buildRequest(options)
    if not request then return nil, requestError end

    local articleId = "cosmic_ascendancy:" .. request.eventId
    local existing, getError = VaultNews.GetArticle(articleId)
    if not existing and getError == "not_found" then return VaultNews.Publish(request) end
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil, false end

    local patch = {}
    local changed = false
    for _, field in ipairs(MUTABLE_FIELDS) do
        patch[field] = request[field]
        if not equivalent(existing[field], request[field]) then changed = true end
    end
    if not changed then return existing, nil, false end
    local updated, updateError = VaultNews.Update(
        articleId, "cosmic_ascendancy", existing.revision, patch)
    return updated, updateError, false
end

function CosmicAscendancyNews.Resolve(kind, rawEventId, outcome, state)
    if not onServer() then return nil, "server_only" end
    local eventId, eventError = stableId(kind, rawEventId)
    if not eventId then return nil, eventError end
    local articleId = "cosmic_ascendancy:" .. eventId
    local existing, getError = VaultNews.GetArticle(articleId)
    if not existing then return nil, getError end
    if existing.state ~= "active" then return existing, nil end
    return VaultNews.Resolve(articleId, "cosmic_ascendancy", existing.revision, {
        state = state or "resolved",
        outcome = outcome,
    })
end

return CosmicAscendancyNews
