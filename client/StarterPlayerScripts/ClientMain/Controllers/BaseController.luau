local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Abbreviate = require(ReplicatedStorage.Packages.Abbreviate)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

-- Base Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local BaseAssets = Assets:WaitForChild("Base")


-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions
local MutationGradients = AnimalAssets:WaitForChild("MutationGradients")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RollAnimal = remotesFolder.Animal.RollAnimal,
	BuySlotAnimal = remotesFolder.Animal.BuySlotAnimal,
	StealSlotAnimal = remotesFolder.Animal.StealSlotAnimal,
	BuyFloor = remotesFolder.Base.BuyFloor,
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
	PlaceAnimal = remotesFolder.Base.PlaceAnimal,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------


type AnimationDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation


type Profile = ProfileTemplate.ProfileTemplate
type AnimalData = ProfileTemplate.AnimalData

--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseController = {}
BaseController.Controllers = {}
BaseController.Signals = {}

local currentStand: Folder? = nil
local standDisplayTrove = Trove.new()

--------------------------------------------------
-- VARIABLES --
--------------------------------------------------


-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------


local function showStandDisplay(standFolder: Folder, isOwner: boolean)
	local trove = standDisplayTrove
	trove:Clean() -- remove previous billboard
	
	if currentStand == standFolder then
		currentStand = nil
		return
	end
	
	local standModel: Model = standFolder:WaitForChild("StandModel")
	local animalMiddle: Part = standModel:WaitForChild("AnimalMiddle")
	
	local defKey = standFolder:GetAttribute("DefinitionKey")
	local animalDef: AnimationDefinition = defKey and AnimalDefinitions[defKey]
	if not animalDef then warn("[showStandDisplay] invalid animal definition key: ", defKey) return end
	
	local billboard = trove:Add(BaseAssets:FindFirstChild("StandBillboard"):Clone())
	local display = billboard.Display
	local nameLabel = display.NameLabel
	local levelLabel = display.LevelLabel
	local earningsLabel = display.EarningsLabel
	local modifiersDisplay = display.Modifiers
	local rarityLabel = modifiersDisplay.RarityLabel
	
	nameLabel.Text = animalDef.displayName
	rarityLabel.Text = animalDef.rarity
	billboard.Adornee = animalMiddle
	billboard.Parent = playerGui   
	
	trove:Add(Observers.observeAttribute(standFolder, "Level", function(level: number)
		levelLabel.Text = string.format("Level %s", Abbreviate.AbbreviateNumber(level, 1))
	end))
	
	local mutationLabelTrove = trove:Extend()
	trove:Add(Observers.observeAttribute(standFolder, "Mutation", function(mutation: string)
		mutationLabelTrove:Clean()
		
		local mutationLabel = mutationLabelTrove:Add(modifiersDisplay.UIListLayout.MutationLabel:Clone())
		if mutationLabel:FindFirstChildOfClass("UIGradient") then mutationLabel:FindFirstChildOfClass("UIGradient"):Destroy() end
		
		mutationLabel.Text = mutation
		
		local mutationGradient = MutationGradients:FindFirstChild(mutation) and MutationGradients:FindFirstChild(mutation):Clone()
		if mutationGradient then
			mutationGradient.Parent = mutationLabel
		end
		
		-- TODO: gradient effects
	end))
	
	trove:Add(Observers.observeAttribute(standFolder, "MoneyPerEgg", function(moneyPerEgg: number)
		earningsLabel.Text = string.format("$%s / Egg", Abbreviate.AbbreviateNumber(moneyPerEgg, 1))
	end))
	
	currentStand = standFolder
	
	return function() trove:Clean() end
end

local function mountAnimalStand(standFolder: Folder, floorIndex: number, owner: Player)
	local standIndex = tonumber(standFolder.Name)
	local isOwner = owner == player
	local standModel: Model = standFolder:WaitForChild("StandModel")
	local animalMiddle: Part = standModel:WaitForChild("AnimalMiddle")
	
	return Observers.observeAttribute(standFolder, "Active", function(isActive: boolean)
		local trove = Trove.new()
		
		if isActive then
			trove:Add(BaseController.Controllers.InteractionController:Register(standModel, function()
				if standFolder:GetAttribute("DefinitionKey") then
					showStandDisplay(standFolder, isOwner)
				elseif isOwner and player.Character and player.Character:FindFirstChild("AnimalTool") then
					remotes.PlaceAnimal:FireServer(floorIndex, standIndex)
				end
			end))
			
			
			trove:Add(Observers.observeAttribute(standFolder, "DefinitionKey", function(definitionKey: string)
				local defTrove = Trove.new()
				local renderTrove = defTrove:Extend()
				
				local function updateRender()
					renderTrove:Clean()
					
					local animalData: AnimalData = {
						definitionKey = definitionKey,
						level = standFolder:GetAttribute("Level") or 1,
						mutation = standFolder:GetAttribute("Mutation") or nil,
					}
					
					-- should the rendering of animal (model, animation connections, effects, etc) be on its own trove?
					local animalModel = renderTrove:Add(AnimalUtil.getAnimalModel(animalData))
					if animalModel then
						animalModel.Parent = standFolder
						animalModel:PivotTo(animalMiddle:GetPivot())
					end
					
					
					-- TODO: animation, fx, etc
				end
				
				
				defTrove:Add(Observers.observeAttribute(standFolder, "Mutation", function(mutation: string)
					updateRender()
				end))
				
				updateRender()
				
				return function()
					defTrove:Destroy()
					standDisplayTrove:Clean() -- remove display
				end
			end))
		else
			
			
			-- unlock sign
			if isOwner then
				local unlockSign: Model = standFolder:WaitForChild("UnlockSign")
				local display: Part = unlockSign:WaitForChild("Display")
				local lockedGui = trove:Add(BaseAssets:WaitForChild("LockedSignGui"):Clone())

				lockedGui.Parent = display
				lockedGui.Adornee = display

				local unlockButton = lockedGui.Button
				local buttonDisplay = unlockButton.ButtonDisplay
				local priceLabel = buttonDisplay.PriceLabel

				trove:Add(unlockButton.Activated:Connect(function()
					remotes.BuyAnimalStand:FireServer(floorIndex, standIndex)
				end))

				trove:Add(Observers.observeAttribute(standFolder, "UnlockCost", function(unlockCost: number)
					if not unlockCost then return function() end end
					priceLabel.Text = string.format("$%s", Abbreviate.AbbreviateNumber(unlockCost, 1))
					return function() end
				end))
			end
		end
		
		return function() trove:Destroy() end
	end)
