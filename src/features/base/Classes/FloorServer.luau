local EncodingService = game:GetService("EncodingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)

-- Classes
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)


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

type FloorData = DataTemplate.FloorData
type AnimalData = DataTemplate.AnimalData
type StandData = DataTemplate.StandData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

type AnimalStandServer = AnimalStandServer.AnimalStandServer

--------------------------------------------------
-- MAIN --
--------------------------------------------------

local FloorServer = {}
FloorServer.__index = FloorServer

type self = {
	Trove: Trove.Trove,
	Services: any,
	Owner: Player,
	Unlocked: boolean,
	FloorIndex: number,
	FloorFolder: Folder,
	FloorData: Scribe.PlayerData<FloorData>,
	AnimalStands: { [number]: AnimalStandServer },
	FloorThread: thread?,
	DroneIndex: number?,
	DroneDirection: number?,
}

export type FloorServer = typeof(setmetatable({} :: self, FloorServer))

function FloorServer.new(owner: Player, floorIndex: number, floorFolder: Folder, floorData: Scribe.PlayerData<FloorData>, isUnlocked: boolean): FloorServer
	local self = setmetatable({} :: self, FloorServer)

	self.Trove = Trove.new()
	self.Owner = owner
	self.Unlocked = isUnlocked
	self.FloorIndex = floorIndex
	self.FloorData = floorData
	self.FloorFolder = floorFolder
	self.AnimalStands = {}
	self.FloorThread = nil

	if isUnlocked then
		self:_buildStands()
	end
	self:_Refresh()

	return self
end

function FloorServer._Refresh(self: FloorServer)
	local ownsFloor = self.Unlocked
	local floorFolder: Folder = self.FloorFolder
	local model: Folder = floorFolder.Model

	BaseServiceUtils.showInstance(model, ownsFloor)
	floorFolder:SetAttribute("Active", ownsFloor)
end

function FloorServer._buildStands(self: FloorServer)
	local floorFolder: Folder = self.FloorFolder 
	local standsContainer = floorFolder.AnimalStands
	for _, standFolder in standsContainer:GetChildren() do
		local standIndex = tonumber(standFolder.Name)
		if not standIndex then continue end

		if self.AnimalStands[standIndex] then
			warn("[_buildStands] duplicate stand index: ", standIndex)
			continue
		end

		local standData = self.FloorData.animalStands[standIndex]
		if standData.Get() == nil then
			standData.Set({
				unlocked = false,
				occupant = nil
			})
		end

		local animalStand = AnimalStandServer.new(self.Owner, self.FloorIndex, standIndex, standFolder, standData)
		self.AnimalStands[standIndex] = animalStand
		self.Trove:Add(animalStand)
	end

	--self:_startLoop()
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

function FloorServer.Activate(self: FloorServer)
	if self.Unlocked then return end
	self.Unlocked = true
	
	-- fire owner to reveal floor
	remotes.BuyFloor:FireClient(self.Owner, self.FloorIndex)

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



return FloorServer
