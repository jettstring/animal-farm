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

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate

type RollStand = RollStand.RollStand

--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local Base = {}
Base.__index = Base

function Base.new(owner: Player, baseFolder: Folder, services: any)
	local self = setmetatable({}, Base)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Owner = owner
	self.BaseFolder = baseFolder
	
	self.State = {
		Active = false,
	}
	
	self.BaseData = nil
	
	
	self:_setup()
	if not self.State.Active then
		warn("Base is not active, destroying")
		self:Destroy()
		return nil
	end
	
	print("[Base] Created base object:", self)
	return self
end

--------------------------------------------------
-- SETUP -- 
--------------------------------------------------

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
	self.RollStand = RollStand.new(self, self.sevices)
	self:_setupFloors()
	
	baseFolder:SetAttribute("Owner", owner.Name)
	self.State.Active = true
	return self
end





function Base:_setupFloors()
	local owner: Player = self.Owner
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:FindFirstChild("Base")
	local floorsFolder = baseModel:FindFirstChild("Floors")
	
	
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
	RollStand: RollStand
	
}, Base))

return Base
