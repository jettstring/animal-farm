local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local AnimalServiceServer = require(ServerScriptService.Features.Animal.AnimalServiceServer)
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)
local NotificationService = require(ServerScriptService.Features.Notification.NotificationServiceServer)

-- Classes
local BaseServer = require(ServerScriptService.Features.Base.Classes.BaseServer)

-- Utils
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)
local AnimalServiceUtils = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceUtils)

local BaseFolders: Folder = workspace.Bases

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyFloor = remotesFolder.Base.BuyFloor,
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
	PlaceAnimal = remotesFolder.Base.PlaceAnimal,
	BuyAnimalLevel = remotesFolder.Base.BuyAnimalLevel,
	RemoveAnimal = remotesFolder.Base.RemoveAnimal,
	SellEggs = remotesFolder.Base.SellEggs,
	RollAnimal = remotesFolder.Base.RollAnimal,
	BuySlotAnimal = remotesFolder.Base.BuySlotAnimal,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type FloorData = DataTemplate.FloorData
type AnimalData = DataTemplate.AnimalData

type BaseServer = BaseServer.BaseServer
type AnimalStandServer = AnimalStandServer.AnimalStandServer

--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseService = {}
BaseService.Signals = {}

BaseService.ClaimedBases = {} :: {[Folder]: Player}
BaseService.PlayerBases = {} :: {[Player]: 	BaseServer}


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------


local function getStand(player: Player, floorIndex: number, standIndex: number): AnimalStandServer?
	local base = BaseService.PlayerBases[player]
	if not base or not base:OwnsFloor(floorIndex) then return nil end
	local floor = base.Floors[floorIndex]
	return floor and floor.AnimalStands[standIndex]
end

local function attemptPlaceAnimal(player: Player, floorIndex: number, standIndex: number)
	local stand = getStand(player, floorIndex, standIndex)
	
	-- check if animalKey exists in profile
	local animalTool = AnimalServiceServer:GetEquippedAnimalTool(player)
	local animalKey = animalTool and animalTool:GetAttribute("AnimalKey")
	local animals = Data[player].inventory.animals
	if not animalKey or (animals[animalKey].Get() or 0) < 1 then return end
	
	-- TODO: guard unlocked stand & stand existing occupant
	
	local animalData = AnimalServiceUtils.getAnimalData(animalKey)
	local added, reason = stand:AddAnimal(animalData)
	if not added then
		warn("[attemptPlaceAnimal] failed to add animal")
		if reason then NotificationService:Error(player, reason) end
		return
	end
	
	animals[animalKey].Decrement(1)
	AnimalServiceServer:UpdateAnimalTool(player, animalKey)
end

local function attemptRemoveAnimal(player: Player, floorIndex: number, standIndex: number)
	local stand = getStand(player, floorIndex, standIndex)
	local occupant = stand and stand:GetOccupant()
	if not occupant then return end

	local success = stand:RemoveAnimal()
	if not success then
		NotificationService:Error(player, "Failed to remove animal!")
		return
	end
end

local function attemptUnlockStand(player: Player, floorIndex: number, standIndex: number)
	local stand = getStand(player, floorIndex, standIndex)
	local cost: number = BaseServiceUtils.getStandCost(floorIndex)

	if Data[player].currency.Money.Get() < cost then
		NotificationService:Error(player, "Cannot buy!")
		return
	end
	
	local success = stand:Unlock()
	if not success then
		warn("[attemptUnlockStand] failed to unlock stand")
		return
	end

	Data[player].currency.Money.Decrement(cost, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay,
		ItemSku = "Unlock Stand"
	})
end

local function attemptBuyAnimalLevels(player: Player, floorIndex: number, standIndex: number, levelAmount: number)
	if typeof(levelAmount) ~= "number" then return end
	levelAmount = math.clamp(levelAmount, 1, 10)
	if math.floor(levelAmount) ~= levelAmount then return end
	
	local stand = getStand(player, floorIndex, standIndex)
	if not stand then warn("[attemptBuyAnimalLevels] missing stand") return end
	
	local animalData = stand.StandData and stand.StandData.occupant
	if not animalData then warn("[attemptBuyAnimalLevels] misising animalData") return end
	
	local definitionKey = animalData.definitionKey.Get()
	local currentLevel = animalData.level.Get()
	local cost: number = AnimalServiceUtils.getLevelUpCost(definitionKey, currentLevel, levelAmount)
	if Data[player].currency.Money.Get() < cost then
		NotificationService:Error(player, "Cannot buy!")
		return
	end
	
	local success = stand:LevelAnimal(levelAmount)
	if not success then
		NotificationService:Error(player, "Failed to level animal!")
		return
	end
	
	Data[player].currency.Money.Decrement(cost, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay,
		ItemSku = "Level Animal"
	})
