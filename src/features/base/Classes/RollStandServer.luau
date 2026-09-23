local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

-- Services
local AnimalService = require(ServerScriptService.Features.Animal.AnimalServiceServer)
local NotificationServiceServer = require(ServerScriptService.Features.Notification.NotificationServiceServer)

-- Services
local DataService = require(ServerScriptService.Features.Data.DataServiceServer)

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Source.Features.Data.ProfileTemplate)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.BaseTypes)

-- Utils
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)
local AnimalServiceUtils = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceUtils)

-- Animal Assets
local AnimalConfig = require(ReplicatedStorage.Source.Features.Animal.AnimalConfig)

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

local RollStandServer = {}
RollStandServer.__index = RollStandServer

type self = {
	Trove: Trove.Trove,
	Base: any,
}

export type RollStandServer = typeof(setmetatable({} :: self, RollStandServer))

function RollStandServer.new(base: any, services: any)
	local self = setmetatable({} :: self, RollStandServer)
	self.Trove = Trove.new()

	self.Base = base

	local baseFolder: Folder = base.BaseFolder
	local baseModel: Model = baseFolder.Base
	local container: Folder = baseModel.Components.RollStand
	BaseServiceUtils.showInstance(container, true)

	self:_Refresh()

	return self
end

--------------------------------------------------
-- ACTIONS --
--------------------------------------------------

function RollStandServer.Roll(self: RollStandServer)
	local rollData: RollData = self.Base.BaseData.rollData
	local unlockedCount = rollData.unlockedCount
	local playerLuck = self:GetRollLuck()
	local owner: Player = self.Base.Owner

	local rollResult: RollResult = {
		slots = {},
		cutsceneSlotIndex = nil,
	}

	rollData.slotData = {}
	self:_Refresh()

	for slotIndex = 1, unlockedCount do
		if not rollData.slotData[slotIndex] then
			rollData.slotData[slotIndex] = {}
		end
		local slotData = rollData.slotData[slotIndex]

		-- get result
		local animalKey = AnimalServiceUtils.rollAnimalResult(playerLuck)
		if not animalKey then
			warn("[Roll] bad result: ", animalKey)
			continue
		end

		rollResult.slots[slotIndex] = {
			definitionKey = animalKey,
			isNew = AnimalService:HasAnimal(owner, animalKey) == false,
		}

		slotData.definitionKey = animalKey
	end

	remotes.RollAnimal:FireClient(owner, rollResult)

	task.delay(BaseServiceUtils.rollLength, function()
		self:_Refresh()
	end)
end

function RollStandServer.BuySlotAnimal(self: RollStandServer, slotIndex: number)
	local owner: Player = self.Base.Owner
	local profile: Profile = DataService:GetProfile(owner)
	if not profile then
		warn("[BuySlotAnimal] No profile found for player:", owner)
		return
	end

	local rollData: RollData = profile.base.rollData
	local slotData = rollData and rollData.slotData[slotIndex]
	if not slotData or not slotData.definitionKey then
		return
	end

	local animalKey = AnimalServiceUtils.generateAnimalKey(slotData)
	if not animalKey then
		warn("[BuySlotAnimal] invalid animalKey: ", animalKey)
		return
	end

	local cost = 100 -- TODO: derive cost from AnimalUtil
	if profile.currency.Money <= cost then
		NotificationServiceServer:Error(owner, "Cannot buy!")
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

function RollStandServer.Destroy(self: RollStandServer)
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function RollStandServer.GetRollLuck(self: RollStandServer): number
	local owner: Player = self.Base.Owner

	local total = 1

	-- roll luck upgrade
	local rollData: RollData = self.Base.BaseData.rollData
	local rollLuck = rollData.rollLuck
	total += math.max(rollLuck, 0)

	return total
end

function RollStandServer._Refresh(self: RollStandServer)
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
		BaseServiceUtils.showInstance(model, available)
	end
end

return RollStandServer
