local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

-- Services
local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local AnimalService = require(ServerScriptService.Features.Animal.AnimalServiceServer)
local NotificationServiceServer = require(ServerScriptService.Features.Notification.NotificationServiceServer)

-- Modules
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.Modules.BaseTypes)

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

type RollStandData = DataTemplate.RollStandData

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
	Owner: Player,
	Container: Folder,
	RollStandData: Scribe.PlayerData<RollStandData>,
}

export type RollStandServer = typeof(setmetatable({} :: self, RollStandServer))

function RollStandServer.new(owner: Player, container: Folder, rollData: Scribe.PlayerData<RollStandData>)
	local self = setmetatable({} :: self, RollStandServer)
	self.Trove = Trove.new()

	self.Owner = owner
	self.Container = container
	self.RollStandData = rollData

	BaseServiceUtils.showInstance(container, true)
	self:_Refresh()

	return self
end

--------------------------------------------------
-- ACTIONS --
--------------------------------------------------

function RollStandServer.Roll(self: RollStandServer)
	local playerLuck = self:GetRollLuck()
	local owner: Player = self.Owner

	local rollResult: RollResult = {
		slots = {},
		cutsceneSlotIndex = nil,
	}

	self.RollStandData.slotData.Set({})
	self:_Refresh()

	local unlockedCount = self.RollStandData.unlockedCount.Get()
	for slotIndex = 1, unlockedCount do
		local animalKey = AnimalServiceUtils.rollAnimalResult(playerLuck)
		if not animalKey then
			warn("[Roll] bad result: ", animalKey)
			continue
		end

		rollResult.slots[slotIndex] = {
			definitionKey = animalKey,
			isNew = AnimalService:discoveredAnimal(owner, animalKey) == false,
		}

		self.RollStandData.slotData[slotIndex].Set({
			definitionKey = animalKey
		})
	end

	remotes.RollAnimal:FireClient(owner, rollResult)

	task.delay(BaseServiceUtils.rollLength, function()
		self:_Refresh()
	end)
end

function RollStandServer.BuySlotAnimal(self: RollStandServer, slotIndex: number)
	local owner = self.Owner
	local slotData = self.RollStandData.slotData[slotIndex].Get()
	if not slotData or not slotData.definitionKey then
		return
	end

	local animalKey = AnimalServiceUtils.generateAnimalKey(slotData)
	if not animalKey then
		warn("[BuySlotAnimal] invalid animalKey: ", animalKey)
		return
	end

	local cost = 100 -- TODO: derive cost from AnimalUtil
	if Data[owner].currency.Money.Get() <= cost then
		NotificationServiceServer:Error(owner, "Cannot buy!")
		return
	end

	local success = AnimalService:GiveAnimal(owner, slotData)
	if not success then
		warn("[BuySlotAnimal] failed to give animal: ", success)
		return
	end

	Data[owner].currency.Money.Decrement(cost, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay,
		ItemSku = "Buy Roll Animal"
	})

	self.RollStandData.slotData[slotIndex].Set(nil)
	self:_Refresh()
end

function RollStandServer.Destroy(self: RollStandServer)
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function RollStandServer.GetRollLuck(self: RollStandServer): number
	local total = 1

	-- roll luck upgrade
	local rollLuck = self.RollStandData.rollLuck.Get()
	total += math.max(rollLuck, 0)

	return total
end

function RollStandServer._Refresh(self: RollStandServer)
	local rollData = self.RollStandData.Get()
	local unlockedCount = rollData.unlockedCount

	-- iterate through slots
	local slotsContainer: Folder = self.Container.Slots
	for _, slot in slotsContainer:GetChildren() do
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
