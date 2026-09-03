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
	BuyAnimal = remotesFolder.Animal.RollAnimal
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

--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function _playerRemoved(player: Player)
	
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function AnimalService.GiveAnimal(self: AnimalService, player: Player, animalData: AnimalData)
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[GiveAnimal] No profile found for player:", player) return end
	
	
end

function AnimalService.CreateAnimalTool(self: AnimalService, player: Player, animalId: string, animalData: AnimalData)

end

function AnimalService._HydrateTools(self: AnimalService, player: Player)
	local profile: Profile = self.Services.DataService:GetProfile(player)
	if not profile then warn("[_HydrateTools] No profile found for player:", player) return end
	
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
			self:_HydrateTools(player)
		end)
		if player.Character then self:_HydrateTools(player) end
	end)
	
	Players.PlayerRemoving:Connect(_playerRemoved)
	
	
	
	remotes.RollAnimal.OnServerEvent:Connect(function(player: Player)
		local base: Base = self.Services.BaseService.PlayerBases[player]
		local rollStand = base and base.RollStand
		if not rollStand then warn("[onAttemptRoll] missing rollStand object") return end

		rollStand:Roll()
	end)
	
end

type AnimalService = typeof(AnimalService) & {}

return AnimalService