local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Trove = require(ReplicatedStorage.Packages.Trove)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)

-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local AnimalUtil = require(Utils.AnimalUtil)

local Assets = ReplicatedStorage:FindFirstChild("Assets")

-- Base Assets
local BaseAssets = Assets:FindFirstChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions


-------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate
type RollData = ProfileTemplate.RollData

type AnimalDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation


--------------------------------------------------
-- MAIN -- 
--------------------------------------------------

local RollStand = {}
RollStand.__index = RollStand

function RollStand.new(base: any, services: any)
	local self = setmetatable({}, RollStand)
	self.Services = services
	self.Trove = Trove.new()
	
	self.Base = base
	
	self:_Refresh()
	
	return self
end
   
--------------------------------------------------
-- ACTIONS -- 
--------------------------------------------------

function RollStand:Roll()
	local rollData: RollData = self.Base.BaseData.rollData
	local unlockedCount = rollData.unlockedCount
	local playerLuck = self:GetRollLuck()

	for slotIndex = 1, unlockedCount do
		if not rollData.slotData[slotIndex] then rollData.slotData[slotIndex] = {} end
		local slotData = rollData.slotData[slotIndex]
		
		-- get result
		local result = AnimalUtil.rollAnimalResult(playerLuck)
		if not result then warn("[Roll] bad result: ", result) continue end
		
		slotData.definitionKey = result
	end
	
	self:_Refresh()
end

function RollStand:BuySlotAnimal(slotIndex: number)
	local owner: Player = self.Base.Owner
	local profile: Profile = self.Services.DataService:GetProfile(owner)
	if not profile then warn("[BuySlotAnimal] No profile found for player:", owner) return end
	
	local rollData: RollData = profile.base.rollData
	local slotData = rollData and rollData.slotData[slotIndex]
	if not slotData or not slotData.definitionKey then
		warn("[BuySlotAnimal] invalid slotData: ", slotData)
		return
	end

	local animalKey = AnimalUtil.generateAnimalKey(slotData)
	if not animalKey then 
		warn("[BuySlotAnimal] invalid animalKey: ", animalKey)
		return
	end

	local cost = 100 -- TODO: derive cost from AnimalUtil
	if profile.currency.Money <= cost then
		self.Services.NotificationService:Error(owner, "Cannot buy!")
		return
	end
	
	local success = self.Services.AnimalService:GiveAnimal(owner, slotData)
	if not success then
		warn("[BuySlotAnimal] failed to give animal: ", success)
		return
	end
	
	self.Services.DataService:IncrementCurrency(owner, "Money", -cost, "Buy Animal", false)
end

function RollStand:Destroy()
	self.Trove:Destroy()
end

--------------------------------------------------
-- HELPERS -- 
--------------------------------------------------

function RollStand:GetRollLuck(): number
	local owner: Player = self.Base.Owner
	
	local total = 1 
	
	-- roll luck upgrade
	local rollData: RollData = self.Base.BaseData.rollData
	local rollLuck = rollData.rollLuck
	total += math.max(rollLuck, 0)
	
	return total
end

function RollStand:_Refresh()
	local baseFolder: Folder = self.Base.BaseFolder
	local baseModel: Model = baseFolder:WaitForChild("Base")
	local container: Folder = baseModel.Components.RollStand
	local slots: Folder = container.Slots

	local rollData: RollData = self.Base.BaseData.rollData
	local unlockedCount = rollData.unlockedCount
	local rollLuck = rollData.rollLuck
	
	-- iterate through stands
	for _, slot in slots:GetChildren() do
		local slotIndex = tonumber(slot.Name)
		local model = slot:FindFirstChild("Model")
		
		local available = slotIndex <= unlockedCount
		slot:SetAttribute("Available", available)
		
		if available then
			local slotData = rollData.slotData[slotIndex]
			local definitionKey = slotData and slotData.definitionKey
			slot:SetAttribute("DefinitionKey", definitionKey)
			
		else
			slot:SetAttribute("DefinitionKey", nil)
			
		end
		
		-- show/hide slot
		for _, basePart: BasePart in model:QueryDescendants("BasePart") do
			basePart.Transparency = (available and 0) or 1
			basePart.CanCollide = available
		end
	end
	
end


export type RollStand = typeof(setmetatable({} :: {
	Trove: any,
	Services: any,
	Base: any,
	
}, RollStand))

return RollStand
