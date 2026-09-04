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

function Floor.new(base: any, floorIndex: number, floorFolder: Folder, floorData: FloorData?, services: any)
	local self = setmetatable({}, Floor)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Base = base
	self.FloorIndex = floorIndex
	self.FloorData = floorData
	self.FloorFolder = floorFolder
	self.AnimalStands = {}
	
	self.Active = false
	
	
	return self
end
   
--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function Floor:Activate()
	if self.Active then return end
	
	local floorFolder: Folder = self.FloorFolder
	
	-- show 
	local model: Folder = floorFolder.Model
	BaseUtil.showInstance(model, true)
	
	
	local floorData: FloorData = self.FloorData
	if not floorData then
		local baseData: BaseData = self.Base.BaseData
		baseData.floors[self.FloorIndex] = {
			animalStands = {},
			upgrades = {},
		}
		self.FloorData = baseData.floors[self.FloorIndex]		
		floorData = self.FloorData
	end
	
	-- hydrate stands
	local standsContainer = floorFolder.AnimalStands
	for _, standFolder in standsContainer:GetChildren() do
		local standIndex = tonumber(standFolder.Name)
		if not standIndex then warn("[Floor.new] invalid stand index: ", standIndex) continue end

		if self.AnimalStands[standIndex] then warn("[Floor.new] duplicate stand index: ", standIndex) continue end

		local standData: AnimalStand? = floorData.animalStands[standIndex]
		self.AnimalStands[standIndex] = self.Trove:Add(AnimalStand.new(self, standIndex, standFolder, standData, self.Services))
	end
	
	self.FloorFolder:SetAttribute("Active", true)
	
	self.Active = true
end

function Floor:Unlock()
	if self.Active then return end
	
	-- fire owner to reveal floor
	local owner: Player = self.Base.Owner
	remotes.BuyFloor:FireClient(owner, self.FloorIndex)
	
	-- activate
	task.delay(2, function()
		self:Activate()
	end)
end

function Floor:Destroy()
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

export type Floor = typeof(setmetatable({} :: {
	Trove: any,
	Services: any,
	Base: any,
	FloorIndex: number,
	FloorFolder: Folder,
	FloorData: FloorData?,
	AnimalStands: {[number]: AnimalStand},
	Active: boolean,
	
}, Floor))

return Floor
