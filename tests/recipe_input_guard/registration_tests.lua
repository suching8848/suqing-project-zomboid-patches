-- From the repository root:
-- dofile("tests/recipe_input_guard/registration_tests.lua").run()
-- Pass run(loadRegistry) when a runner loads source without dofile support.
local function run(loadRegistry)
    loadRegistry = loadRegistry or function()
        return dofile("src/SuQingRecipeInputGuard_4221/42/media/registries.lua")
    end

    local saved = {
        ResourceLocation = ResourceLocation,
        ItemTag = ItemTag,
        SuQingRecipeInputGuard = SuQingRecipeInputGuard,
        print = print,
    }
    local TAG_ID = "sapphcooking:strawberry"
    local passed = 0

    local function fixture()
        local f = { tags = {}, logs = {}, registrations = 0, lookups = 0 }
        local function idOf(value)
            if type(value) == "table" then return value.id end
            return value
        end

        ResourceLocation = {
            of = function(id)
                assert(type(id) == "string", "ResourceLocation.of expects a string")
                return setmetatable({ id = id }, { __tostring = function(value) return value.id end })
            end,
        }
        ItemTag = {
            get = function(location)
                f.lookups = f.lookups + 1
                return f.tags[idOf(location)]
            end,
            register = function(location)
                local id = idOf(location)
                f.registrations = f.registrations + 1
                assert(not f.tags[id], "attempted to register an existing tag")
                if f.registrationError == "before" then
                    f.failureReached = "before"
                    error("fixture registration failure")
                end
                local tag = { id = id, owner = "registered in fixture" }
                f.tags[id] = tag
                if f.registrationError == "after" then
                    f.failureReached = "after"
                    error("fixture failure after publishing tag")
                end
                return tag
            end,
        }
        SuQingRecipeInputGuard = nil
        print = function(...)
            local values = {}
            for i = 1, select("#", ...) do values[i] = tostring(select(i, ...)) end
            f.logs[#f.logs + 1] = table.concat(values, " ")
        end
        return f
    end

    local function hasErrorLog(f)
        local diagnostic = SuQingRecipeInputGuard.error
        if type(diagnostic) ~= "string" or diagnostic == "" then return false end
        -- Kahlua can wrap a Lua mock's exception in a Java diagnostic. Check
        -- that the complete diagnostic actually captured by production is
        -- logged, rather than requiring Lua 5.1's exception formatting.
        local expected = "[SuQingRecipeInputGuard] ERROR: early registration failed: " .. diagnostic
        for _, line in ipairs(f.logs) do
            if line == expected then return true end
        end
        return false
    end

    local function assertIds(actual, expected)
        assert(#actual == #expected, "unexpected candidate count: " .. tostring(#actual))
        for i, id in ipairs(expected) do
            assert(actual[i] == id, "candidate " .. tostring(i) .. " differs: " .. tostring(actual[i]))
        end
    end

    local function test(name, callback)
        callback()
        passed = passed + 1
        saved.print("PASS recipe registration: " .. name)
    end

    local ok, err = pcall(function()
        test("missing strawberry tag is registered once", function()
            local f = fixture()
            loadRegistry()
            assert(f.registrations == 1)
            assert(f.lookups >= 1)
            assert(SuQingRecipeInputGuard.VERSION == "1.0.0")
            assert(SuQingRecipeInputGuard.tagId == TAG_ID)
            assert(SuQingRecipeInputGuard.tag == f.tags[TAG_ID])
            assert(SuQingRecipeInputGuard.registration == "registered")

            local tag = f.tags[TAG_ID]
            loadRegistry()
            assert(f.registrations == 1, "loading twice registered the same tag twice")
            assert(f.tags[TAG_ID] == tag and SuQingRecipeInputGuard.tag == tag)
        end)

        test("an existing upstream tag is reused without mutation", function()
            local f = fixture()
            local existing = { id = TAG_ID, owner = "upstream", marker = {} }
            local other = { id = "base:other", owner = "unrelated" }
            f.tags[TAG_ID] = existing
            f.tags[other.id] = other
            loadRegistry()
            assert(f.registrations == 0)
            assert(SuQingRecipeInputGuard.tag == existing)
            assert(SuQingRecipeInputGuard.registration == "existing")
            assert(existing.owner == "upstream" and existing.marker ~= nil)
            assert(f.tags[other.id] == other and other.owner == "unrelated")
            loadRegistry()
            assert(f.registrations == 0 and f.tags[TAG_ID] == existing)
        end)

        test("native null-tag collision is removed during a fresh script parse", function()
            local f = fixture()
            local NULL_TAG = {}
            local definitions = {
                { id = "Base.Strewberrie", tag = TAG_ID, kind = "food" },
                { id = "SapphCooking.Syrup_Strawberry", tag = TAG_ID, kind = "food" },
                { id = "Fixture.TacticalJKTop", tag = "fixture:unregisteredJacketTag", kind = "clothing" },
                { id = "Fixture.EmptyCartridge", tag = "fixture:unregisteredCartridgeTag", kind = "normal" },
                { id = "Fixture.UnrelatedTool", tag = "fixture:registeredToolTag", kind = "normal" },
            }
            local toolTag = { id = "fixture:registeredToolTag" }
            f.tags[toolTag.id] = toolTag
            local function parseItems()
                local items = {}
                for _, definition in ipairs(definitions) do
                    items[#items + 1] = {
                        id = definition.id,
                        kind = definition.kind,
                        parsedTag = f.tags[definition.tag] or NULL_TAG,
                    }
                end
                return items
            end
            local function matching(items, tagId)
                local inputTag = f.tags[tagId] or NULL_TAG
                local result = {}
                for _, item in ipairs(items) do
                    if item.parsedTag == inputTag then result[#result + 1] = item.id end
                end
                return result
            end

            -- Models the engine's null tag entry. This is the negative control:
            -- two unrelated missing tags collide with the missing strawberry tag.
            local before = parseItems()
            assertIds(matching(before, TAG_ID), {
                "Base.Strewberrie", "SapphCooking.Syrup_Strawberry",
                "Fixture.TacticalJKTop", "Fixture.EmptyCartridge",
            })

            -- registries.lua runs BEFORE the native item/recipe script parse;
            -- it does not repair an already parsed cache in place.
            loadRegistry()
            local after = parseItems()
            assertIds(matching(after, TAG_ID), {
                "Base.Strewberrie", "SapphCooking.Syrup_Strawberry",
            })
            assertIds(matching(after, toolTag.id), { "Fixture.UnrelatedTool" })
            assert(#definitions == 5 and #after == 5)
            for i, item in ipairs(after) do
                assert(item.id == definitions[i].id and item.kind == definitions[i].kind)
            end
            assert(after[3].parsedTag == NULL_TAG and after[4].parsedTag == NULL_TAG)
            assert(f.tags[toolTag.id] == toolTag)
        end)

        test("registration failure is logged without retry or unrelated changes", function()
            local f = fixture()
            f.registrationError = "before"
            local other = { id = "base:preserved", marker = {} }
            f.tags[other.id] = other
            loadRegistry()
            assert(f.registrations == 1, "registration failure was retried")
            assert(f.failureReached == "before", "the injected registration failure was not reached")
            assert(f.tags[TAG_ID] == nil)
            assert(f.tags[other.id] == other and other.marker ~= nil)
            assert(SuQingRecipeInputGuard.registration == "registration-failed")
            assert(SuQingRecipeInputGuard.error ~= nil)
            assert(hasErrorLog(f), "registration failure was not logged; captured logs: "
                .. table.concat(f.logs, " | ") .. "; error: " .. tostring(SuQingRecipeInputGuard.error))
        end)

        test("a registration error never clears an already published tag", function()
            local f = fixture()
            f.registrationError = "after"
            loadRegistry()
            assert(f.registrations == 1, "registration failure was retried")
            assert(f.failureReached == "after", "the injected post-publication failure was not reached")
            local published = f.tags[TAG_ID]
            assert(published and published.id == TAG_ID)
            assert(SuQingRecipeInputGuard.registration == "registration-failed")
            assert(hasErrorLog(f), "partial registration failure was not logged; captured logs: "
                .. table.concat(f.logs, " | ") .. "; error: " .. tostring(SuQingRecipeInputGuard.error))

            -- A later independent registry load must discover the existing tag,
            -- never replace or register it again.
            f.registrationError = nil
            loadRegistry()
            assert(f.registrations == 1)
            assert(f.tags[TAG_ID] == published)
            assert(SuQingRecipeInputGuard.tag == published)
        end)
    end)

    ResourceLocation = saved.ResourceLocation
    ItemTag = saved.ItemTag
    SuQingRecipeInputGuard = saved.SuQingRecipeInputGuard
    print = saved.print
    if not ok then error(err, 0) end
    return passed
end

return { run = run }
