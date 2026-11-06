CodexChinaBrewingBooks50 = CodexChinaBrewingBooks50 or {}
local B = CodexChinaBrewingBooks50

B.VERSION = "0.1.1"
B.MOD_DATA_KEY = "CodexChinaBrewingBooks50"
B.MAX_MULTIPLIER = 50
B.BOOKS = {
    { fullType = "Chinesecuisine.BrewingBook12", low = 1, high = 2, pages = 220, original = 3 },
    { fullType = "Chinesecuisine.BrewingBook34", low = 3, high = 4, pages = 260, original = 5 },
    { fullType = "Chinesecuisine.BrewingBook56", low = 5, high = 6, pages = 300, original = 8 },
    { fullType = "Chinesecuisine.BrewingBook78", low = 7, high = 8, pages = 340, original = 12 },
    { fullType = "Chinesecuisine.BrewingBook910", low = 9, high = 10, pages = 380, original = 16 },
}

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function singlePlayer()
    return not (isClient and isClient()) and not (isServer and isServer())
end

local function logOnce(key, message)
    B._logged = B._logged or {}
    if B._logged[key] then return end
    B._logged[key] = true
    print("[CodexChinaBrewingBooks50] " .. message)
end

function B.ProgressMultiplier(pages, totalPages, maximum)
    if not finite(pages) or not finite(totalPages) or totalPages <= 0
        or not finite(maximum) or maximum <= 0 then return nil end
    local percent = math.max(0, math.min(100, pages / totalPages * 100))
    -- Preserve ISReadABook.checkMultiplier's ten-percent steps exactly.
    return math.floor(percent / 10) * (maximum / 10)
end

function B.BookForLevel(level)
    if not finite(level) or level < 0 or level >= 10 then return nil end
    local nextLevel = level + 1
    for _, book in ipairs(B.BOOKS) do
        if book.low <= nextLevel and nextLevel <= book.high then return book end
    end
    return nil
end

local function definition()
    return SkillBook and SkillBook.ChinaBrewing
end

local function describe(value)
    return tostring(value) .. "(" .. type(value) .. ")"
end

function B.ScriptBookMetadata(item)
    if not item then return nil end
    -- Script.Item uses an exclusive upper bound (low + count).
    -- Inventory Literature uses an inclusive bound (low + count - 1).
    local low = item:getLevelSkillTrained()
    local count = item:getNumLevelsTrained()
    return {
        skill = item:getSkillTrained(),
        low = low,
        count = count,
        exclusive = item:getMaxLevelTrained(),
        inclusive = finite(low) and finite(count) and low + count - 1 or nil,
        pages = item:getNumberOfPages(),
    }
end

function B.ValidateDefinitions()
    local entry = definition()
    if not (entry and Perks and Perks.ChinaBrewing and entry.perk == Perks.ChinaBrewing) then
        return false, "ChinaBrewing definition is not ready"
    end
    if not getScriptManager then return false, "script manager unavailable" end
    local manager = getScriptManager()
    if not manager then return false, "script manager unavailable" end
    for index, book in ipairs(B.BOOKS) do
        local maximum = entry["maxMultiplier" .. index]
        if maximum ~= book.original and not (B._configured and maximum == B.MAX_MULTIPLIER) then
            return false, "unexpected ChinaBrewing book maximum at tier " .. index
                .. "; expected=" .. describe(book.original) .. " actual=" .. describe(maximum)
        end
        local actual = B.ScriptBookMetadata(manager:getItem(book.fullType))
        local expectedCount = book.high - book.low + 1
        if not actual then
            return false, "Script.Item missing: " .. book.fullType
        end
        if actual.skill ~= "ChinaBrewing" or actual.low ~= book.low
            or actual.count ~= expectedCount or actual.exclusive ~= book.high + 1
            or actual.inclusive ~= book.high or actual.pages ~= book.pages then
            return false, "Script.Item metadata mismatch: " .. book.fullType
                .. "; skill expected=ChinaBrewing(string) actual=" .. describe(actual.skill)
                .. "; low expected=" .. describe(book.low) .. " actual=" .. describe(actual.low)
                .. "; count expected=" .. describe(expectedCount) .. " actual=" .. describe(actual.count)
                .. "; exclusive expected=" .. describe(book.high + 1) .. " actual=" .. describe(actual.exclusive)
                .. "; inclusive expected=" .. describe(book.high) .. " actual=" .. describe(actual.inclusive)
                .. "; pages expected=" .. describe(book.pages) .. " actual=" .. describe(actual.pages)
        end
    end
    return true
end

function B.Configure()
    if not singlePlayer() or B._restored then return false end
    local ok, reason = B.ValidateDefinitions()
    if not ok then logOnce("definitions", reason); return false end
    local entry = definition()
    for index = 1, 5 do entry["maxMultiplier" .. index] = B.MAX_MULTIPLIER end
    B._configured = true
    return true
end

