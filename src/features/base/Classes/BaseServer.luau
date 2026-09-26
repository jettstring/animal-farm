local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES --
--------------------------------------------------

-- Services
local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.Modules.BaseTypes)

-- Classes
local RollStandServer = require(ServerScriptService.Features.Base.Classes.RollStandServer)
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)
local DroneServer = require(ServerScriptService.Features.Base.Classes.DroneServer)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	BuyFloor = remotesFolder.Base.BuyFloor :: RemoteEvent,
}

--------------------------------------------------
-- TYPES --
--------------------------------------------------

type FloorData = DataTemplate.FloorData
type CollectedEgg = BaseTypes.CollectedEgg

type RollStandServer = RollStandServer.RollStandServer
type AnimalStandServer = AnimalStandServer.AnimalStandServer
type DroneServer = DroneServer.DroneServer

type Floor = {
	Folder: Folder,
	AnimalStands: { [number]: AnimalStandServer }?,
	Drone: DroneServer?,
}

--------------------------------------------------
-- MAIN --
--------------------------------------------------

local BaseServer = {}
BaseServer.__index = BaseServer

type self = {
	Trove: Trove.Trove,
	Owner: Player,
	BaseFolder: Folder,
	BaseData: Scribe.PlayerData<typeof(DataTemplate.base)>,
	RollStand: RollStandServer,
	Floors: { [number]: Floor },
	EggQueue: { CollectedEgg }
}


export type BaseServer = typeof(setmetatable({} :: self, BaseServer))

function BaseServer.new(owner: Player, baseFolder: Folder): BaseServer
	local self = setmetatable({} :: self, BaseServer)
	self.Trove = Trove.new()

	self.State = {
		Active = false,
	}

	self.Owner = owner
	self.BaseFolder = baseFolder
	self.BaseData = Data[owner].base
	self.Floors = {}
	self.EggQueue = {}

	self:_setup()
	if not self.State.Active then
		warn("BaseServer is not active, destroying")
		self:Destroy()
		return nil
	end

	self:_Refresh()

	print("[BaseServer] Created base object:", self)
	return self
end

function BaseServer._setup(self: BaseServer)
	local owner: Player = self.Owner
	local baseFolder = self.BaseFolder :: Folder
	local baseModel = baseFolder.Base :: Model
	local components = baseModel.Components :: Folder
	local baseData = self.BaseData

	-- assign spawn location
	local spawnLocation = baseModel:WaitForChild("SpawnLocation")
	owner.RespawnLocation = spawnLocation
	if owner.Character then
		owner.Character:MoveTo(spawnLocation.Position + Vector3.new(0, 5, 0))
	end

	-- setup floors
	for _, floorFolder in baseModel.Floors:GetChildren() do
		local floorIndex = tonumber(floorFolder.Name)
		if not floorIndex then continue end

		self.Floors[floorIndex] = {
			Folder = floorFolder,
			AnimalStands = {},
			Drone = nil,
		}

		if self:OwnsFloor(floorIndex) then
			self:buildFloor(floorIndex)
		else
			-- BaseServiceUtils.showInstance(floorFolder.Model, false)
			floorFolder:SetAttribute("Active", false)
		end
	end

	-- setup components
	self.RollStand = self.Trove:Add(RollStandServer.new(owner, components.RollStand, self.BaseData.rollStandData))

	baseFolder:SetAttribute("Owner", owner.Name)
	self.State.Active = true


	-- Drone tick
	self.Trove:Add(RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()

		for _, floor in self.Floors do
			if not floor.Drone then continue end
			local collected = floor.Drone:update(now)
			if collected then
				table.insert(self.EggQueue, collected)
			end
		end

		self:collectQueue(now)
	end))

	return self
end

