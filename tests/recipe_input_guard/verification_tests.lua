-- From the repository root:
-- dofile("tests/recipe_input_guard/verification_tests.lua").run()
-- A runner may pass run(loadVerifier) instead of using dofile.
local function run(loadVerifier)
    loadVerifier = loadVerifier or function()
        return dofile("src/SuQingRecipeInputGuard_4221/42/media/lua/client/SuQingRecipeInputGuard.lua")
    end

    local saved = {
        ResourceLocation = ResourceLocation,
        ItemTag = ItemTag,
        SuQingRecipeInputGuard = SuQingRecipeInputGuard,
        getScriptManager = getScriptManager,
        Events = Events,
        print = print,
    }
    local TAG_ID = "sapphcooking:strawberry"
    local RECIPE_ID = "Base.SapphCooking PrepareStrawberryCheesecake"
    local passed = 0

    local function fixture(options)
        options = options or {}
        local NULL = {}
        local f = { mutations = 0, logs = {}, callbacks = {}, useChecks = {} }
        local tag = { id = TAG_ID }
        local foreignTag = { id = "fixture:other" }

        local function list(values)
            local value = { values = values }
            function value:size() return #self.values end
            function value:get(index)
                local entry = self.values[index + 1]
                return entry ~= NULL and entry or nil
            end
            function value:contains(entry)
                if entry == nil then entry = NULL end
                for _, candidate in ipairs(self.values) do if candidate == entry then return true end end
                return false
            end
            local function mutation()
                f.mutations = f.mutations + 1
                error("verifier attempted to mutate a native input list")
            end
            value.clear, value.add, value.remove, value.set = mutation, mutation, mutation, mutation
            return value
        end

        local function item(id, valid)
            local value = { id = id, tags = list({ valid and tag or foreignTag }) }
            function value:getFullName() return self.id end
            function value:getTags() return self.tags end
            return value
        end

        local berry = item("Base.Strewberrie", true)
        local syrup = item("SapphCooking.Syrup_Strawberry", true)
        local candidates = { berry, syrup }
        if options.extraTagged then candidates[#candidates + 1] = item("Fixture.AnotherStrawberry", true) end
        if options.unrelated then candidates[#candidates + 1] = item("Base.SST_JK_clothing", false) end
        if options.missingSyrup then table.remove(candidates, 2) end
        local candidateList = list(candidates)
        local allowed = {}
        for _, candidate in ipairs(candidates) do
            if candidate.tags:contains(tag) then allowed[candidate.id] = true end
        end
        if options.rejectBerry then allowed[berry.id] = false end
        if options.acceptCartridge then allowed["Base.556Bullets"] = true end

        local tags = list(options.nullTag and { tag, NULL } or { tag })
        local target = {
            original = options.original or "  item 5 tags[ sapphcooking:strawberry ],  ",
            quantity = 5,
            tags = tags,
            candidates = candidateList,
        }
        function target:getOriginalLine()
            if options.readError then error("fixture input-read error") end
            return self.original
        end
        function target:getItemTags() return self.tags end
        function target:getPossibleInputItems() return self.candidates end
        function target:canUseItem(id)
            f.useChecks[#f.useChecks + 1] = id
            return allowed[id] == true
        end
        local flour = { original = "item 4 [Base.Flour],", quantity = 4 }
        function flour:getOriginalLine() return self.original end
        local fluid = { original = "item 1 [*],", amount = 0.5, fluid = "CowMilk" }
        function fluid:getOriginalLine() return self.original end
        local inputValues = { flour, target, fluid }
        if options.duplicate then inputValues[#inputValues + 1] = target end
        local inputs = list(inputValues)
        local recipe = { inputs = inputs }
        function recipe:getInputs() return self.inputs end
        local manager = {}
        function manager:getCraftRecipe(id)
            assert(id == RECIPE_ID, "unexpected recipe lookup: " .. tostring(id))
            return not options.missingRecipe and recipe or nil
        end

        ResourceLocation = { of = function(id) return { id = id } end }
        ItemTag = {
            get = function(location)
                assert(location.id == TAG_ID)
                return options.changedIdentity and foreignTag or tag
            end,
            register = function()
                f.mutations = f.mutations + 1
                error("verifier must not register tags late")
            end,
        }
        SuQingRecipeInputGuard = {
            VERSION = "1.0.0", tagId = TAG_ID, tag = tag,
            registration = options.failedRegistration and "registration-failed" or "registered",
        }
        getScriptManager = function() return manager end
        Events = { OnGameStart = { Add = function(callback) f.callbacks[#f.callbacks + 1] = callback end } }
        print = function(...)
            local values = {}
            for i = 1, select("#", ...) do values[i] = tostring(select(i, ...)) end
            f.logs[#f.logs + 1] = table.concat(values, " ")
        end
        loadVerifier()
        f.G, f.tag, f.target = SuQingRecipeInputGuard, tag, target
        f.candidates, f.candidateList, f.inputs = candidates, candidateList, inputs
        f.flour, f.fluid, f.recipe = flour, fluid, recipe
        f.original = target.original
        function f.assertUntouched()
            assert(f.mutations == 0, "read-only verification mutated input data")
            assert(f.target.original == f.original and f.target.quantity == 5)
            assert(f.target.candidates == f.candidateList and f.target.tags == tags)
            assert(f.recipe.inputs == f.inputs and f.inputs.values == inputValues)
            assert(f.candidateList.values == f.candidates)
            assert(f.flour.quantity == 4 and f.flour.original == "item 4 [Base.Flour],")
            assert(f.fluid.amount == 0.5 and f.fluid.fluid == "CowMilk")
        end
        return f
    end

    local function test(name, callback)
        callback()
        passed = passed + 1
        saved.print("PASS recipe verification: " .. name)
    end

    local function rejected(options, messagePart)
        local f = fixture(options)
        local ok, reason = f.G.Verify()
        assert(ok == false and type(reason) == "string")
        assert(reason:find(messagePart, 1, true), "unexpected rejection: " .. tostring(reason))
        assert(f.G.validationStatus == "failed" and #f.logs >= 1)
        f.assertUntouched()
    end

    local ok, err = pcall(function()
        test("two legitimate sources pass without changing quantities or fluids", function()
            local f = fixture()
            assert(f.G.Verify())
            assert(f.G.validationStatus == "verified" and f.G.candidateCount == 2)
            assert(#f.useChecks == 6)
            assert(#f.candidates == 2 and f.candidates[1]:getFullName() == "Base.Strewberrie")
            assert(f.candidates[2]:getFullName() == "SapphCooking.Syrup_Strawberry")
            f.assertUntouched()
        end)

        test("an additional genuinely tagged source is preserved", function()
            local f = fixture({ extraTagged = true })
            assert(f.G.Verify())
            assert(f.G.candidateCount == 3 and #f.candidates == 3)
            assert(f.candidates[3]:getFullName() == "Fixture.AnotherStrawberry")
            f.assertUntouched()
        end)

        test("failed early registration is not repaired late", function()
            rejected({ failedRegistration = true }, "early registry phase did not succeed")
        end)
        test("changed tag identity is rejected without replacing it", function()
            rejected({ changedIdentity = true }, "identity changed")
        end)
        test("a missing recipe is rejected", function()
            rejected({ missingRecipe = true }, "recipe missing or changed")
        end)
        test("a changed input quantity is not silently patched", function()
            rejected({ original = "item 6 tags[sapphcooking:strawberry]," }, "input missing or ambiguous")
        end)
        test("ambiguous matching inputs are rejected", function()
            rejected({ duplicate = true }, "input missing or ambiguous")
        end)
        test("an unresolved null tag is rejected", function()
            rejected({ nullTag = true }, "unresolved/incorrect tag")
        end)
        test("clothing in candidates is rejected and retained for diagnosis", function()
            rejected({ unrelated = true }, "unrelated item")
        end)
        test("missing syrup is rejected without manufacturing a new candidate", function()
            rejected({ missingSyrup = true }, "source absent")
        end)
        test("a legitimate candidate rejected by native matching is detected", function()
            rejected({ rejectBerry = true }, "source absent")
        end)
        test("native acceptance of an unrelated cartridge is detected", function()
            rejected({ acceptCartridge = true }, "unrelated item is accepted")
        end)
        test("OnGameStart reports native read failures without mutating inputs", function()
            local f = fixture({ readError = true })
            assert(#f.callbacks == 1)
            local callbackOk = pcall(f.callbacks[1])
            assert(callbackOk and f.G.validationStatus == "failed")
            assert(f.G.validationError:find("fixture input-read error", 1, true))
            f.assertUntouched()
        end)
    end)

    ResourceLocation = saved.ResourceLocation
    ItemTag = saved.ItemTag
    SuQingRecipeInputGuard = saved.SuQingRecipeInputGuard
    getScriptManager = saved.getScriptManager
    Events = saved.Events
    print = saved.print
    if not ok then error(err, 0) end
    return passed
end

return { run = run }
