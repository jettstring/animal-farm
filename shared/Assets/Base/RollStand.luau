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

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local RollStand = {}
RollStand.__index = RollStand

function RollStand.new(base: any, services: any)
	local self = setmetatable({}, RollStand)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Base = base
	self.RollStandData = base.BaseData.rollStands
	
	self:_refresh()
	
	task.spawn(function()
		wait(3)
		self:Roll()
	end)
	
	return self
end
   


--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function RollStand:Roll()
	local playerLuck = self:GetRollLuck()
	local result = AnimalUtil.rollAnimalResult(playerLuck)
	print("Rolled:", result)
end

function RollStand:Destroy()
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

function RollStand:GetRollLuck(): number
	local owner: Player = self.Base.Owner
	local total = 1
	
	return total
end

function RollStand:_refresh()

end


export type RollStand = typeof(setmetatable({} :: {
	Owner: Player,
	
}, RollStand))

return RollStand