end

local function mountFloors(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player
	
	local baseModel = baseFolder:WaitForChild("Base")
	local floorsContainer: Folder = baseModel:WaitForChild("Floors")
	
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		local floorIndex: number = tonumber(floorFolder.Name)
		if not floorIndex then warn("[mountFloors] invalid floor index: ", floorIndex) continue end
		
		local modelFolder = floorFolder:WaitForChild("Model")
		
		trove:Add(Observers.observeAttribute(floorFolder, "Active", function(isActive: boolean)
			local upgradesSign = floorFolder:WaitForChild("UpgradeSign")
			BaseUtil.showInstance(upgradesSign, isOwner and isActive)
		end))
		
		-- animal stands
		local standsContainer = floorFolder:WaitForChild("AnimalStands")
		for _, standFolder: Folder in standsContainer:GetChildren() do
			local standIndex: number = tonumber(standFolder.Name)
			if not standIndex then warn("[mountFloors] invalid stand index: ", standIndex) continue end

			trove:Add(mountAnimalStand(standFolder, floorIndex, owner))
		end
		
	end
	
	return function() trove:Destroy() end
end

local function mountRollStand(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player

	local baseModel = baseFolder:WaitForChild("Base")
	local components = baseModel:WaitForChild("Components")
	local rollStand = components:WaitForChild("RollStand")
	local slots: Folder = rollStand:WaitForChild("Slots")
	local interactPart = rollStand:WaitForChild("Interact")
	local leverModel = rollStand:WaitForChild("Lever")
	local rollPrompt: ProximityPrompt = interactPart:WaitForChild("RollPrompt")
	
	-- roll prompt
	rollPrompt.Enabled = isOwner
	if isOwner then
		trove:Add(rollPrompt.Triggered:Connect(function()
			remotes.RollAnimal:FireServer()
		end))
	end
	
	-- slots
	for _, slot in slots:GetChildren() do
		local slotNumber = tonumber(slot.Name)
		local middlePart: Part = slot:WaitForChild("Middle")
		local model = slot:WaitForChild("Model")
		local buyPrompt: ProximityPrompt = middlePart:WaitForChild("BuyPrompt")
		local stealPrompt: ProximityPrompt= middlePart:WaitForChild("StealPrompt")
		
		local isActive = false
		local hasAnimal = false
		
		
		local function updatePrompts()
			local active = isActive and hasAnimal
			buyPrompt.Enabled = active and isOwner
			stealPrompt.Enabled = active and not isOwner
		end
		
		trove:Add(Observers.observeAttribute(slot, "Active", function(state: boolean)
			isActive = state
			updatePrompts()
			return function() end
		end))
		
		
		trove:Add(Observers.observeAttribute(slot, "DefinitionKey", function(definitionKey: string)
			hasAnimal = definitionKey ~= nil
			updatePrompts()
			
			if not definitionKey then
				return function() end
			end
			
			local animalTrove = trove:Extend()
			
			local animalData: AnimalData = {
				definitionKey = definitionKey,
			}
			
			local animalModel = animalTrove:Add(AnimalUtil.getAnimalModel(animalData))
			if animalModel then
				animalModel.Parent = model
				animalModel:PivotTo(middlePart:GetPivot())
			end
			
			return function() animalTrove:Destroy() end
		end))
		
		
		if isOwner then
			trove:Add(buyPrompt.Triggered:Connect(function()
				remotes.BuySlotAnimal:FireServer(slotNumber)
			end))
		else
			trove:Add(stealPrompt.Triggered:Connect(function()
				remotes.StealSlotAnimal:FireServer(owner, slotNumber)
			end))
		end
	end
	
	return function() trove:Destroy() end
end

local function mountBases()
	Observers.observeTag("Base", function(baseFolder: Folder)
		return Observers.observeAttribute(baseFolder, "Owner", function(ownerName)
			local trove = Trove.new()
			local owner: Player = Players:FindFirstChild(ownerName)
			
			local isOwner = owner == player
			
			-- base components
			trove:Add(mountFloors(baseFolder, owner))
			trove:Add(mountRollStand(baseFolder, owner))
			
			
			return function() trove:Destroy() end
		end)
	end)
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function BaseController.PublicFoo(self: BaseController)

end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function BaseController.Init(self: BaseController, controllers)
	self.Controllers = controllers
	
end

function BaseController.Start(self: BaseController)
	
	mountBases()
end

type BaseController = typeof(BaseController) & {}


return BaseController