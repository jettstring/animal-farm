local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Source.Features.Data.ProfileTemplate)

-- Classes
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

-- Base Assets
local Assets = ReplicatedStorage:FindFirstChild("Assets")

-- Animal Assets
local AnimalConfig = require(ReplicatedStorage.Source.Features.Animal.AnimalConfig)
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

type AnimalStandServer = AnimalStandServer.AnimalStandServer

--------------------------------------------------
-- MAIN --
--------------------------------------------------

local FloorServer = {}
FloorServer.__index = FloorServer

type self = {
	Trove: any,
	Services: any,
	Base: any,
	FloorIndex: number,
	FloorFolder: Folder,
	FloorData: FloorData?,
	AnimalStands: { [number]: AnimalStandServer },
	FloorThread: thread?,
	DroneIndex: number?,
	DroneDirection: number?,
}

export type FloorServer = typeof(setmetatable({} :: self, FloorServer))

function FloorServer.new(base: any, floorIndex: number, floorFolder: Folder, floorData: FloorData?): FloorServer
	local self = setmetatable({} :: self, FloorServer)
	self.Trove = Trove.new()

	self.Base = base
	self.FloorIndex = floorIndex
	self.FloorData = floorData
	self.FloorFolder = floorFolder
	self.AnimalStands = {}

	self.FloorThread = nil

	if self:OwnsFloor() then
		self:_buildStands()
	end

	self:_Refresh()

	return self
end

function FloorServer._Refresh(self: FloorServer)
	local floorFolder: Folder = self.FloorFolder
	local model: Folder = floorFolder.Model

	local ownsFloor = self:OwnsFloor()

	BaseUtil.showInstance(model, ownsFloor)
	floorFolder:SetAttribute("Active", ownsFloor)
	floorFolder:SetAttribute("DroneCollectTime", self:GetDroneCollectTime())
	floorFolder:SetAttribute("DroneStepTime", self:GetDroneStepTime())
end

function FloorServer._buildStands(self: FloorServer)
	local floorFolder: Folder = self.FloorFolder

	local floorData: FloorData = self.FloorData
	if not floorData then
		warn("[_buildStands] missing floor data")
		return
	end

	local standsContainer = floorFolder.AnimalStands
	for _, standFolder in standsContainer:GetChildren() do
		local standIndex = tonumber(standFolder.Name)
		if not standIndex then
			warn("[_buildStands] invalid stand index: ", standIndex)
			continue
		end

		if self.AnimalStands[standIndex] then
			warn("[_buildStands] duplicate stand index: ", standIndex)
			continue
		end

		floorData.animalStands[standIndex] = floorData.animalStands[standIndex]
			or {
				unlocked = false,
				occupant = nil,
			}
		local standData: StandData = floorData.animalStands[standIndex]

		self.AnimalStands[standIndex] = self.Trove:Add(AnimalStandServer.new(self, standIndex, standFolder, standData))
	end

	self:_startLoop()
end

function FloorServer._startLoop(self: FloorServer)
	local floorFolder: Folder = self.FloorFolder
	if self.FloorThread then
		warn("[_startLoop] floor thread already active!")
		return
	end

	self.DroneIndex = 1
	self.DroneDirection = 1

	self.FloorThread = self.Trove:Add(task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()

			local nearestStand = self.AnimalStands[self.DroneIndex]
			if nearestStand and nearestStand:IsEggReady(now) then
				floorFolder:SetAttribute("DroneVacuuming", true)

				-- collect egg
				task.wait(self:GetDroneCollectTime())
				nearestStand:CollectEgg()
				floorFolder:SetAttribute("DroneVacuuming", false)
				continue
			end

			-- check for ready stand ahead
			if not self:GetReadyAhead(self.DroneIndex, self.DroneDirection, now) then
				self.DroneDirection *= -1 -- reverse direction
				--print(string.format("[Floor %d] Reversing %s", self.FloorIndex, (math.sign(self.DroneDirection) == 1) and "Right" or "Left"))
				if not self:GetReadyAhead(self.DroneIndex, self.DroneDirection, now) then
					task.wait(0.5) -- nothing ready, reverse
					continue
				end
			end

			-- step
			self.DroneIndex += self.DroneDirection
			floorFolder:SetAttribute("DroneIndex", self.DroneIndex)
			print(string.format("[Floor %d] DroneIndex: %d", self.FloorIndex, self.DroneIndex))
			task.wait(self:GetDroneStepTime())
		end
	end))
end

--------------------------------------------------
-- ACTIONS --
--------------------------------------------------

function FloorServer.Unlock(self: FloorServer)
	local baseData: BaseData = self.Base.BaseData
	if self.FloorIndex ~= baseData.unlockedFloors + 1 then
		warn("Floor is not the next floor to be unlocked")
		return
	end

	baseData.unlockedFloors += 1
	baseData.floors[self.FloorIndex] = baseData.floors[self.FloorIndex]
		or { -- TODO: fix sparse numbered data structure
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

function FloorServer.Destroy(self: FloorServer)
	self.Trove:Destroy()

	-- clear attributes
	for attributeName, _ in self.FloorFolder:GetAttributes() do
		self.FloorFolder:SetAttribute(attributeName, nil)
	end
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function FloorServer.GetDroneCollectTime(self: FloorServer): number
	return 3 -- TODO multiply by speed ugprade
end

function FloorServer.GetDroneStepTime(self: FloorServer): number
	return 1 -- TODO multiply by speed ugprade
end

function FloorServer.GetReadyAhead(self: FloorServer, fromIndex, dir: number, now: number): AnimalStandServer?
	local i = fromIndex + dir
	while i >= 1 and i <= #self.AnimalStands do
		local stand = self.AnimalStands[i]
		if stand and stand:IsEggReady(now) then
			return stand
		end

		i += dir
	end

	return nil
end

function FloorServer.OwnsFloor(self: FloorServer): boolean
	local baseData: BaseData = self.Base.BaseData
	return self.FloorIndex <= baseData.unlockedFloors
end

return FloorServer
