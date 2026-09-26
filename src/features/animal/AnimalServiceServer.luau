local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local AnimalServiceUtils = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceUtils)

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type AnimalData = DataTemplate.AnimalData

--------------------------------------------------
-- STATE --
--------------------------------------------------
local AnimalServiceServer = {}
AnimalServiceServer.Services = {}
AnimalServiceServer.Signals = {}
AnimalServiceServer.AnimalTools = {} :: {[Player]: {[string]: Tool}}


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function _playerAdded(player: Player)
	local data, reason = Data.WaitForData(player)
	if not data then
		warn("Could not load player data:", reason)
		return
	end
	
	player.CharacterAdded:Connect(function()
		AnimalServiceServer.AnimalTools[player] = nil
		AnimalServiceServer:_HydrateTools(player)
	end)
	if player.Character then
		print("GIVING ANIMAL TOOLS")
		AnimalServiceServer:_HydrateTools(player)
	end
end

local function _playerRemoved(player: Player)
	AnimalServiceServer.AnimalTools[player] = nil
end


--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function AnimalServiceServer.GetEquippedAnimalTool(self: AnimalServiceServer, player: Player): Tool?
	return player and player.Character and player.Character:FindFirstChild("AnimalTool")
end

function AnimalServiceServer.GiveAnimal(self: AnimalServiceServer, player: Player, animalData: AnimalData): boolean
	if not animalData or not animalData.definitionKey then warn("[GiveAnimal] invalid animalData: ", animalData); return false end
	
	local animalKey = AnimalServiceUtils.generateAnimalKey(animalData)
	if not animalKey then warn("[GiveAnimal] invalid animalKey: ", animalKey); return false end

	local playerData = Data[player]

	-- increment owned 
	playerData.inventory.animals[animalKey].Increment(1)

	-- mark index entry
	local entry = playerData.index.animals[animalData.definitionKey]
	if entry.Get() == nil then
		entry.Set({})
	end
	if animalData.mutation then
		entry[animalData.mutation].Get()
	end
	
	self:CreateAnimalTool(player, animalKey)
	
	return true
end

function AnimalServiceServer.CreateAnimalTool(self: AnimalServiceServer, player: Player, animalKey: string): Tool?
	local playerData = Data[player]
	
	-- check if animalKey exists in profile
	local ownedAmount = playerData.inventory.animals[animalKey].Get()
	if not ownedAmount or ownedAmount < 1 then
		warn("[CreateAnimalTool] player does not own animalKey: ", animalKey)
		return nil
	end
	
	local animalData = animalKey and AnimalServiceUtils.getAnimalData(animalKey)
	if not animalData then warn("[CreateAnimalTool] invalid animalData: ", animalData); return end
	
	local character = player.Character
	if not character then return end
	
	-- check if player already has a tool for this animalKey
	local existingTool: Tool? = self.AnimalTools[player] and self.AnimalTools[player][animalKey]
	if existingTool and existingTool.Parent then
		self:UpdateAnimalTool(player, animalKey)
		return nil
	end
	
	-- create new tool 
	local tool = Instance.new("Tool")
	tool:AddTag("AnimalTool")
	tool.Name = "AnimalTool"
	tool.Grip = CFrame.new(0, 0, 1)
	tool.CanBeDropped = false
	tool:SetAttribute("AnimalKey", animalKey)
	tool:SetAttribute("Quantity", ownedAmount)
	
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Anchored = false
	handle.CanCollide = false
	handle.Parent = tool
	
	local animalModel = AnimalServiceUtils.getAnimalModel(animalData)
	animalModel:PivotTo(handle.CFrame)
	animalModel.Parent = tool
	
	for _, basePart: BasePart in animalModel:QueryDescendants("BasePart") do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = basePart
		weld.Parent = basePart
		basePart.Anchored = false
		basePart.CanCollide = false
		basePart.Massless = true
	end
	
	-- track
	self.AnimalTools[player] = self.AnimalTools[player] or {}
	self.AnimalTools[player][animalKey] = tool

	tool.Parent = player.Backpack
	
	return tool
end

function AnimalServiceServer.UpdateAnimalTool(self: AnimalServiceServer, player: Player, animalKey: string)
	local animals = Data[player].inventory.animals

	-- check if animalKey exists in profile
	local ownedAmount = animals[animalKey].Get()
	if not ownedAmount then warn("[UpdateAnimalTool] animalKey not found: ", animalKey) return end

	local animalData = animalKey and AnimalServiceUtils.getAnimalData(animalKey)
	if not animalData then warn("[UpdateAnimalTool] invalid animalData: ", animalData) return end

	local character = player.Character
	if not character then return end

	-- check if player already has a tool for this animalKey
	local existingTool: Tool? = self.AnimalTools[player] and self.AnimalTools[player][animalKey]
	if not existingTool then
		warn("[UpdateAnimalTool] no existing tool found for animalKey: ", animalKey)
		return
	end
	
	-- destroy if no more owned
	if ownedAmount < 1 then
		existingTool:Destroy()
		self.AnimalTools[player][animalKey] = nil
		animals[animalKey].Set(nil)
		return
	end
	
	existingTool:SetAttribute("Quantity", ownedAmount)
end

function AnimalServiceServer._HydrateTools(self: AnimalServiceServer, player: Player)
	local animals = Data[player].inventory.animals
	for animalKey, ownedAmount in animals.Get() do
		if ownedAmount < 1 then
			animals[animalKey].Set(nil)
			continue
		end
		self:CreateAnimalTool(player, animalKey)
	end
end

function AnimalServiceServer.discoveredAnimal(self: AnimalServiceServer, player: Player, animalKey: string): boolean
	return Data[player] and Data[player].index[animalKey]
end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function AnimalServiceServer.Init(self: AnimalServiceServer)

end

function AnimalServiceServer.Start(self: AnimalServiceServer)
	Players.PlayerAdded:Connect(_playerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(_playerAdded(player))
	end

	Players.PlayerRemoving:Connect(_playerRemoved)
end

type AnimalServiceServer = typeof(AnimalServiceServer) & {}

return AnimalServiceServer