end

local function attemptSellEggs(player: Player, source: string)
	local base: BaseServer = BaseService.PlayerBases[player]
	if not base then warn("[attemptSellEggs] missing base") return end
	base:SellCrates(source)
end

local function attemptRollAnimal(player)
	local base: BaseServer = BaseService.PlayerBases[player]
	local rollStand = base and base.RollStand
	if not rollStand then warn("missing rollStand object") return end
	rollStand:Roll()
end

local function attemptBuySlotAnimal(player: Player, slotIndex: number)
	local base: BaseServer = BaseService.PlayerBases[player]
	local rollStand = base and base.RollStand 
	if not rollStand then warn("missing rollStand object") return end
	rollStand:BuySlotAnimal(slotIndex)
end

local function _cleanupBase(baseFolder: Folder)
	local baseModel: Model = baseFolder.Base
	
	-- hide floors
	local floorsContainer = baseModel.Floors
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		BaseServiceUtils.showInstance(floorFolder, false)
	end
	
	-- hide components
	BaseServiceUtils.showInstance(baseModel.Components, false)
end


local function _playerAdded(player: Player)
	local data, reason = Data.WaitForData(player)
	if not data then
		warn("Could not load player data:", reason)
		return
	end

	BaseService:AssignBase(player)
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------


function BaseService.AssignBase(self: BaseService, player: Player)
	if not player then return end
	
	-- already assigned
	if self.PlayerBases[player] then
		warn("[AssignBase] player already assigned a base")
		return
	end
	
	-- find available base
	for i = 1, #BaseFolders:GetChildren() do
		local baseFolder = BaseFolders:FindFirstChild(i)
		if not baseFolder then continue end
		
		-- check if claimed by someone else
		local owner = self.ClaimedBases[baseFolder]
		if owner then continue end
		
		local base: BaseServer? = BaseServer.new(player, baseFolder)
		if not base then
			warn("[AssignBase] failed to create base for player", player)
			return
		end
		self.ClaimedBases[baseFolder] = player
		self.PlayerBases[player] = base
		player:SetAttribute("BaseAssigned", i) 
		
		print("[AssignBase] assigned base to player", player)
		return
	end
end

function BaseService.RemoveBase(self: BaseService, player: Player)
	local baseFolder: number? = player:GetAttribute("BaseAssigned") and BaseFolders:FindFirstChild(player:GetAttribute("BaseAssigned"))
	if baseFolder then
		self.ClaimedBases[baseFolder] = nil
	end

	local base: BaseServer = self.PlayerBases[player]
	if base then
		base:Destroy()
		self.PlayerBases[player] = nil 
	end
	
	player:SetAttribute("BaseAssigned", nil)
	
	_cleanupBase(baseFolder)
	
	print("[RemoveBase] removed base for", player)
end


--------------------------------------------------
-- MAIN --
--------------------------------------------------

function BaseService.Init(self: BaseService)
	for _, baseFolder in BaseFolders:GetChildren() do
		_cleanupBase(baseFolder)
	end
end

function BaseService.Start(self: BaseService)
	Players.PlayerAdded:Connect(_playerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(_playerAdded(player))
	end
	
	Players.PlayerRemoving:Connect(function(player: Player)
		self:RemoveBase(player)
	end)
	
	remotes.BuyAnimalStand.OnServerEvent:Connect(attemptUnlockStand)
	remotes.PlaceAnimal.OnServerEvent:Connect(attemptPlaceAnimal)
	remotes.RemoveAnimal.OnServerEvent:Connect(attemptRemoveAnimal) 
	remotes.BuyAnimalLevel.OnServerEvent:Connect(attemptBuyAnimalLevels)
	remotes.SellEggs.OnServerEvent:Connect(attemptSellEggs)
	remotes.RollAnimal.OnServerEvent:Connect(attemptRollAnimal)
	remotes.BuySlotAnimal.OnServerEvent:Connect(attemptBuySlotAnimal)
end

type BaseService = typeof(BaseService) & {}

return BaseService