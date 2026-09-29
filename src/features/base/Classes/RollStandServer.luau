local EncodingService = game:GetService("EncodingService")
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
	RollStandData: Scribe.PlayerData<typeof(DataTemplate.base.rollStandData)>,
}

export type RollStandServer = typeof(setmetatable({} :: self, RollStandServer))

function RollStandServer.new(owner: Player, container: Folder)
	local self = setmetatable({} :: self, RollStandServer)
	self.Trove = Trove.new()

	self.Owner = owner
	self.Container = container
	self.RollStandData = Data[owner].base.rollStandData

	BaseServiceUtils.showInstance(container, true)
	self:refreshAllSlots()

	self.Trove:Add(self.RollStandData.upgrades.rollSlots.Changed(function(newUnlockedAmount: number)
		self:refreshSlot(newUnlockedAmount)
	end))


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
	self:refreshAllSlots()

	local unlockedSlots = self.RollStandData.upgrades.rollSlots.Get()
	for slotIndex = 1, unlockedSlots do
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
	print("Roll Luck", playerLuck)
	task.delay(BaseServiceUtils.rollLength, function()
		self:refreshAllSlots()
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
	self:refreshSlot(slotIndex)
end

function RollStandServer.refreshSlot(self: RollStandServer, slotIndex: number)
	local rollData = self.RollStandData.Get()
	local unlockedSlots = rollData.upgrades.rollSlots
	local available = slotIndex <= unlockedSlots

	local slotModel: Folder = self.Container.Slots:FindFirstChild(slotIndex)
	if not slotModel then
		warn("[refreshSlot] slot model not found for slotIndex: ", slotIndex)
		return
	end

	if available then
		local slotData = rollData.slotData[slotIndex]
		local definitionKey = slotData and slotData.definitionKey
		slotModel:SetAttribute("DefinitionKey", definitionKey)
	else
		slotModel:SetAttribute("DefinitionKey", nil)
	end

	-- show/hide slot
	BaseServiceUtils.showInstance(slotModel, available)
	slotModel:SetAttribute("Active", available)
end

function RollStandServer.refreshAllSlots(self: RollStandServer)
	local slotsContainer = self.Container.Slots :: Folder
	for _, slotModel in ipairs(slotsContainer:GetChildren()) do
		local slotIndex = tonumber(slotModel.Name)
		self:refreshSlot(slotIndex)
	end
end

function RollStandServer.Destroy(self: RollStandServer)
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function RollStandServer.GetRollLuck(self: RollStandServer): number
	local added = 0

	-- roll luck upgrade
	local rollLuck = self.RollStandData.upgrades.rollLuck.Get()
	added += math.max(rollLuck, 0)

	-- TODO: pity luck

	return math.max(added, 1)
end




return RollStandServer
