local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Services
local DataServiceServer = require(ServerScriptService.Features.Data.DataServiceServer)
local AnimalServiceServer = require(ServerScriptService.Features.Animal.AnimalServiceServer)
local NotificationService = require(ServerScriptService.Features.Notification.NotificationServiceServer)

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Source.Features.Data.ProfileTemplate)

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

type Profile = ProfileTemplate.ProfileTemplate
type BaseData = ProfileTemplate.BaseData
type FloorData = ProfileTemplate.FloorData
type AnimalData = ProfileTemplate.AnimalData

type BaseServer = BaseServer.BaseServer

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

local function attemptPlaceAnimal(player: Player, floorIndex: number, standIndex: number)
	local base: BaseServer = BaseService.PlayerBases[player]
	if not base then warn("[attemptPlaceAnimal] missing base") return end

	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptPlaceAnimal] missing floor object for", floorIndex) return end

	if not floor:OwnsFloor() then
		warn("[attemptPlaceAnimal] Floor is not unlocked")
		return
	end

	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptPlaceAnimal] missing animalStand object:", standIndex) return end
	
	local animalTool: Tool? = player.Character and player.Character:FindFirstChild("AnimalTool")
	if not animalTool then warn("[attemptPlaceAnimal] No animal tool equipped") return end
	
	local profile: Profile = DataServiceServer:GetProfile(player)
	if not profile then warn("[attemptPlaceAnimal] No profile found for player:", player) return end

	-- check if animalKey exists in profile
	local animalKey = animalTool:GetAttribute("AnimalKey")
	local ownedAmount = profile.inventory.animals[animalKey]
	if not ownedAmount then warn("[attemptPlaceAnimal] animalKey not found in profile: ", animalKey) return end
	
	if ownedAmount < 1 then
		warn("[attemptPlaceAnimal] not enough animals for key:", animalKey)
		return
	end
	
	local animalData: AnimalData? = AnimalServiceUtils.getAnimalData(animalKey)
	
	local success, reason = animalStand:AddAnimal(animalData)
	if not success then
		warn("[attemptPlaceAnimal] failed to add animal")
		if reason then NotificationService:Error(player, reason) end
		return
	end
	
	profile.inventory.animals[animalKey] -= 1
	AnimalServiceServer:UpdateAnimalTool(player, animalKey)
end

local function attemptRemoveAnimal(player: Player, floorIndex: number, standIndex: number)
	local base: BaseServer = BaseService.PlayerBases[player]
	if not base then warn("[attemptRemoveAnimal] missing base") return end

	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptRemoveAnimal] missing floor object for", floorIndex) return end

	if not floor:OwnsFloor() then
		warn("[attemptRemoveAnimal] Floor is not unlocked")
		return
	end

	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptRemoveAnimal] missing animalStand object:", standIndex) return end

	local success = animalStand:RemoveAnimal()
	if not success then
		NotificationService:Error(player, "Failed to remove animal!")
		return
	end
end

local function attemptUnlockStand(player: Player, floorIndex: number, standIndex: number)
	local base: BaseServer = BaseService.PlayerBases[player]
	if not base then warn("[attemptUnlockStand] missing base") return end
	
	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptUnlockStand] missing floor object for", floorIndex) return end
	
	if not floor:OwnsFloor() then
		warn("[attemptUnlockStand] Floor is not unlocked")
		return
	end
	
	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptUnlockStand] missing animalStand object:", standIndex) return end
	
	local profile: Profile = DataServiceServer:GetProfile(player)
	if not profile then warn("[attemptUnlockStand] No profile found for player:", player) return end
	
	local unlockCost: number = BaseServiceUtils.getStandCost(floorIndex)
	if profile.currency.Money < unlockCost then
		NotificationService:Error(player, "Cannot buy!")
		return
	end

	local success = animalStand:Unlock()
	if not success then
		warn("[attemptUnlockStand] failed to unlock animalStand")
		return
	end

	DataServiceServer:IncrementCurrency(player, "Money", -unlockCost, "Buy Stand", false)
end

local function attemptBuyAnimalLevels(player: Player, floorIndex: number, standIndex: number, levelAmount: number)
	if typeof(levelAmount) ~= "number" then return end
	levelAmount = math.clamp(levelAmount, 1, 10)
	if math.floor(levelAmount) ~= levelAmount then return end
	
	local base: BaseServer = BaseService.PlayerBases[player]
	if not base then warn("[attemptBuyAnimalLevels] missing base") return end

	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptBuyAnimalLevels] missing floor object for", floorIndex) return end

	if not floor:OwnsFloor() then
		warn("[attemptBuyAnimalLevels] Floor is not unlocked")
		return
	end

	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptBuyAnimalLevels] missing animalStand object:", standIndex) return end
	
	local animalData = animalStand.StandData and animalStand.StandData.occupant
	if not animalData then warn("[attemptUnlockStand] misising animalData") return end
	
	local definitionKey = animalData.definitionKey
	local currentLevel = animalData.level
	
	local profile: Profile = DataServiceServer:GetProfile(player)
	if not profile then warn("[attemptUnlockStand] No profile found for player:", player) return end

	local levelsCost: number = AnimalServiceUtils.getLevelUpCost(definitionKey, currentLevel, levelAmount)
	if profile.currency.Money < levelsCost then
		NotificationService:Error(player, "Cannot buy!")
		return
	end
	
	local success = animalStand:LevelAnimal(levelAmount)
	if not success then
		NotificationService:Error(player, "Failed to level animal!")
		return
	end
	
	DataServiceServer:IncrementCurrency(player, "Money", -levelsCost, "Level Animal", false)
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
	local spawnLocation: SpawnLocation = baseModel.SpawnLocation
	
	-- hide floors
	local floorsContainer = baseModel.Floors
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		BaseServiceUtils.showInstance(floorFolder, false)
	end
	
	-- hide components
	BaseServiceUtils.showInstance(baseModel.Components, false)
	
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
	DataServiceServer.Signals.DataLoaded:Connect(function(player: Player)
		self:AssignBase(player)
	end)
	
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