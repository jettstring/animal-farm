local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)

local Assets = ReplicatedStorage:WaitForChild("Assets")

-- Base Assets
local BaseAssets = Assets:WaitForChild("Base")
local Base = require(BaseAssets.Base)
local BaseFolders = workspace.Bases


local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type BaseData = ProfileTemplate.BaseData
type FloorData = ProfileTemplate.FloorData
type ShopData = ProfileTemplate.ShopData
type AnimalData = ProfileTemplate.AnimalData

type Base = Base.Base

--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseService = {}
BaseService.Services = {}
BaseService.Signals = {}

BaseService.ClaimedBases = {} :: {[Folder]: Player}
BaseService.PlayerBases = {} :: {[Player]: Base}


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function _cleanupBase(baseFolder: Folder)
	local baseModel: Model = baseFolder.Base
	local spawnLocation: SpawnLocation = baseModel.SpawnLocation
	
	
	-- hide floors
	local floorsContainer = baseModel.Floors
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		BaseUtil.showInstance(floorFolder, false)
	end
	
	-- hide components
	BaseUtil.showInstance(baseModel.Components, false)
	
	
	
end


--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------


function BaseService.AssignBase(self: BaseService, player: Player)
	if not player then return end
	
	-- already assigned
	if self.PlayerBases[player] then
		warn("[AssignBase] player already assigned a base")
		return
	end
	
	-- find available base
	for i = 1, #BaseFolders:GetChildren() do
		local baseFolder = BaseFolders:FindFirstChild(i)
		if not baseFolder then continue end
		
		-- check if claimed by someone else
		local owner = self.ClaimedBases[baseFolder]
		if owner then continue end
		
		local base: Base? = Base.new(player, baseFolder, self.Services)
		if not base then
			warn("[AssignBase] failed to create base for player", player)
			return
		end
		self.ClaimedBases[baseFolder] = player
		self.PlayerBases[player] = base
		player:SetAttribute("BaseAssigned", i) 
		
		print("[AssignBase] assigned base to player", player)
		return
	end
end

function BaseService.RemoveBase(self: BaseService, player: Player)
	local baseFolder: number? = player:GetAttribute("BaseAssigned") and BaseFolders:FindFirstChild(player:GetAttribute("BaseAssigned"))
	if baseFolder then
		self.ClaimedBases[baseFolder] = nil
	end

	local base: Base = self.PlayerBases[player]
	if base then
		base:Destroy()
		self.PlayerBases[player] = nil 
	end
	
	player:SetAttribute("BaseAssigned", nil)
	
	_cleanupBase(baseFolder)
	
	print("[RemoveBase] removed base for", player)
end


--------------------------------------------------
-- MAIN --
--------------------------------------------------

function BaseService.Init(self: BaseService, services)
	self.Services = services
	
	for _, baseFolder in BaseFolders:GetChildren() do
		_cleanupBase(baseFolder)
	end
end

function BaseService.Start(self: BaseService)
	self.Services.DataService.Signals.DataLoaded:Connect(function(player: Player)
		self:AssignBase(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		self:RemoveBase(player)
	end)
	
	
	
end

type BaseService = typeof(BaseService) & {}

return BaseService