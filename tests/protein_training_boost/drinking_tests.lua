-- Run from the repository root:
-- dofile("tests/protein_training_boost/drinking_tests.lua").run()
-- A runner may instead supply a function that loads Drinking.lua.
local function run(loadModule)
    loadModule = loadModule or function()
        return dofile("src/SuQingProteinTrainingBoost/42/media/lua/client/SuQingProteinTrainingBoost/Drinking.lua")
    end

    local saved = {
        require = require,
        Fluid = Fluid,
        ISDrinkFluidAction = ISDrinkFluidAction,
    }
    local passed = 0
    local function close(actual, expected, label)
        assert(math.abs(actual - expected) < 0.000001,
            (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end

    local function fixture(original)
        local f = { logs = {}, doses = {}, originalCalls = 0, singlePlayer = true }
        local fluids = { ProteinA = {}, ProteinB = {} }
        local B = {
            FLUID_IDS = { "ProteinA", "ProteinB" },
            DOSE_LITRES = 0.5,
            MAX_HOURS = 3,
        }
        B.IsSinglePlayer = function() return f.singlePlayer end
        B.Log = function(message) f.logs[#f.logs + 1] = message end
        B.AddDose = function(player, litres)
            f.doses[#f.doses + 1] = { player = player, litres = litres }
        end
        Fluid = { Get = function(id) return fluids[id] end }
        ISDrinkFluidAction = {}
        ISDrinkFluidAction.updateEat = function(action, delta)
            f.originalCalls = f.originalCalls + 1
            if original then return original(action, delta) end
            local container = action.fluidContainer
            local target = action.startAmount * action.percentage * delta
            local amount = math.max(0, target - action.consumed)
            amount = math.min(amount, container.amount)
            local fraction = container.amount > 0 and amount / container.amount or 0
            for id, value in pairs(container.fluids) do
                container.fluids[id] = value * (1 - fraction)
            end
            container.amount = container.amount - amount
            action.consumed = action.consumed + amount
            if action.failAfter then container.failRead = true end
            return "kept", nil, delta
        end
        require = function(name)
            if name == "SuQingProteinTrainingBoost/Core" then return B end
            if name == "TimedActions/ISDrinkFluidAction" then return ISDrinkFluidAction end
            return saved.require(name)
        end
        loadModule()
        f.B = B
        assert(B.Drinking.Install())
        function f.action(total, proteinA, proteinB, percentage)
            local container = {
                amount = total,
                fluids = { [fluids.ProteinA] = proteinA or 0, [fluids.ProteinB] = proteinB or 0 },
            }
            function container:getAmount()
                if self.failRead then error("test total read failure") end
                return self.amount
            end
            function container:getSpecificFluidAmount(fluid)
                if self.failRead then error("test component read failure") end
                return self.fluids[fluid] or 0
            end
            return setmetatable({
                fluidContainer = container,
                character = {},
                startAmount = total,
                percentage = percentage or 1,
                consumed = 0,
            }, { __index = ISDrinkFluidAction })
        end
        function f:totalDose()
            local total = 0
            for _, dose in ipairs(self.doses) do total = total + dose.litres end
            return total
        end
        return f
    end

    local function test(name, callback)
        callback()
        passed = passed + 1
        print("PASS drinking: " .. name)
    end

    local ok, err = pcall(function()
        test("half cup and original return values", function()
            local f = fixture()
            local action = f.action(0.5, 0.5, 0, 0.5)
            local first, second, third = action:updateEat(0.5)
            assert(first == "kept" and second == nil and third == 0.5)
            action:updateEat(1)
            close(f:totalDose(), 0.25)
            assert(f.doses[1].player == action.character)
            close(action.fluidContainer.amount, 0.25)
        end)

        test("repeated progress and final completion are not duplicated", function()
            local f = fixture()
            local action = f.action(0.5, 0.5)
            action:updateEat(0.5)
            action:updateEat(0.5)
            action:updateEat(1)
            action:updateEat(1)
            close(f:totalDose(), 0.5)
            assert(#f.doses == 2 and f.originalCalls == 4)
        end)

        test("interrupted drink gives only already consumed volume", function()
            local f = fixture()
            local action = f.action(0.5, 0.5)
            action:updateEat(0.3)
            -- Stopping the action adds nothing: no final progress is submitted.
            close(f:totalDose(), 0.15)
            close(action.fluidContainer.amount, 0.35)
        end)

        test("mixed flavours and dilution count only protein components", function()
            local f = fixture()
            local action = f.action(0.5, 0.25, 0.1)
            action:updateEat(1)
            close(f:totalDose(), 0.35)
        end)

        test("another bottle works without a shaker item identifier", function()
            local f = fixture()
            local action = f.action(1, 0.4, 0.2, 0.25)
            action.item = { fullType = "Base.WaterBottle" }
            action:updateEat(1)
            close(f:totalDose(), 0.15)
        end)

        test("pure water and empty containers have no dose", function()
            local f = fixture()
            f.action(0.5):updateEat(1)
            f.action(0):updateEat(1)
            assert(#f.doses == 0)
        end)

        test("pouring or dumping outside the drink action has no dose", function()
            local f = fixture()
            local action = f.action(0.5, 0.5)
            action.fluidContainer.amount = 0
            for fluid in pairs(action.fluidContainer.fluids) do action.fluidContainer.fluids[fluid] = 0 end
            assert(#f.doses == 0 and f.originalCalls == 0)
        end)

        test("original failure propagates and clears the reentry guard", function()
            local shouldFail = true
            local f = fixture(function(action)
                if shouldFail then error("original drink failure") end
                action.fluidContainer.amount = 0
                for fluid in pairs(action.fluidContainer.fluids) do action.fluidContainer.fluids[fluid] = 0 end
            end)
            local action = f.action(0.5, 0.5)
            local success, message = pcall(function() action:updateEat(1) end)
            assert(not success and tostring(message):find("original drink failure", 1, true))
            assert(#f.doses == 0)
            shouldFail = false
            action:updateEat(1)
            close(f:totalDose(), 0.5)
        end)

        test("failed before or after reads log and do not reward", function()
            local f = fixture()
            local before = f.action(0.5, 0.5)
            before.fluidContainer.failRead = true
            before:updateEat(1)
            local after = f.action(0.5, 0.5)
            after.failAfter = true
            after:updateEat(1)
            assert(#f.logs == 2 and #f.doses == 0 and f.originalCalls == 2)
        end)

        test("changed containers are rejected", function()
            local f = fixture(function(action)
                action.fluidContainer = {}
            end)
            f.action(0.5, 0.5):updateEat(1)
            assert(#f.logs == 1 and #f.doses == 0)
        end)

        test("negative and nonfinite reads are rejected", function()
            local f = fixture()
            f.action(-1):updateEat(0)
            f.action(0 / 0):updateEat(0)
            f.action(math.huge):updateEat(0)
            f.action(0.5, -0.1):updateEat(0)
            assert(#f.logs == 4 and #f.doses == 0)
        end)

        test("two installations preserve one wrapper and one reward", function()
            local f = fixture()
            local installed = ISDrinkFluidAction.updateEat
            assert(f.B.Drinking.Install())
            assert(ISDrinkFluidAction.updateEat == installed)
            f.action(0.5, 0.5):updateEat(1)
            close(f:totalDose(), 0.5)
            assert(#f.doses == 1 and f.originalCalls == 1)
        end)

        test("nested original calls are counted only by the outer call", function()
            local entered = false
            local f = fixture(function(action)
                if not entered then
                    entered = true
                    action:updateEat(1)
                    return
                end
                action.fluidContainer.amount = 0
                for fluid in pairs(action.fluidContainer.fluids) do action.fluidContainer.fluids[fluid] = 0 end
            end)
            f.action(0.5, 0.5):updateEat(1)
            close(f:totalDose(), 0.5)
            assert(#f.doses == 1 and f.originalCalls == 2)
        end)

        test("multiplayer leaves original drinking behaviour untouched", function()
            local f = fixture()
            f.singlePlayer = false
            f.action(0.5, 0.5):updateEat(1)
            assert(f.originalCalls == 1 and #f.doses == 0 and #f.logs == 0)
        end)
    end)

    require = saved.require
    Fluid = saved.Fluid
    ISDrinkFluidAction = saved.ISDrinkFluidAction
    if not ok then error(err, 0) end
    return passed
end

return { run = run }
