local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local inputs = ReplicatedStorage:WaitForChild("Inputs")
local interactionContext = inputs:WaitForChild("Interaction")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------


--------------------------------------------------
-- STATE --
--------------------------------------------------
local InteractionController = {}
InteractionController.Controllers = {}
InteractionController.Signals = {}

local callbacks: {[Instance]: (Instance) -> ()} = {}
local instances: {Instance} = {}

--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function _mountInteractions()
	
	local function resolveModel(hitPart: BasePart): Model?
		local current = hitPart
		while current do
			local hasCallback = callbacks[current]
			if hasCallback then
				return current
			end
			current = current.Parent
		end
		return nil
	end

	local function getInteractableFromMouse()
		local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = instances

		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if result and result.Instance then

			-- resolve resulting model
			local model = resolveModel(result.Instance)
			if model then
				return model
			else
				return nil
			end
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.new(1, 1, 1)

	local currentInteractable = nil
	RunService.RenderStepped:Connect(function()
		local model = getInteractableFromMouse()
		if model then
			currentInteractable = model

			mouse.Icon = "http://www.roblox.com/asset?id=105991732318156"

			highlight.Parent = model
			highlight.Adornee = model
			highlight.Enabled = true
		else
			currentInteractable = nil

			mouse.Icon = "rbxasset://SystemCursors/Arrow"

			highlight.Parent = nil
			highlight.Enabled = false
		end
	end)


	interactionContext.InteractModel.Pressed:Connect(function()
		if not currentInteractable then return end
		if callbacks[currentInteractable] then
			callbacks[currentInteractable](currentInteractable)
		end
	end)

	
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function InteractionController.Register(self: InteractionController, instance: Instance, callback: (Instance) -> ())
	callbacks[instance] = callback
	table.insert(instances, instance)
	
	return function()
		callbacks[instance] = nil
		local i = table.find(instances, instance)
		if i then table.remove(instances, i) end
	end
end


function InteractionController.Unregister(self: InteractionController, instance: Instance)
	callbacks[instance] = nil
	local i = table.find(instances, instance)
	if i then table.remove(instances, i) end
end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function InteractionController.Init(self: InteractionController, controllers)
	self.Controllers = controllers

	_mountInteractions()
end

function InteractionController.Start(self: InteractionController)
	
	
	
	local baseplate = workspace:WaitForChild("Baseplate")
	if baseplate then
		self:Register(baseplate, function()
			task.spawn(function()
				print("Interacted with ", baseplate)
				task.wait(2)
				self:Unregister(baseplate)
				print("unregistered callback!")
			end)
		end)
		
		
	end
end

type InteractionController = typeof(InteractionController) & {}


return InteractionController