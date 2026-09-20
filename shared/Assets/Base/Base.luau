local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Services
local DataService = require(ServerScriptService.ServerMain.Services.DataService)

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

local Assets = ReplicatedStorage:WaitForChild("Assets")

-- Base Assets
local BaseAssets = Assets:WaitForChild("Base")
local RollStand = require(BaseAssets.RollStand)
local Floor = require(BaseAssets.Floor)

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type BaseData = ProfileTemplate.BaseData
type FloorData = ProfileTemplate.FloorData

type RollStand = RollStand.RollStand
type Floor = Floor.Floor

--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local Base = {}
Base.__index = Base

type self = { 
	Owner: Player,
	BaseFolder: Folder,
	BaseData: BaseData,
	RollStand: RollStand,
	Floors: {[number]: Floor}
}

export type Base = typeof(setmetatable({} :: self, Base))

function Base.new(owner: Player, baseFolder: Folder): Base
	local self = setmetatable({} :: self, Base)
	self.Trove = Trove.new()
	
	self.State = {
		Active = false,
	}
	
	self.Owner = owner
	self.BaseFolder = baseFolder
	self.BaseData = nil
	self.Floors = {}
	
	self:_setup()
	if not self.State.Active then
		warn("Base is not active, destroying")
		self:Destroy()
		return nil
	end
	
	self:_Refresh()
	
	print("[Base] Created base object:", self)
	return self
end

function Base._setup(self: Base)
	local owner: Player = self.Owner
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:WaitForChild("Base")
	
	-- assign spawn location
	local spawnLocation = baseModel:WaitForChild("SpawnLocation")
	owner.RespawnLocation = spawnLocation
	if owner.Character then
		owner.Character:MoveTo(spawnLocation.Position + Vector3.new(0, 5, 0))
	end
	
	-- hydrate base from profile
	local profile: Profile = DataService:GetProfile(owner)
	if not profile then warn("[_Setup] No profile found for player", owner) end
	local baseData: BaseData = profile.base
	self.BaseData = baseData
	
	-- setup components
	self.RollStand = self.Trove:Add(RollStand.new(self))
	self:_setupFloors()
	
	baseFolder:SetAttribute("Owner", owner.Name)
	self.State.Active = true
	
	return self
end


function Base._setupFloors(self: Base)
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:WaitForChild("Base")
	local floorsContainer: Folder = baseModel:WaitForChild("Floors")
	
	local baseData: BaseData = self.BaseData 
	local unlockedFloors: number = baseData.unlockedFloors
	
	for _, floorFolder in floorsContainer:GetChildren() do
		local floorIndex = tonumber(floorFolder.Name)
		if not floorIndex then warn("[_SetupFloors] invalid floor index: ", floorIndex) continue end
		
		local floorData: FloorData? = baseData.floors[floorIndex]
		
		local floor: Floor = self.Trove:Add(Floor.new(self, floorIndex, floorFolder, floorData))
		self.Floors[floorIndex] = floor
	end
end

function Base._Refresh(self: Base)
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:WaitForChild("Base")
	local components: Folder = baseModel:WaitForChild("Components")
	
	local baseData: BaseData = self.BaseData 
	
	local eggCollector: Folder = components.EggCollector
	eggCollector:SetAttribute("CrateValue", baseData and baseData.crateValue or nil)
	eggCollector:SetAttribute("EggsCollected", baseData and baseData.eggsCollected or nil)
end

--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function Base.IncrementCrateValue(self: Base, addedMoney: number)
	local baseData: BaseData = self.BaseData 
	baseData.crateValue += math.max(addedMoney, 0)
	baseData.eggsCollected += 1
	self:_Refresh()
end

function Base.SellCrates(self: Base, source: string)
	local baseData: BaseData = self.BaseData 
	local earnings = 0
	
	if source == "EggCollector" then
		earnings = baseData.crateValue or 0
		baseData.eggsCollected = 0
		baseData.crateValue = 0
	else
		return
	end
	
	if earnings <= 0 then return nil end
	DataService:IncrementCurrency(self.Owner, "Money", earnings)
	self:_Refresh()
end

function Base.Destroy(self: Base)
	self.Trove:Destroy()
	self.BaseFolder:SetAttribute("Owner", nil)
	print("[Base] base object destroyed:", self.BaseFolder.Name)
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------


return Base
