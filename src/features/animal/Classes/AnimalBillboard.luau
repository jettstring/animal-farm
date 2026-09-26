local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Trove = require(ReplicatedStorage.Packages.Trove)


local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local AnimalServiceUtil = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceUtils)
local Abbreviate = require(ReplicatedStorage.Source.Core.Util.Abbreviate)
local GradientSpinner = require(ReplicatedStorage.Source.Core.UI.GradientSpinner)

local AnimalAssets: Folder = ReplicatedStorage.Assets.Animals

-- Types
type AnimalData = DataTemplate.AnimalData


local AnimalBillboard = {}
AnimalBillboard.__index = AnimalBillboard

export type AnimalBillboard = typeof(setmetatable({} :: {
    trove: Trove.Trove,
    gui: BillboardGui,
    gradientTrove: Trove.Trove,
    
}, AnimalBillboard))

function AnimalBillboard.new(root: Part, animalData: AnimalData): AnimalBillboard?
    local self = setmetatable({}, AnimalBillboard)
    self.trove = Trove.new()
    self.gradientTrove = self.trove:Extend()

    if not root or not animalData  then
        warn("Root part and animal data are required for AnimalBillboard")
        self:destroy()
        return nil
    end
    
    local gui = self.trove:Add(AnimalAssets:WaitForChild("AnimalBillboard"):Clone() :: BillboardGui)
    gui.Adornee = root
    gui.Parent = root
    self.gui = gui

    self:update(animalData)

    return self
end


function AnimalBillboard.update(self: AnimalBillboard, animalData: AnimalData)
    if not animalData then
        warn("[update] missing animalData")
        return
    end

    local animalDef = AnimalServiceUtil.getAnimalDefinitionFromData(animalData)
    
    local gui = self.gui
    local display: Frame = gui:WaitForChild("Display")
    local nameLabel = display:WaitForChild("Name") :: TextLabel 
    local oddsLabel = display:WaitForChild("Odds") :: TextLabel
    local rarityLabel = display:WaitForChild("Rarity") :: TextLabel
    local priceLabel = display.PriceDisplay:WaitForChild("Price") :: TextLabel

    local rarityInfo = AnimalServiceUtil.resolveRarityInfo(animalData.definitionKey)

    nameLabel.Text = animalDef.displayName
    oddsLabel.Text = string.format("[ 1 / %s ]", Abbreviate.AddCommas(math.round(1 / animalDef.odds)))
    priceLabel.Text = string.format("$%s", Abbreviate.AbbreviateNumber(animalDef.price))
    rarityLabel.Text = rarityInfo.name or "N/A"

    self.gradientTrove:Clean()
    local colorSequence = rarityInfo.gradient
    local rarityGradient = self.gradientTrove:Add(Instance.new("UIGradient"))
    rarityGradient.Color = colorSequence or ColorSequence.new(Color3.new(1, 1, 1))
    self.gradientTrove:Add(GradientSpinner.spin(rarityGradient, 50))
    rarityGradient.Parent = rarityLabel

end


function AnimalBillboard.destroy(self: AnimalBillboard)
    self.trove:Clean()
end

return AnimalBillboard