local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:FindFirstChild("Assets")

-- Base Assets
local BaseAssets = Assets:FindFirstChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions


-------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type StandData = ProfileTemplate.StandData
type AnimalData = ProfileTemplate.AnimalData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation


--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local AnimalStand = {}
AnimalStand.__index = AnimalStand

function AnimalStand.new(floor: any, standIndex: number, standFolder: Folder, standData: AnimalStand?, services: any)
	local self = setmetatable({}, AnimalStand)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Floor = floor
	self.StandIndex = standIndex
	self.StandFolder = standFolder
	self.StandData = standData
	
	
	
	return self
end


--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function AnimalStand:_Refresh()
	local standData: StandData? = self.StandData
	
end

function AnimalStand:Activate()
	
end

function AnimalStand:Destroy()
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

export type AnimalStand = typeof(setmetatable({} :: {
	Trove: any,
	Services: any,
	Floor: any,
	StandIndex: number,
	StandFolder: Folder,
	StandData: StandData?,
	
}, AnimalStand))

return AnimalStand