function BaseServer.buildFloor(self: BaseServer, floorIndex: number)
	local floor = self.Floors[floorIndex]
	if not floor then
		warn("[buildFloor] missing base floor table for" , floorIndex)
		return
	end

	-- initalize floor data
	local floorData = self.BaseData.floors[floorIndex]
	if floorData.Get() == nil then
		floorData.Set({
			animalStands = {},
			upgrades = {},
		})
	end

	-- setup animal stands
	for _, standFolder: Folder in floor.Folder.AnimalStands:GetChildren() do
		local standIndex = tonumber(standFolder.Name)
		if not standIndex then continue end
		
		if floor.AnimalStands[standIndex] then
			warn("[buildFloor] duplicate stand index: ", standIndex)
			continue
		end

		local standData = floorData.animalStands[standIndex]
		if standData.Get() == nil then
			standData.Set({
				unlocked = false,
				occupant = nil
			})
		end

		floor.AnimalStands[standIndex] = self.Trove:Add(AnimalStandServer.new(self.Owner, floorIndex, standIndex, standFolder, standData))
	end

	-- setup drone
	floor.Drone = self.Trove:Add(DroneServer.new(floor.Folder, floor.AnimalStands, floorData.upgrades))

	floor.Folder:SetAttribute("Active",  true)
	BaseServiceUtils.showInstance(floor.Folder.Model, true)
end


function BaseServer._Refresh(self: BaseServer)
	local baseFolder = self.BaseFolder
	local baseModel = baseFolder:WaitForChild("Base")
	local components: Folder = baseModel:WaitForChild("Components")

	local baseData = self.BaseData
	local eggCollector: Folder = components.EggCollector
	eggCollector:SetAttribute("CrateValue", baseData.crateValue.Get() or nil)
	eggCollector:SetAttribute("EggsCollected", baseData.eggsCollected.Get() or nil)
end

--------------------------------------------------
-- ACTIONS --
--------------------------------------------------

function BaseServer.UnlockNextFloor(self: BaseServer): boolean
	local nextIndex = self.BaseData.unlockedFloors.Get() + 1
	local floor = self.Floors[nextIndex]
	if not floor then
		return false
	end

	self.BaseData.unlockedFloors.Increment(1)

	remotes.BuyFloor:FireClient(self.Owner, nextIndex)
	self.Trove:Add(task.delay(3, function()
		self:buildFloor(nextIndex)
	end))

	return true
end

function BaseServer.collectQueue(self: BaseServer, now: number)
	if not now then return end
	for i, egg in self.EggQueue do
		if egg.collectTimestamp <= now then
			self:IncrementCrateValue(egg.earnings)
			table.remove(self.EggQueue, i)
		end
	end
end

function BaseServer.IncrementCrateValue(self: BaseServer, addedMoney: number)
	self.BaseData.crateValue.Increment(addedMoney)
	self.BaseData.eggsCollected.Increment(1)
	self:_Refresh()
end

function BaseServer.SellCrates(self: BaseServer, source: string)
	local baseData = self.BaseData
	local earnings = 0

	if source == "EggCollector" then
		earnings = baseData.crateValue.Get() or 0
		baseData.eggsCollected.Set(0)
		baseData.crateValue.Set(0)
	else
		return
	end

	if earnings <= 0 then
		return
	end

	Data[self.Owner].currency.Money.Increment(earnings, {
		TransactionType = Enum.AnalyticsEconomyTransactionType.Gameplay,
		ItemSku = "Sell Crates"
	})

	self:_Refresh()
end

function BaseServer.Destroy(self: BaseServer)
	self.Trove:Destroy()
	self.BaseFolder:SetAttribute("Owner", nil)

	-- clear floor attributes
	for _, floor in self.Floors do
		for attribute, _ in floor.Folder:GetAttributes() do
			floor.Folder:SetAttribute(attribute, nil)
		end
	end

	print("[BaseServer] base object destroyed:", self.BaseFolder.Name)
end

--------------------------------------------------
-- HELPERS --
--------------------------------------------------

function BaseServer.OwnsFloor(self: BaseServer, floorIndex: number): boolean
	return floorIndex <= self.BaseData.unlockedFloors.Get()
end


return BaseServer
