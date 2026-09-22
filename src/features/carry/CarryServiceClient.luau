local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Observers = require(ReplicatedStorage.Packages.Observers)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local player = Players.LocalPlayer

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------


--------------------------------------------------
-- STATE --
--------------------------------------------------
local CarryController = {}
CarryController.Controllers = {}
CarryController.Signals = {}

CarryController.source = nil :: string?

local crates: {Model} = {}
local crateModel: Model? = nil 
local count = 0

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function newCrate(): Model
	local crate = crateModel:Clone()
	local root = crate.PrimaryPart

	for _, part: BasePart in crate:QueryDescendants("BasePart") do
		part.CanCollide = false
		part.Massless = true

		if part ~= root then
			part.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = part
			w.Parent = part
		end
	end

	root.Anchored = true
	crate.Parent = workspace

	return crate
end

local function render()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not crateModel then return end

	-- crate new
	for i = #crates + 1, count do
		crates[i] = newCrate()
	end

	-- clear old
	for i = #crates, count + 1, -1 do
		crates[i]:Destroy()
		crates[i] = nil
	end

	for i, crate in crates do
		local root = crate.PrimaryPart
		local size = crate:GetExtentsSize()
		local weld: Weld = root:FindFirstChild("CarryWeld") or Instance.new("Weld")
		weld.Name = "CarryWeld"
		weld.Part0 = hrp
		weld.Part1 = root
		weld.C0 = CFrame.new(0, (i - 1) * size.Y, size.Z)
		root.Anchored = false     -- before the weld is parented
		weld.Parent = root
	end
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function CarryController.Carry(self: CarryController, source: string, model: Model, n: number)
	if not n or n <= 0 then return end
	self.source = source
	crateModel = model
	count = n
	player:SetAttribute("CarryingCrates", true)
	render()
end

function CarryController.Stop(self: CarryController)
	self.source = nil
	crateModel =  nil
	count = 0
	for _, crate in crates do
		crate:Destroy()
	end
	table.clear(crates)
	player:SetAttribute("CarryingCrates", false)
end

function CarryController.Take(self: CarryController): {Model}
	local copied = table.clone(crates)
	table.clear(crates)
	self:Stop()
	return copied
end

function CarryController.SetCrateCount(self: CarryController, n: number)
	count = n
	render()
end

function CarryController.IsCarrying(self: CarryController)
	return player:GetAttribute("CarryingCrates") == true
end


--------------------------------------------------
-- MAIN --
--------------------------------------------------

function CarryController.Init(self: CarryController, controllers)
	self.Controllers = controllers

end

function CarryController.Start(self: CarryController)
	
	Observers.observeCharacter(function(_, character)
		return function()
			self:Stop()
		end
	end, {player})
end

type CarryController = typeof(CarryController) & {}


return CarryController