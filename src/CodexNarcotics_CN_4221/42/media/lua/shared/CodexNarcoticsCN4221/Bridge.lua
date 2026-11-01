-- Display-only localization. Read the currently installed upstream script by
-- mod ID, so updates keep their original mechanics instead of using a frozen copy.
CodexNarcoticsCN4221 = CodexNarcoticsCN4221 or {}
local M = CodexNarcoticsCN4221
local keys = {
    ["I better stop before I get addicted..."] = "UI_CodexNnCCN_Addict1",
    ["I'm liking this stuff a little too much..."] = "UI_CodexNnCCN_Addict2",
    ["This is getting out of hand..."] = "UI_CodexNnCCN_Addict3",
    ["Maybe I should take a break..."] = "UI_CodexNnCCN_Addict4",
    ["This stuff is highly addictive..."] = "UI_CodexNnCCN_AddictStrong1",
    ["I better be careful with this stuff..."] = "UI_CodexNnCCN_AddictStrong2",
    ["I better be careful not to OD..."] = "UI_CodexNnCCN_Overdose1",
    ["To OD or get eaten by Zombies..."] = "UI_CodexNnCCN_Overdose2",
}

function M.warning(text)
    local key = keys[text]
    if key and getTextOrNull then
        local translated = getTextOrNull(key)
        if type(translated) == "string" and translated ~= "" and translated ~= key then
            return translated
        end
    end
    return text
end

local function replaceExact(source, needle, replacement)
    local pattern = needle:gsub("(%W)", "%%%1")
    local result, count = source:gsub(pattern, function() return replacement end)
    return result, count
end

function M.transform(source, mode)
    local result = source
    if mode == "OnEat" then
        for english in pairs(keys) do
            local literal = '"' .. english .. '"'
            local count
            result, count = replaceExact(result, literal, "CodexNarcoticsCN4221.warning(" .. literal .. ")")
            if count ~= 1 then return source, false end
        end
    elseif mode == "ModSync" then
        local count
        result, count = replaceExact(source, "p:Say(args.text)", "p:Say(CodexNarcoticsCN4221.warning(args.text))")
        if count ~= 1 then return source, false end
    else
        return source, false
    end
    return result, true
end

function M.loadOriginal(relativePath, mode)
    local allowed = {
        OnEat = "media/lua/server/NnC_OnEat.lua",
        ModSync = "media/lua/client/NnC_ModSync.lua",
    }
    if allowed[mode] ~= relativePath then error("NnC CN: unexpected upstream script") end
    -- getModFileReader reads this specific mod's version/common directory directly;
    -- it does not resolve through the overlay file map, avoiding recursive loading.
    local reader = getModFileReader("N&CsNarcotics", relativePath, false)
    if not reader then
        print("[CodexNarcoticsCN4221] Upstream file unavailable: " .. relativePath)
        return
    end
    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    local original = table.concat(lines, "\n") .. "\n"
    local localized, matched = M.transform(original, mode)
    if not matched then
        print("[CodexNarcoticsCN4221] Upstream text changed; loading original: " .. relativePath)
    end
    local ok, chunk = pcall(loadstring, localized, "@NnC_CN/" .. relativePath)
    if not ok or type(chunk) ~= "function" then
        print("[CodexNarcoticsCN4221] Localization compile fallback: " .. relativePath)
        ok, chunk = pcall(loadstring, original, "@NnC_original/" .. relativePath)
    end
    if not ok or type(chunk) ~= "function" then error("NnC CN: upstream script could not compile: " .. relativePath) end
    return chunk()
end

return M
