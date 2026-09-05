local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:FindFirstChild("Assets")

-- Base Assets
local BaseAssets = Assets:FindFirstChild("Base")
local AnimalStand = require(BaseAssets.AnimalStand)

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyFloor = remotesFolder.Base.BuyFloor,
}

-------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type BaseData = ProfileTemplate.BaseData
type FloorData = ProfileTemplate.FloorData
type AnimalData = ProfileTemplate.AnimalData
type StandData = ProfileTemplate.StandData


type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

type AnimalStand = AnimalStand.AnimalStand


--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local Floor = {}
Floor.__index = Floor

type self = {
	Trove: any,
	Services: any,
	Base: any,
	FloorIndex: number,
	FloorFolder: Folder,
	FloorData: FloorData?,
	AnimalStands: {[number]: AnimalStand},
}

export type Floor = typeof(setmetatable({} :: self, Floor))


function Floor.new(base: any, floorIndex: number, floorFolder: Folder, floorData: FloorData?, services: any): Floor
	local self = setmetatable({} :: self, Floor)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Base = base
	self.FloorIndex = floorIndex
	self.FloorData = floorData
	self.FloorFolder = floorFolder
	self.AnimalStands = {}
	
	if self:OwnsFloor() then
		self:_buildStands()
	end
	
	self:_Refresh()
	
	return self
end
   
function Floor._Refresh(self: Floor)
	local floorFolder: Folder = self.FloorFolder
	local model: Folder = floorFolder.Model
	
	local ownsFloor = self:OwnsFloor()

	BaseUtil.showInstance(model, ownsFloor)
	self.FloorFolder:SetAttribute("Active", ownsFloor)
end

function Floor._buildStands(self: Floor)
	local floorFolder: Folder = self.FloorFolder
	
	local floorData: FloorData = self.FloorData
	if not floorData then
		warn("[_buildStands] missing floor data")
		return
	end
	
	local standsContainer = floorFolder.AnimalStands
	for _, standFolder in standsContainer:GetChildren() do
		local standIndex = tonumber(standFolder.Name)
		if not standIndex then warn("[_buildStands] invalid stand index: ", standIndex) continue end

		if self.AnimalStands[standIndex] then warn("[_buildStands] duplicate stand index: ", standIndex) continue end

		floorData.animalStands[standIndex] = floorData.animalStands[standIndex] or {
			unlocked = false,
			occupant = nil,
		}
		local standData: StandData = floorData.animalStands[standIndex]
		
		self.AnimalStands[standIndex] = self.Trove:Add(AnimalStand.new(self, standIndex, standFolder, standData, self.Services))
	end
end
   
--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function Floor.Unlock(self: Floor)
	local baseData: BaseData = self.Base.BaseData
	if self.FloorIndex ~= baseData.unlockedFloors + 1 then
		warn("Floor is not the next floor to be unlocked")
		return
	end
	
	baseData.unlockedFloors += 1
	baseData.floors[self.FloorIndex] = baseData.floors[self.FloorIndex] or { -- TODO: fix sparse numbered data structure 
		animalStands = {},
		upgrades = {},
	}
	self.FloorData = baseData.floors[self.FloorIndex]
	
	-- fire owner to reveal floor
	local owner: Player = self.Base.Owner
	remotes.BuyFloor:FireClient(owner, self.FloorIndex)
	
	-- activate
	self.Trove:Add(task.delay(3, function()
		self:_buildStands()
		self:_Refresh()
	end))
end

function Floor.Destroy(self: Floor)
	self.Trove:Destroy()
	
	-- clear attributes
	for attributeName, _ in self.FloorFolder:GetAttributes() do
		self.FloorFolder:SetAttribute(attributeName, nil)
	end
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

function Floor.OwnsFloor(self: Floor): boolean
	local baseData: BaseData = self.Base.BaseData
	return self.FloorIndex <= baseData.unlockedFloors
end

return Floor



