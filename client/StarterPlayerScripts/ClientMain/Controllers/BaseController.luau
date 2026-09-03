 local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Abbreviate = require(ReplicatedStorage.Packages.Abbreviate)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local player = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RollAnimal = remotesFolder.Base.RollAnimal,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------


--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseController = {}
BaseController.Controllers = {}
BaseController.Signals = {}

--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function mountRollStand(baseFolder: Folder, isOwner: boolean)
	local trove = Trove.new()
	
	local baseModel = baseFolder:WaitForChild("Base")
	local components = baseModel:WaitForChild("Components")
	local rollStand = components:WaitForChild("RollStand")
	local slots: Folder = rollStand:WaitForChild("Slots")
	local interactPart = rollStand:WaitForChild("Interact")
	local leverModel = rollStand:WaitForChild("Lever")
	local rollPrompt: ProximityPrompt = interactPart:WaitForChild("RollPrompt")
	
	-- roll prompt
	rollPrompt.Enabled = isOwner
	if isOwner then
		trove:Add(rollPrompt.Triggered:Connect(function()
			remotes.RollAnimal:FireServer()
		end))
	end
	
	
	
	return function() trove:Destroy() end
end

local function mountBases()
	Observers.observeTag("Base", function(baseFolder: Folder)
		return Observers.observeAttribute(baseFolder, "Owner", function(ownerName)
			local trove = Trove.new()
			local isOwner = ownerName == player.Name
			
			-- base components
			trove:Add(mountRollStand(baseFolder, isOwner))
			
			
			return function() trove:Destroy() end
		end)
	end)
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function BaseController.PublicFoo(self: BaseController)

end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function BaseController.Init(self: BaseController, controllers)
	self.Controllers = controllers
	
end

function BaseController.Start(self: BaseController)
	
	mountBases()
end

type BaseController = typeof(BaseController) & {}


return BaseController