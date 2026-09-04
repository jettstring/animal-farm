local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

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

function Base.new(owner: Player, baseFolder: Folder, services: any)
	local self = setmetatable({}, Base)
	self.Services = services
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
	
	print("[Base] Created base object:", self)
	return self
end

function Base:_setup()
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
	local profile: Profile = self.Services.DataService:GetProfile(owner)
	if not profile then warn("[_Setup] No profile found for player", owner) end
	local baseData: BaseData = profile.base
	self.BaseData = baseData
	
	-- setup components
	self.RollStand = self.Trove:Add(RollStand.new(self, self.Services))
	self:_setupFloors()
	
	baseFolder:SetAttribute("Owner", owner.Name)
	self.State.Active = true
	
	return self
end


function Base:_setupFloors()
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:WaitForChild("Base")
	local floorsContainer: Folder = baseModel:WaitForChild("Floors")
	
	local baseData: BaseData = self.BaseData 
	local unlockedFloors: number = baseData.unlockedFloors
	
	for _, floorFolder in floorsContainer:GetChildren() do
		local floorIndex = tonumber(floorFolder.Name)
		if not floorIndex then warn("[_SetupFloors] invalid floor index: ", floorIndex) continue end
		
		local floorData: FloorData? = baseData.floors[floorIndex]
		
		local floor: Floor = self.Trove:Add(Floor.new(self, floorIndex, floorFolder, floorData, self.Services))
		self.Floors[floorIndex] = floor
		
		if floorIndex <= unlockedFloors then
			floor:Activate()
		end
	end
end

--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function Base:Roll()

end

function Base:Destroy()
	self.Trove:Destroy()
	self.BaseFolder:SetAttribute("Owner", nil)
	print("[Base] base object destroyed:", self.BaseFolder.Name)
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------


export type Base = typeof(setmetatable({} :: {
	Owner: Player,
	BaseFolder: Folder,
	BaseData: BaseData,
	RollStand: RollStand,
	Floors: {[number]: Floor}
	
}, Base))

return Base
