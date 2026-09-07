local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:WaitForChild("Assets")

-- Base Assets
local BaseAssets = Assets:WaitForChild("Base")
local Base = require(BaseAssets.Base)

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RollAnimal = remotesFolder.Animal.RollAnimal,
	BuySlotAnimal = remotesFolder.Animal.BuySlotAnimal,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type AnimalData = ProfileTemplate.AnimalData

type Base = Base.Base

--------------------------------------------------
-- STATE --
--------------------------------------------------
local AnimalService = {}
AnimalService.Services = {}
AnimalService.Signals = {}
AnimalService.AnimalTools = {} :: {[Player]: {[string]: Tool}}


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function _playerRemoved(player: Player)
	AnimalService.AnimalTools[player] = nil
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------


function AnimalService.GiveAnimal(self: AnimalService, player: Player, animalData: AnimalData): boolean
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[GiveAnimal] No profile found for player:", player) return false end
	
	if not animalData or not animalData.definitionKey then warn("[GiveAnimal] invalid animalData: ", animalData) return false end
	
	local animalKey = AnimalUtil.generateAnimalKey(animalData)
	if not animalKey then warn("[GiveAnimal] invalid animalKey: ", animalKey) return false end
	
	-- save to profile
	profile.inventory.animals[animalKey] = (profile.inventory.animals[animalKey] or 0) + 1
	
	self:CreateAnimalTool(player, animalKey)
	
	return true
end

function AnimalService.CreateAnimalTool(self: AnimalService, player: Player, animalKey: string): Tool
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[CreateAnimalTool] No profile found for player:", player) return end
	
	-- check if animalKey exists in profile
	local ownedAmount = profile.inventory.animals[animalKey]
	if not ownedAmount then warn("[CreateAnimalTool] animalKey not found in profile: ", animalKey) return end
	
	if ownedAmount < 1 then
		warn("[CreateAnimalTool] player does not own animalKey: ", animalKey)
		return
	end
	
	local animalData = animalKey and AnimalUtil.getAnimalData(animalKey)
	if not animalData then warn("[CreateAnimalTool] invalid animalData: ", animalData) return end
	
	local character = player.Character
	if not character then return end
	
	-- check if player already has a tool for this animalKey
	local existingTool: Tool? = self.AnimalTools[player] and self.AnimalTools[player][animalKey]
	if existingTool and existingTool.Parent then
		self:UpdateAnimalTool(player, animalKey)
		return
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
	
	local animalModel = AnimalUtil.getAnimalModel(animalData)
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

function AnimalService.UpdateAnimalTool(self: AnimalService, player: Player, animalKey: string)
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[UpdateAnimalTool] No profile found for player:", player) return end

	-- check if animalKey exists in profile
	local ownedAmount = profile.inventory.animals[animalKey]
	if not ownedAmount then warn("[UpdateAnimalTool] animalKey not found in profile: ", animalKey) return end

	local animalData = animalKey and AnimalUtil.getAnimalData(animalKey)
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
		profile.inventory.animals[animalKey] = nil
		return
	end
	
	existingTool:SetAttribute("Quantity", ownedAmount)
end

function AnimalService._HydrateTools(self: AnimalService, player: Player)
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[_HydrateTools] No profile found for player:", player) return end

	for animalKey, ownedAmount in profile.inventory.animals do
		if ownedAmount < 1 then
			profile.inventory.animals[animalKey] = nil
			continue
		end
		
		self:CreateAnimalTool(player, animalKey)
	end
end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function AnimalService.Init(self: AnimalService, services)
	self.Services = services

end

function AnimalService.Start(self: AnimalService)
	self.Services.DataService.Signals.DataLoaded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			print("GIVING ANIMAL TOOLS")
			self.AnimalTools[player] = nil
			self:_HydrateTools(player)
		end)
		if player.Character then
			print("GIVING ANIMAL TOOLS")
			self:_HydrateTools(player)
		end
	end)
	
	Players.PlayerRemoving:Connect(_playerRemoved)
	
	
	
	remotes.RollAnimal.OnServerEvent:Connect(function(player: Player)
		local base: Base = self.Services.BaseService.PlayerBases[player]
		local rollStand = base and base.RollStand
		if not rollStand then warn("missing rollStand object") return end

		rollStand:Roll()
	end)
	
	remotes.BuySlotAnimal.OnServerEvent:Connect(function(player: Player, slotIndex: number)
		local base: Base = self.Services.BaseService.PlayerBases[player]
		local rollStand = base and base.RollStand 
		if not rollStand then warn("missing rollStand object") return end
		
		rollStand:BuySlotAnimal(slotIndex)
	end)
	
end

type AnimalService = typeof(AnimalService) & {}

return AnimalService