local function ledger(player, create)
    local data = player:getModData()
    local state = data[B.MOD_DATA_KEY]
    if state ~= nil and (type(state) ~= "table" or state.schema ~= 1) then
        return nil, "unknown saved migration schema"
    end
    if not state and create then
        state = { schema = 1, version = B.VERSION }
        data[B.MOD_DATA_KEY] = state
    end
    return state
end

local function isOwned(state, multiplier)
    return state and state.last and finite(state.last.multiplier)
        and math.abs(state.last.multiplier - multiplier) < 0.0001
end

local function writeMultiplier(player, amount, book)
    if amount > 0 then
        addXpMultiplier(player, Perks.ChinaBrewing, amount, book.low, book.high)
    else
        player:getXp():getMultiplierMap():remove(Perks.ChinaBrewing)
    end
end

function B.PrepareAction(action)
    if not singlePlayer() or not action or not action.item or not action.character then return end
    local item = action.item
    if item:getSkillTrained() ~= "ChinaBrewing" then return end
    local state, reason = ledger(action.character, false)
    if reason then return end
    if state and state.restored then B._restored = true end
    if not B._restored and not B.Configure() then return end
    local entry = definition()
    if not entry then return end
    for index, book in ipairs(B.BOOKS) do
        if item:getFullType() == book.fullType then
            -- Also updates a queued action when RestoreOriginal was called.
            action.maxMultiplier = entry["maxMultiplier" .. index]
            return
        end
    end
end

-- Rebuild only the currently trainable volume from actual character read pages.
-- BookPack has no SkillTrained and is deliberately absent from BOOKS.
function B.Sync(player, readWitness)
    if not singlePlayer() or not player or player:getPlayerNum() ~= 0 then return false end
    local state, stateError = ledger(player, false)
    if stateError then logOnce("schema", stateError); return false end
    if state and state.restored then B._restored = true; return false end
    if not B.Configure() then return false end
    local xp = player:getXp()
    local current = xp:getMultiplier(Perks.ChinaBrewing)
    if not finite(current) then return false end
    local book = B.BookForLevel(player:getPerkLevel(Perks.ChinaBrewing))
    if not book then
        if isOwned(state, current) then
            xp:getMultiplierMap():remove(Perks.ChinaBrewing)
            state.last = nil
        end
        return false
    end
    local pages = player:getAlreadyReadPages(book.fullType)
    local wanted = B.ProgressMultiplier(pages, book.pages, B.MAX_MULTIPLIER)
    if not wanted then return false end
    local owned = isOwned(state, current)
    if wanted <= 0 then
        if owned then writeMultiplier(player, 0, book); state.last = nil end
        return false
    end
    local witness = readWitness and readWitness:getFullType() == book.fullType
    -- Do not overwrite an unrelated custom bonus above the original book cap.
    if not owned and current > book.original and not (witness and current == wanted) then
        logOnce("foreign", "preserved an unowned brewing multiplier; no migration applied")
        return false
    end
    if current ~= wanted then writeMultiplier(player, wanted, book) end
    state = ledger(player, true)
    state.last = { fullType = book.fullType, low = book.low, high = book.high,
        multiplier = wanted, pages = pages, totalPages = book.pages, original = book.original }
    return true
end

-- Call while this mod is enabled, then save/quit before disabling it.
-- Removing an inactive mod cannot run cleanup for a previously saved 50x record.
function B.RestoreOriginal(player)
    if not singlePlayer() or not player or player:getPlayerNum() ~= 0 then return false end
    local state, reason = ledger(player, false)
    if reason then return false, reason end
    local entry = definition()
    if not entry then return false, "ChinaBrewing definition unavailable" end
    for index, book in ipairs(B.BOOKS) do
        local value = entry["maxMultiplier" .. index]
        if value ~= book.original and value ~= B.MAX_MULTIPLIER then
            return false, "book definition changed externally; preserved"
        end
    end
    local current = player:getXp():getMultiplier(Perks.ChinaBrewing)
    local owned = isOwned(state, current)
    if owned then
        local book = B.BookForLevel(player:getPerkLevel(Perks.ChinaBrewing))
        local original = book and B.ProgressMultiplier(player:getAlreadyReadPages(book.fullType), book.pages, book.original) or 0
        writeMultiplier(player, original, book)
    elseif state and state.last and current ~= 0 then
        return false, "brewing multiplier changed externally; preserved"
    end
    for index, book in ipairs(B.BOOKS) do entry["maxMultiplier" .. index] = book.original end
    B._restored = true
    state = ledger(player, true)
    state.restored = true
    state.last = nil
    logOnce("restore", "original brewing book multipliers restored; save/quit before disabling")
    return true
end

function B.Enable(player)
    if not singlePlayer() or not player then return false end
    local state, reason = ledger(player, false)
    if reason then return false, reason end
    if state then state.restored = nil end
    B._restored = false
    return B.Sync(player)
end

return B
