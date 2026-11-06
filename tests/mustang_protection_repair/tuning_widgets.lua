local function noop() end
local function richText()
    return {
        height = 20,
        setWidth = function(self, width) self.width = width end,
        setText = noop,
        render = noop,
    }
end
local function panel()
    return {
        itemheight = 18,
        setX = noop,
        setY = function(self, value) self.y = value end,
        setHeight = function(self, value) self.height = value end,
        setVisible = noop,
        getBottom = function(self) return self.y + self.height end,
    }
end

-- Simulate widgets and item APIs; keep Tsar's recipe builder and render function intact.
ISVehicleTuning2.getContainers = noop
ISVehicleTuning2.refreshIngredientPanel = noop
function ISVehicleTuning2:IsRecipeValid() return true end
function ISVehicleTuning2:GetItemInstance(itemType)
    return {
        IsDrainable = function() return itemType == "Base.BlowTorch" end,
        getTex = function() return nil end,
        getDisplayName = function() return itemType end,
        getFullType = function() return itemType end,
    }
end

function ISVehicleTuning2:createChildren()
    self.width = 800
    self.playerNum = 0
    self.getWidth = function() return 800 end
    self.getHeight = function() return 700 end
    self.borderColor = { a = 1, r = 1, g = 1, b = 1 }
    self.drawRectBorder = noop
    self.drawText = noop
    self.javaObject = { DrawTextureScaledColor = noop }
    self.keysRichText = richText()
    self.noteRichText = richText()
    self.ingredientPanel = panel()
    self.toolsPanel = panel()
    self.resultPanel = panel()
    self.character.isDriving = function() return false end
    self.character.isRecipeKnown = function() return true end
    self.character.getPerkLevel = function() return 2 end
    self.refreshTypesAvailableMS = 0

    ISCollapsableWindow.createChildren(self)
    self.craftOneButton.getBottom = function(button) return button:getY() + button.height end
    self.addIngredientButton = ISButton:new(0, 0, 50, 25, "Add", self)
    self:populateRecipesList()
    local view = self.panel.activeView.view
    local items = {}
    for _, recipe in ipairs(self.recipesList[view.category]) do items[#items + 1] = { item = recipe } end
    view.recipes = { items = items, selected = 1 }
end
