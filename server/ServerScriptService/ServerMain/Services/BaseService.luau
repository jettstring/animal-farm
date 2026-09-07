local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:WaitForChild("Assets")

-- Base Assets
local BaseAssets = Assets:WaitForChild("Base")
local Base = require(BaseAssets.Base)
local BaseFolders = workspace.Bases


local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyFloor = remotesFolder.Base.BuyFloor,
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
	PlaceAnimal = remotesFolder.Base.PlaceAnimal,
	BuyAnimalLevel = remotesFolder.Base.BuyAnimalLevel,
	RemoveAnimal = remotesFolder.Base.RemoveAnimal,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type BaseData = ProfileTemplate.BaseData
type FloorData = ProfileTemplate.FloorData
type ShopData = ProfileTemplate.ShopData
type AnimalData = ProfileTemplate.AnimalData

type Base = Base.Base

--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseService = {}
BaseService.Services = {}
BaseService.Signals = {}

BaseService.ClaimedBases = {} :: {[Folder]: Player}
BaseService.PlayerBases = {} :: {[Player]: Base}


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function attemptPlaceAnimal(player: Player, floorIndex: number, standIndex: number)
	local base: Base = BaseService.PlayerBases[player]
	if not base then warn("[attemptPlaceAnimal] missing base") return end

	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptPlaceAnimal] missing floor object for", floorIndex) return end

	if not floor:OwnsFloor() then
		warn("[attemptPlaceAnimal] Floor is not unlocked")
		return
	end

	local animalStand: AnimalDt = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptPlaceAnimal] missing animalStand object:", standIndex) return end
	
	local animalTool: Tool? = player.Character and player.Character:FindFirstChild("AnimalTool")
	if not animalTool then warn("[attemptPlaceAnimal] No animal tool equipped") return end
	
	local profile: Profile = BaseService.Services.DataService:GetProfile(player)
	if not profile then warn("[attemptPlaceAnimal] No profile found for player:", player) return end

	-- check if animalKey exists in profile
	local animalKey = animalTool:GetAttribute("AnimalKey")
	local ownedAmount = profile.inventory.animals[animalKey]
	if not ownedAmount then warn("[attemptPlaceAnimal] animalKey not found in profile: ", animalKey) return end
	
	if ownedAmount < 1 then
		warn("[attemptPlaceAnimal] not enough animals for key:", animalKey)
		return
	end
	
	local animalData: AnimalData? = AnimalUtil.getAnimalData(animalKey)
	
	local success, reason = animalStand:AddAnimal(animalData)
	if not success then
		warn("[attemptPlaceAnimal] failed to add animal")
		if reason then BaseService.Services.NotificationService:Error(player, reason) end
		return
	end
	
	profile.inventory.animals[animalKey] -= 1
	BaseService.Services.AnimalService:UpdateAnimalTool(player, animalKey)
end

local function attemptRemoveAnimal(player: Player, floorIndex: number, standIndex: number)
	local base: Base = BaseService.PlayerBases[player]
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
		BaseService.Services.NotificationService:Error(player, "Failed to remove animal!")
		return
	end
end

local function attemptUnlockStand(player: Player, floorIndex: number, standIndex: number)
	local base: Base = BaseService.PlayerBases[player]
	if not base then warn("[attemptUnlockStand] missing base") return end
	
	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptUnlockStand] missing floor object for", floorIndex) return end
	
	if not floor:OwnsFloor() then
		warn("[attemptUnlockStand] Floor is not unlocked")
		return
	end
	
	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptUnlockStand] missing animalStand object:", standIndex) return end
	
	local profile: Profile = BaseService.Services.DataService:GetProfile(player)
	if not profile then warn("[attemptUnlockStand] No profile found for player:", player) return end
	
	local unlockCost: number = BaseUtil.getStandCost(floorIndex)
	if profile.currency.Money < unlockCost then
		BaseService.Services.NotificationService:Error(player, "Cannot buy!")
		return
	end

	local success = animalStand:Unlock()
	if not success then
		warn("[attemptUnlockStand] failed to unlock animalStand")
		return
	end

	BaseService.Services.DataService:IncrementCurrency(player, "Money", -unlockCost, "Buy Stand", false)
end

local function attemptBuyAnimalLevels(player: Player, floorIndex: number, standIndex: number, levelAmount: number)
	if typeof(levelAmount) ~= "number" then return end
	levelAmount = math.clamp(levelAmount, 1, 10)
	if math.floor(levelAmount) ~= levelAmount then return end
	
	local base: Base = BaseService.PlayerBases[player]
	if not base then warn("[attemptBuyAnimalLevels] missing base") return end

	local floor = base.Floors[floorIndex]
	if not floor then warn("[attemptBuyAnimalLevels] missing floor object for", floorIndex) return end

	if not floor:OwnsFloor() then
		warn("[attemptRemoveAnimal] Floor is not unlocked")
		return
	end

	local animalStand = floor.AnimalStands[standIndex]
	if not animalStand then warn("[attemptBuyAnimalLevels] missing animalStand object:", standIndex) return end
	
	local animalData = animalStand.StandData and animalStand.StandData.occupant
	if not animalData then warn("[attemptUnlockStand] misising animalData") return end
	
	local definitionKey = animalData.definitionKey
	local currentLevel = animalData.level
	
	local profile: Profile = BaseService.Services.DataService:GetProfile(player)
	if not profile then warn("[attemptUnlockStand] No profile found for player:", player) return end

	local levelsCost: number = AnimalUtil.getLevelUpCost(definitionKey, currentLevel, levelAmount)
	if profile.currency.Money < levelsCost then
		BaseService.Services.NotificationService:Error(player, "Cannot buy!")
		return
	end
	
	local success = animalStand:LevelAnimal(levelAmount)
	if not success then
		BaseService.Services.NotificationService:Error(player, "Failed to level animal!")
		return
	end
	
	BaseService.Services.DataService:IncrementCurrency(player, "Money", -levelsCost, "Level Animal", false)
end

local function _cleanupBase(baseFolder: Folder)
	local baseModel: Model = baseFolder.Base
	local spawnLocation: SpawnLocation = baseModel.SpawnLocation
	
	
	-- hide floors
	local floorsContainer = baseModel.Floors
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		BaseUtil.showInstance(floorFolder, false)
	end
	
	-- hide components
	BaseUtil.showInstance(baseModel.Components, false)
	
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
		
		local base: Base? = Base.new(player, baseFolder, self.Services)
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

	local base: Base = self.PlayerBases[player]
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

function BaseService.Init(self: BaseService, services)
	self.Services = services
	
	for _, baseFolder in BaseFolders:GetChildren() do
		_cleanupBase(baseFolder)
	end
end

function BaseService.Start(self: BaseService)
	self.Services.DataService.Signals.DataLoaded:Connect(function(player: Player)
		self:AssignBase(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		self:RemoveBase(player)
	end)
	
	
	remotes.BuyAnimalStand.OnServerEvent:Connect(attemptUnlockStand)
	remotes.PlaceAnimal.OnServerEvent:Connect(attemptPlaceAnimal)
	remotes.RemoveAnimal.OnServerEvent:Connect(attemptRemoveAnimal)
	remotes.BuyAnimalLevel.OnServerEvent:Connect(attemptBuyAnimalLevels)
end

type BaseService = typeof(BaseService) & {}

return BaseService