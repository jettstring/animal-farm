local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Services
local AnimalService = require(ServerScriptService.ServerMain.Services.AnimalService)
local NotificationService = require(ServerScriptService.ServerMain.Services.NotificationService)

-- Services
local DataService = require(ServerScriptService.ServerMain.Services.DataService)

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)
local BaseTypes = require(ReplicatedStorage.Modules.BaseTypes)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)


-- Base Assets
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local BaseAssets = Assets:FindFirstChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions


local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RollAnimal = remotesFolder.Base.RollAnimal,
}

-------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type RollData = ProfileTemplate.RollData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

type RollResult = BaseTypes.RollResult
type SlotResult = BaseTypes.SlotResult


--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local RollStand = {}
RollStand.__index = RollStand

type self = {
	Trove: any,
	Base: any,
}

export type RollStand = typeof(setmetatable({} :: self, RollStand))

function RollStand.new(base: any, services: any)
	local self = setmetatable({} :: self, RollStand)
	self.Trove = Trove.new()
	
	self.Base = base
	
	local baseFolder: Folder = base.BaseFolder
	local baseModel: Model = baseFolder.Base
	local container: Folder = baseModel.Components.RollStand
	BaseUtil.showInstance(container, true)
	
	
	self:_Refresh()
	
	return self
end

--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function RollStand.Roll(self: RollStand)
	local rollData: RollData = self.Base.BaseData.rollData
	local unlockedCount = rollData.unlockedCount
	local playerLuck = self:GetRollLuck()
	local owner: Player = self.Base.Owner

	local rollResult: RollResult = {
		slots = {},
		cutsceneSlotIndex = nil
	}

	rollData.slotData = {}
	self:_Refresh()

	for slotIndex = 1, unlockedCount do
		if not rollData.slotData[slotIndex] then rollData.slotData[slotIndex] = {} end
		local slotData = rollData.slotData[slotIndex]

		-- get result
		local animalKey = AnimalUtil.rollAnimalResult(playerLuck)
		if not animalKey then warn("[Roll] bad result: ", animalKey) continue end
		
		rollResult.slots[slotIndex] = {
			definitionKey = animalKey,
			isNew = AnimalService:HasAnimal(owner, animalKey) == false
		}

		slotData.definitionKey = animalKey
	end
	
	remotes.RollAnimal:FireClient(owner, rollResult)
	
	task.delay(BaseUtil.rollLength, function()
		self:_Refresh()
	end)
end

function RollStand.BuySlotAnimal(self: RollStand, slotIndex: number)
	local owner: Player = self.Base.Owner
	local profile: Profile = DataService:GetProfile(owner)
	if not profile then warn("[BuySlotAnimal] No profile found for player:", owner) return end
	
	local rollData: RollData = profile.base.rollData
	local slotData = rollData and rollData.slotData[slotIndex]
	if not slotData or not slotData.definitionKey then
		return
	end

	local animalKey = AnimalUtil.generateAnimalKey(slotData)
	if not animalKey then 
		warn("[BuySlotAnimal] invalid animalKey: ", animalKey)
		return
	end

	local cost = 100 -- TODO: derive cost from AnimalUtil
	if profile.currency.Money <= cost then
		NotificationService:Error(owner, "Cannot buy!")
		return
	end
	

	
	local success = AnimalService:GiveAnimal(owner, slotData)
	if not success then
		warn("[BuySlotAnimal] failed to give animal: ", success)
		return
	end
	
	DataService:IncrementCurrency(owner, "Money", -cost, "Buy Animal", false)
	
	rollData.slotData[slotIndex] = nil
	self:_Refresh()
end

function RollStand.Destroy(self: RollStand)
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

function RollStand.GetRollLuck(self: RollStand): number
	local owner: Player = self.Base.Owner
	
	local total = 1 
	
	-- roll luck upgrade
	local rollData: RollData = self.Base.BaseData.rollData
	local rollLuck = rollData.rollLuck
	total += math.max(rollLuck, 0)
	
	return total
end

function RollStand._Refresh(self: RollStand)
	local baseFolder: Folder = self.Base.BaseFolder
	local baseModel: Model = baseFolder:WaitForChild("Base")
	local container: Folder = baseModel.Components.RollStand
	local slots: Folder = container.Slots

	local rollData: RollData = self.Base.BaseData.rollData
	local unlockedCount = rollData.unlockedCount
	local rollLuck = rollData.rollLuck
	
	-- iterate through stands
	for _, slot in slots:GetChildren() do
		local slotIndex = tonumber(slot.Name)
		local model = slot:FindFirstChild("Model")
		
		local available = slotIndex <= unlockedCount
		slot:SetAttribute("Active", available)
		
		if available then
			local slotData = rollData.slotData[slotIndex]
			local definitionKey = slotData and slotData.definitionKey
			slot:SetAttribute("DefinitionKey", definitionKey)
			
		else
			slot:SetAttribute("DefinitionKey", nil)
			
		end
		
		-- show/hide slot
		BaseUtil.showInstance(model, available)
	end
	
end

return RollStand
