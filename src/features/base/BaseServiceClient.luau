local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Abbreviate = require(ReplicatedStorage.Source.Core.Util.Abbreviate)
local VfxUtils = require(ReplicatedStorage.Source.Core.Util.VfxUtils)

local function quadraticBezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	return p0:Lerp(p1, t):Lerp(p1:Lerp(p2, t), t)
end

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Controllers
local CarryServiceClient = require(ReplicatedStorage.Source.Features.Carry.CarryServiceClient)
local InteractionServiceClient = require(ReplicatedStorage.Source.Features.Interaction.InteractionServiceClient)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Source.Features.Data.ProfileTemplate)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.BaseTypes)
local AnimalBillboard = require(ReplicatedStorage.Source.Features.Animal.Classes.AnimalBillboard)

-- Utils
local BaseServiceUtils = require(ReplicatedStorage.Source.Features.Base.BaseServiceUtils)
local AnimalServiceUtils = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceUtils)

-- Base Assets
local Assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local BaseAssets = Assets:WaitForChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(ReplicatedStorage.Source.Features.Animal.AnimalConfig)
local AnimalDefinitions = AnimalConfig.AnimalDefinitions
local MutationGradients: Folder = AnimalAssets:WaitForChild("MutationGradients")


local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	RollAnimal = remotesFolder.Base.RollAnimal,
	BuySlotAnimal = remotesFolder.Base.BuySlotAnimal,
	StealSlotAnimal = remotesFolder.Base.StealSlotAnimal,
	BuyFloor = remotesFolder.Base.BuyFloor,
	BuyAnimalStand = remotesFolder.Base.BuyAnimalStand,
	PlaceAnimal = remotesFolder.Base.PlaceAnimal,
	BuyAnimalLevel = remotesFolder.Base.BuyAnimalLevel,
	RemoveAnimal = remotesFolder.Base.RemoveAnimal,
	SellEggs = remotesFolder.Base.SellEggs,
}

--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Trove = Trove.Trove

type AnimationDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

type Profile = ProfileTemplate.ProfileTemplate
type AnimalData = ProfileTemplate.AnimalData

type SlotResult = BaseTypes.SlotResult
type RollResult = BaseTypes.RollResult

type AnimalBillboard = AnimalBillboard.AnimalBillboard

--------------------------------------------------
-- STATE --
--------------------------------------------------
local BaseController = {}
BaseController.Controllers = {}
BaseController.Signals = {}


local currentStand: Folder? = nil
local standDisplayTrove = Trove.new()


--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function playRollReveal(slotParts: {Part}, rollResults)
	
end

local function showStandDisplay(standFolder: Folder, floorIndex: number, isOwner: boolean)
	local trove: Trove = standDisplayTrove
	trove:Clean() -- remove previous billboard

	if currentStand == standFolder then
		currentStand = nil
		return
	end

	local standIndex = tonumber(standFolder.Name)
	local standModel: Model = standFolder:WaitForChild("StandModel")
	local animalMiddle: Part = standModel:WaitForChild("AnimalMiddle")

	local defKey = standFolder:GetAttribute("DefinitionKey")
	local animalDef: AnimationDefinition = defKey and AnimalDefinitions[defKey]
	if not animalDef then warn("[showStandDisplay] invalid animal definition key: ", defKey) return end

	local billboard = trove:Add(BaseAssets:FindFirstChild("StandBillboard"):Clone())
	local display = billboard.Display
	local nameLabel = display.NameLabel
	local levelLabel = display.LevelLabel
	local earningsLabel = display.EarningsLabel
	local modifiersDisplay = display.Modifiers
	local rarityLabel = modifiersDisplay.RarityLabel
	local options = display.Options
	local removeButton = options:FindFirstChild("Remove")
	local buy1Button = options:FindFirstChild("Buy1")
	local buy10Button = options:FindFirstChild("Buy10")

	nameLabel.Text = animalDef.displayName
	rarityLabel.Text = animalDef.rarity
	billboard.Adornee = animalMiddle
	billboard.Parent = playerGui   

	trove:Add(Observers.observeAttribute(standFolder, "Level", function(level: number)
		levelLabel.Text = string.format("Level %s", Abbreviate.AbbreviateNumber(level, 1))

		-- display level cost on buttons
		buy1Button.PriceLabel.Text  = "$" .. Abbreviate.AbbreviateNumber(AnimalServiceUtils.getLevelUpCost(defKey, level, 1), 1)
		buy10Button.PriceLabel.Text = "$" .. Abbreviate.AbbreviateNumber(AnimalServiceUtils.getLevelUpCost(defKey, level, 10), 1)

	end))

	local mutationLabelTrove = trove:Extend()
	trove:Add(Observers.observeAttribute(standFolder, "Mutation", function(mutation: string)
		mutationLabelTrove:Clean()

		local mutationLabel = mutationLabelTrove:Add(modifiersDisplay.UIListLayout.MutationLabel:Clone())
		if mutationLabel:FindFirstChildOfClass("UIGradient") then mutationLabel:FindFirstChildOfClass("UIGradient"):Destroy() end

		mutationLabel.Text = mutation

		local mutationGradient = MutationGradients:FindFirstChild(mutation) and MutationGradients:FindFirstChild(mutation):Clone()
		if mutationGradient then
			mutationGradient.Parent = mutationLabel
		end

		-- TODO: gradient effects
	end))

	trove:Add(Observers.observeAttribute(standFolder, "MoneyPerEgg", function(moneyPerEgg: number)
		earningsLabel.Text = string.format("$%s / Egg", Abbreviate.AbbreviateNumber(moneyPerEgg, 1))
	end))

	options.Visible = isOwner
	if isOwner then
		trove:Add(removeButton.Activated:Connect(function()
			remotes.RemoveAnimal:FireServer(floorIndex, standIndex)
		end))

		trove:Add(buy1Button.Activated:Connect(function()
			remotes.BuyAnimalLevel:FireServer(floorIndex, standIndex, 1)
		end))

		trove:Add(buy10Button.Activated:Connect(function()
			remotes.BuyAnimalLevel:FireServer(floorIndex, standIndex, 10)
		end))
	end

	currentStand = standFolder

	return function() trove:Clean() end
end

local function mountAnimalStand(standFolder: Folder, floorIndex: number, owner: Player)
	local standIndex = tonumber(standFolder.Name)
	local isOwner = owner == player
	local standModel: Model = standFolder:WaitForChild("StandModel")
	local animalMiddle: Part = standModel:WaitForChild("AnimalMiddle")
	local statusIndicator: Part = standModel:WaitForChild("StatusIndicator")
	local eggPositionsContainer: Folder = standModel:WaitForChild("EggPositions")
	
	
	return Observers.observeAttribute(standFolder, "Active", function(isActive: boolean)
		local trove = Trove.new()
		
		if isActive then
			trove:Add(InteractionServiceClient:Register(standModel, function()
				if standFolder:GetAttribute("DefinitionKey") then
					showStandDisplay(standFolder, floorIndex, isOwner)
				elseif isOwner and player.Character and player.Character:FindFirstChild("AnimalTool") then
					remotes.PlaceAnimal:FireServer(floorIndex, standIndex)
				end
			end))
			
			trove:Add(Observers.observeAttribute(standFolder, "DefinitionKey", function(definitionKey: string)
				local defTrove = Trove.new()
				local renderTrove = defTrove:Extend()
				
				local function updateRender()
					renderTrove:Clean()
					
					local animalData: AnimalData = {
						definitionKey = definitionKey,
						level = standFolder:GetAttribute("Level") or 1,
						mutation = standFolder:GetAttribute("Mutation") or nil,
					}
					
					-- should the rendering of animal (model, animation connections, effects, etc) be on its own trove?
					local animalModel = renderTrove:Add(AnimalServiceUtils.getAnimalModel(animalData))
					if animalModel then
						animalModel.Parent = standFolder
						animalModel:PivotTo(animalMiddle:GetPivot())
					end
					
					-- TODO: animation, fx, etc
				end
				
				defTrove:Add(Observers.observeAttribute(standFolder, "Mutation", function(mutation: string)
					updateRender()
				end))
				updateRender()

				
				local eggThread: thread = nil
				local function updateStandEgg()
					local now = workspace:GetServerTimeNow()
					local eggTimestamp: number? = standFolder:GetAttribute("EggReadyAt")
					local isReady = eggTimestamp and now >= eggTimestamp
					
					statusIndicator.Color = (isReady and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(57, 59, 81))
				end
				
				defTrove:Add(Observers.observeAttribute(standFolder, "EggReadyAt", function(eggTimestamp: number)
					updateStandEgg()
					
					if eggThread then task.cancel(eggThread) end
					eggThread = defTrove:Add(task.spawn(function()
						local now = workspace:GetServerTimeNow()
						while true do
							task.wait(0.25)
							now = workspace:GetServerTimeNow()
							local isReady = eggTimestamp and eggTimestamp <= now
							
							updateStandEgg()
							if isReady then break end
						end
					end))
					
					return function()
						if eggThread then task.cancel(eggThread) end
						updateStandEgg()
					end
				end))
				updateStandEgg()
				
				return function()
					defTrove:Destroy()
					standDisplayTrove:Clean() -- remove display
				end
			end))
		else
			-- unlock sign
			if isOwner then
				local unlockSign: Model = standFolder:WaitForChild("UnlockSign")
				local display: Part = unlockSign:WaitForChild("Display")
				local lockedGui = trove:Add(BaseAssets:WaitForChild("LockedSignGui"):Clone())

				lockedGui.Parent = display
				lockedGui.Adornee = display

				local unlockButton = lockedGui.Button
				local buttonDisplay = unlockButton.ButtonDisplay
				local priceLabel = buttonDisplay.PriceLabel

				trove:Add(unlockButton.Activated:Connect(function()
					remotes.BuyAnimalStand:FireServer(floorIndex, standIndex)
				end))

				trove:Add(Observers.observeAttribute(standFolder, "UnlockCost", function(unlockCost: number)
					if not unlockCost then return function() end end
					priceLabel.Text = string.format("$%s", Abbreviate.AbbreviateNumber(unlockCost, 1))
					return function() end
				end))
			end
		end
		
		return function() trove:Destroy() end
	end)
end

local function mountDrone(floorFolder: Folder)
	local trove = Trove.new()
	
	local floorIndex = tonumber(floorFolder.Name)
	
	local waypointParts: {[number]: Part} = {}
	local standsContainer = floorFolder:WaitForChild("AnimalStands")
	for _, standFolder: Folder in standsContainer:GetChildren() do
		local standIndex: number = tonumber(standFolder.Name)
		if not standIndex then warn("[mountDrone] invalid stand index: ", standIndex) continue end
		if not waypointParts[standIndex] then
			waypointParts[standIndex] = standFolder:WaitForChild("DroneWaypoint")
		end
	end

	-- setup
	local droneAssets = BaseAssets:WaitForChild("Drone")
	local animations = droneAssets:WaitForChild("Animations")
	
	local droneRoot = trove:Add(Instance.new("Part"))
	droneRoot.Name = "DroneRoot"
	droneRoot.Anchored = true
	droneRoot.CanCollide = false
	droneRoot.Transparency = 0
	droneRoot.Material = Enum.Material.ForceField
	droneRoot.Parent = floorFolder
	
	local droneModel = trove:Add(droneAssets:WaitForChild("DroneModel"):Clone())
	local droneBody = droneModel:WaitForChild("Body")
	local animator = droneModel.AnimationController:WaitForChild("Animator")

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = droneRoot
	weld.Part1 = droneModel.PrimaryPart
	weld.Parent = droneModel.PrimaryPart
	droneModel:PivotTo(droneRoot.CFrame)
	droneModel.Parent = floorFolder
	
	local tracks = {
		left = animator:LoadAnimation(animations.Left),
		right = animator:LoadAnimation(animations.Right),
		vacuum = animator:LoadAnimation(animations.Vacuuming)
	}
	
	local droneIndex = floorFolder:GetAttribute("DroneIndex") or 1
	local targetIndex = droneIndex
	
	
	local facing = nil -- nil until first move
	local function face(dir)
		local faceTrack = dir == 1 and tracks.right or tracks.left
		for _, track in tracks do
			track:Stop()
		end
		faceTrack:Play(0.15)
		print("playing ", faceTrack)
		facing = dir
	end
	
	trove:Add(task.spawn(function()
		while true do
			if droneIndex == targetIndex then
				task.wait(0.1)
			else
				local dir = math.sign(targetIndex - droneIndex)
				local nextIndex = droneIndex + dir
				local stepTime = floorFolder:GetAttribute("DroneStepTime") or 1
				
				face(dir)
				
				local tween = TweenService:Create(droneRoot, 
					TweenInfo.new(stepTime, Enum.EasingStyle.Linear),
					{ CFrame = waypointParts[nextIndex].CFrame }
				)
				tween:Play()
				tween.Completed:Wait()
				droneIndex = nextIndex
			end
		end
	end))
	
	trove:Add(Observers.observeAttribute(floorFolder, "DroneIndex", function(standIndex: string)
		targetIndex = standIndex
	end))
	
	trove:Add(Observers.observeAttribute(floorFolder, "DroneVacuuming", function(isVacuuming: boolean)
		if not isVacuuming then return end
		
		local collectSpeed: number = floorFolder:GetAttribute("DroneCollectTime")
		tracks.left:Stop(); tracks.right:Stop()
		tracks.vacuum:Play(1, 1, collectSpeed)
		
		
		local standFolder = standsContainer[targetIndex]
		local definitionKey = standFolder and standFolder:GetAttribute("DefinitionKey")
		if not definitionKey then
			warn("[mountDrone] missing stand folder definitionKey for index: ", targetIndex)
		end
		
		-- crate conveyor eggs
		local animalData: AnimalData = definitionKey and { definitionKey = definitionKey }
		if animalData then
			trove:Add(task.delay(0.1, function()
				local travelTime = BaseServiceUtils.getConveyorTravelTime(floorIndex, targetIndex) 

				for i = 1, 5 do
					local eggModel = AnimalServiceUtils.getEggModel(animalData)
					if not eggModel then return end
					Debris:AddItem(eggModel, travelTime)

					local primaryPart = eggModel.PrimaryPart
					if not primaryPart then
						eggModel:Destroy()
						warn("[mountDrone] missing primary part for egg model")
						return
					end
					eggModel:AddTag("EggModel")

					for _, basePart: BasePart in eggModel:QueryDescendants("BasePart") do
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = primaryPart
						weld.Part1 = basePart
						weld.Parent = basePart
						basePart.Anchored = false
						basePart.CollisionGroup = "AssemblyEggs"
						basePart.CanCollide = basePart ~= primaryPart
						basePart.Massless = true
					end


					eggModel:PivotTo(droneModel.Body.EggPart:GetPivot())
					eggModel.Parent = workspace

					task.wait(0.35)
				end

			end))
		end
		
		
		return function() 
			tracks.vacuum:Stop()
		end
	end))
	
	return function() trove:Destroy() end
end

local function mountFloors(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player
	
	local baseModel = baseFolder:WaitForChild("Base")
	local floorsContainer: Folder = baseModel:WaitForChild("Floors")
	
	for _, floorFolder: Folder in floorsContainer:GetChildren() do
		local floorIndex: number = tonumber(floorFolder.Name)
		if not floorIndex then warn("[mountFloors] invalid floor index: ", floorIndex) continue end
		
		local modelFolder = floorFolder:WaitForChild("Model")
		
		trove:Add(Observers.observeAttribute(floorFolder, "Active", function(isActive: boolean)
			local floorTrove = trove:Extend()
			local upgradesSign = floorFolder:WaitForChild("UpgradeSign")
			BaseServiceUtils.showInstance(upgradesSign, isOwner and isActive)
			
			-- drone
			if isOwner and isActive then floorTrove:Add(mountDrone(floorFolder)) end
			
			return function() floorTrove:Destroy() end
		end))
		
		-- animal stands
		local standsContainer = floorFolder:WaitForChild("AnimalStands")
		for _, standFolder: Folder in standsContainer:GetChildren() do
			local standIndex: number = tonumber(standFolder.Name)
			if not standIndex then warn("[mountFloors] invalid stand index: ", standIndex) continue end

			trove:Add(mountAnimalStand(standFolder, floorIndex, owner))
		end
		
		
	end
	
	return function() trove:Destroy() end
end

local function mountEggCollector(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player
	
	local baseModel = baseFolder:WaitForChild("Base") :: Model
	local container = baseModel.Components:WaitForChild("EggCollector") :: Folder
	local eggHitbox = container:WaitForChild("EggHitbox") :: Part
	local pickupPart = container:WaitForChild("PickupPart") :: Part
	local earningsBillboard = pickupPart:WaitForChild("EarningsBillboard") :: BillboardGui
	local cratesContainer = container:WaitForChild("Crates") :: Folder
	local crateMiddle = container:WaitForChild("CrateMiddle") :: Part

	local function getCrateCount()
		local eggs = container:GetAttribute("EggsCollected") or 0
		return eggs > 0 and math.clamp(math.floor(eggs / 2), 1, 10) or 0
	end

	local displayCrates: {Model} = {}
	local function updateDisplayCrates()
		local carrying = isOwner and CarryServiceClient.source == "EggCollector"
		local n = carrying and 0 or getCrateCount()
		
		-- add new
		for i = #displayCrates + 1, n do 
			local crate = BaseAssets.Crate:Clone()
			local root = crate.PrimaryPart
			for _, part: BasePart in crate:QueryDescendants("BasePart") do
				part.CanCollide = false
			end
			
			root.Anchored = true
			crate.Parent = cratesContainer
			displayCrates[i] = crate
		end
		
		-- remove extra
		for i, crate in displayCrates do
			if i > n then
				crate:Destroy()
				displayCrates[i] = nil
			end
		end
		
		-- position crates
		for i, crate in displayCrates do
			local root = crate.PrimaryPart
			local yOffset = (i - 1) * crate:GetExtentsSize().Y
			crate:PivotTo(crateMiddle:GetPivot() + Vector3.new(0, yOffset, 0))
		end
	end
	
	trove:Add(Observers.observeAttribute(container, "CrateValue", function(value: number)
		local amountLabel: TextLabel = earningsBillboard:WaitForChild("AmountLabel")
		amountLabel.Text = string.format("$%s", Abbreviate.AddCommas(value))
	end))
	
	trove:Add(Observers.observeAttribute(container, "EggsCollected", function(eggsCollected: number)
		if isOwner and CarryServiceClient.source == "EggCollector" then
			CarryServiceClient:SetCrateCount(getCrateCount())
		end
		updateDisplayCrates()
	end))
	
	-- setup egg collector
	if isOwner then
		local pickupPrompt = pickupPart:WaitForChild("PickupPrompt") :: ProximityPrompt
		pickupPrompt.Triggered:Connect(function()
			if CarryServiceClient:IsCarrying() then return end
			CarryServiceClient:Carry("EggCollector", BaseAssets.Crate, getCrateCount())
		end)
		
		Observers.observeAttribute(player, "CarryingCrates", function(isCarrying: boolean)
			pickupPrompt.Enabled = not isCarrying
			if isCarrying then
				updateDisplayCrates()
			end
		end)
		
		local function cashPopup()
			local popup = BaseAssets:WaitForChild("CashPopup"):Clone()

			local radius = math.random(3, 10)
			local theta = math.random() * math.pi

			local x = radius * math.cos(theta)
			local y = radius * math.sin(theta)

			popup.Size = UDim2.fromScale(0.1, 0.1)
			popup.Adornee = eggHitbox
			popup.Parent = eggHitbox

			local tweenInfo = TweenInfo.new(0.85, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, true)
			local tween = TweenService:Create(popup, tweenInfo, {
				Size = UDim2.fromScale(3, 2),
				StudsOffset = Vector3.new(x, y, 0)
			})
			tween:Play()

			task.spawn(function()
				tween.Completed:Wait()
				popup:Destroy()
			end)
		end
		
		local params = OverlapParams.new()
		params.CollisionGroup = "AssemblyGroup"
		task.spawn(function()
			while true do
				local eggPartsInside = workspace:GetPartsInPart(eggHitbox, params)
				local toCollect = {}

				for _, part: BasePart in eggPartsInside do
					local eggModel: Model = part:FindFirstAncestorOfClass("Model")
					if not eggModel or not eggModel:HasTag("EggModel") then 
						continue
					end
					toCollect[eggModel] = true
				end

				for eggModel in toCollect do
					cashPopup()
					if eggModel then eggModel:Destroy() end
				end

				task.wait(0.1)
			end
		end)
	end
	
	return function()
		earningsBillboard.Enabled = false
		trove:Destroy()
	end
end

local function mountSellStand(baseFolder: Folder)
	local baseModel = baseFolder:WaitForChild("Base") :: Model
	local container = baseModel.Components:WaitForChild("SellStand") :: Folder
	local sellHitbox = container:WaitForChild("SellHitbox") :: Part
	local crateTarget = container:WaitForChild("CrateTarget") :: Part
	
	-- sell zone 
	local inSellZone = false
	sellHitbox.Touched:Connect(function(hit)
		if not CarryServiceClient:IsCarrying() or inSellZone then return end
		if hit.Parent == player.Character then 
			inSellZone = true
			remotes.SellEggs:FireServer(CarryServiceClient.source)
			
			-- suck effect
			local crateModels = CarryServiceClient:Take()
			task.spawn(function()
				for i = #crateModels, 1, -1 do
					local crate = crateModels[i]
					local root = crate.PrimaryPart

					local weld: Weld = root:FindFirstChild("CarryWeld")
					if weld then
						weld:Destroy()
					end
					root.Anchored = true
					
					local parts: {BasePart} = crate:QueryDescendants("BasePart")
					
					local startCF = crate:GetPivot()
					local endCF = crateTarget:GetPivot()
					local startPos = startCF.Position
					local endPos = endCF.Position
					local controlPos = startPos:Lerp(endPos, 0.3) + Vector3.new(0, 5, 0)

					local DURATION = 0.5
					local elapsed = 0
					local conn: RBXScriptConnection
					conn = RunService.PreRender:Connect(function(deltaTime)
						elapsed += deltaTime
						local a = math.min(elapsed / DURATION, 1)
						local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						
						crate:PivotTo(CFrame.new(quadraticBezier(startPos, controlPos, endPos, e)) * startCF.Rotation:Lerp(endCF.Rotation, e))
						crate:ScaleTo(math.max(1 - e / 2, 0.5))
						for _, basePart: BasePart in parts do
							basePart.Transparency = e/2
						end

						if a >= 1 then
							conn:Disconnect()
							crate:Destroy()
							return
						end
					end)
					
					task.delay(0.25, function()
						SoundService:PlayLocalSound(SoundService.SFX.CrateAdded)
					end)
					
					task.wait(0.15)
				end
			end)
			
			task.delay(0.5, function()
				inSellZone = false
			end)
		end
	end)
	
	
	-- TODO: 2x crate value product pad
	
	BaseServiceUtils.showInstance(container, true)
end

local function mountRollStand(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player
	local slotRecords = {} :: {[number]: {
		slot: Folder,
		middlePart: Part,
		trove: Trove,
		animalModel: Model?,
		definitionKey: string?,
		animalBillboard: AnimalBillboard?
	}}

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

	local function renderSlotAnimal(slotIndex: number, animalData: AnimalData): Model?
		local slotRecord = slotRecords[slotIndex]
		if not slotRecord then warn("[renderSlotAnimal] missing slot record for index ", slotIndex) return end
		
		local slotTrove = slotRecord.trove

		if not animalData or not animalData.definitionKey then
			slotTrove:Clean()
			slotRecord.animalModel = nil
			slotRecord.definitionKey = nil
			return nil
		end

		-- already showing this animal (e.g. handed off from the roll reveal): keep it, don't tear it down
		if slotRecord.animalModel and slotRecord.definitionKey == animalData.definitionKey then
			return slotRecord.animalModel
		end
		slotTrove:Clean()

		local animalModel = AnimalServiceUtils.getAnimalModel(animalData)
		if not animalModel then warn("[renderSlotAnimal] failed to get animal model for definitionKey ", animalData.definitionKey) return nil end
		slotTrove:Add(animalModel)
		animalModel.Parent = slotRecord.slot
		animalModel:PivotTo(slotRecord.middlePart:GetPivot())
		slotRecord.animalModel = animalModel
		slotRecord.definitionKey = animalData.definitionKey

		-- animal billboard
		if slotRecord.animalBillboard then 
			slotRecord.animalBillboard:destroy()
			slotRecord.animalBillboard = nil
		end
		slotRecord.animalBillboard = slotTrove:Add(AnimalBillboard.new(animalModel.PrimaryPart or slotRecord.middlePart, animalData))

		-- bob effect
		if isOwner then
			local middleCF = slotRecord.middlePart:GetPivot()
			slotTrove:Add(RunService.PreRender:Connect(function()
				local time = os.clock()
				animalModel:PivotTo(middleCF * CFrame.new(0, math.sin(time * 2) * 0.1, 0))
			end))
		end

		return animalModel
	end

	
	-- slots
	for _, slot in slots:GetChildren() do
		local slotIndex = tonumber(slot.Name)
		local middlePart: Part = slot:WaitForChild("Middle")
		local model = slot:WaitForChild("Model")
		local buyPrompt: ProximityPrompt = middlePart:WaitForChild("BuyPrompt")
		local stealPrompt: ProximityPrompt= middlePart:WaitForChild("StealPrompt")

		slotRecords[slotIndex] = {
			slot = slot,
			middlePart = middlePart,
			trove = trove:Extend(),
			animalModel = nil,
			definitionKey = nil,
		}
		
		-- prompts
		if isOwner then
			trove:Add(buyPrompt.Triggered:Connect(function()
				remotes.BuySlotAnimal:FireServer(slotIndex)
			end))
		else
			trove:Add(stealPrompt.Triggered:Connect(function()
				remotes.StealSlotAnimal:FireServer(owner, slotIndex)
			end))
		end

		
		local function update()
			local active = slot:GetAttribute("Active")
			local rolling = rollStand:GetAttribute("Rolling")
			local definitionKey = slot:GetAttribute("DefinitionKey")
			
			local showAnimal = active and definitionKey and not rolling
			
			buyPrompt.Enabled = showAnimal and isOwner
			stealPrompt.Enabled = showAnimal and not isOwner
			
			if rolling then return end
			
			local animalData: AnimalData = {
				definitionKey = definitionKey,
			}
		
			renderSlotAnimal(slotIndex, active and definitionKey and animalData or nil)
		end
		
		trove:Add(slot:GetAttributeChangedSignal("Active"):Connect(update))
		trove:Add(slot:GetAttributeChangedSignal("DefinitionKey"):Connect(update))
		trove:Add(rollStand:GetAttributeChangedSignal("Rolling"):Connect(update))
		update()
		
	end
	
	
	-- listen for roll result
	if isOwner then
		local rollTrove = trove:Extend()

		local function spawnFlickerAnimal(slotRecord, revealLength: number)
			local middlePart = slotRecord.middlePart
			local randomKey = AnimalServiceUtils.getRandomAnimalKey(true)
			local animalModel = randomKey and AnimalServiceUtils.getAnimalModel({definitionKey = randomKey})
			if not animalModel then warn("[mountRollStand] failed to get random animal model for key: ", randomKey) return end
			rollTrove:Add(animalModel)

			local shadow = rollTrove:Add(Instance.new("Highlight"))
			shadow.DepthMode = Enum.HighlightDepthMode.Occluded
			shadow.FillColor = Color3.fromRGB(0, 0, 0)
			shadow.FillTransparency = 0
			shadow.OutlineTransparency = 0
			shadow.Parent = animalModel

			animalModel:ScaleTo(0.25)
			animalModel.Parent = middlePart
			animalModel:PivotTo(middlePart:GetPivot())

			local animalBillboard = AnimalBillboard.new(middlePart, { definitionKey = randomKey })
			rollTrove:Add(animalBillboard)

			local elapsed = 0
			local connection: RBXScriptConnection
			connection = rollTrove:Add(RunService.PreRender:Connect(function(dt)
				elapsed += dt
				local a = math.min(elapsed / revealLength, 1)
				animalModel:ScaleTo(0.25 + (0.75 * a))

				if a >= 1 then
					connection:Disconnect()
					animalModel:Destroy()
					animalBillboard:destroy()
				end
			end))
		end

		local function revealAnimal(slotIndex, slotResult: SlotResult)
			local defKey = slotResult.definitionKey
			if not defKey then warn("[mountRollStand] missing definitionKey for slot result") return end

			local slotRecord = slotRecords[slotIndex]
			local trove = slotRecord.trove
			local animalModel = renderSlotAnimal(slotIndex, { definitionKey = defKey })

			local REVEAL_LENGTH = 0.3
			local elapsed = 0
			local connection: RBXScriptConnection
			connection = rollTrove:Add(RunService.PreRender:Connect(function(dt)
				elapsed += dt
				local a = math.min(elapsed / REVEAL_LENGTH, 1)
				animalModel:ScaleTo(1 + math.sin(a * math.pi) * 0.25)
				if a >= 1 then
					connection:Disconnect()
				end
			end))

			VfxUtils.emitVfx("ExpandingRing", animalModel.PrimaryPart or slotRecord.middlePart)
			
		end

		local function playPop(step: number)
			task.delay(0.1, function()
				local sound = SoundService.SFX.Pop:Clone()
				sound.PlaybackSpeed = 1 + (step * 0.1)
				SoundService:PlayLocalSound(sound)
				Debris:AddItem(sound, sound.TimeLength + 0.1)
			end)
		end

		trove:Add(remotes.RollAnimal.OnClientEvent:Connect(function(rollResult: RollResult)
			rollTrove:Clean()
			rollStand:SetAttribute("Rolling", true)

			for slotIndex in slotRecords do
				renderSlotAnimal(slotIndex, nil)
			end

			rollTrove:Add(task.spawn(function()
				-- reveal: every slot flickers in lockstep
				for i = 1, 5 do
					local revealLength = 0.2 * i
					for slotIndex in rollResult.slots do
						local slotRecord = slotRecords[slotIndex]
						if slotRecord then spawnFlickerAnimal(slotRecord, revealLength) end
					end
					playPop(i)
					task.wait(revealLength)
				end

				-- final animals: rendered onto the slot records, so update() keeps them once the attribute lands
				for slotIndex, slotResult in rollResult.slots do
					revealAnimal(slotIndex, slotResult)
				end

				rollStand:SetAttribute("Rolling", nil) -- the roll's owner ends the roll
			end))
		end))
	end
	
	
	return function() trove:Destroy() end
end

local function mountBases()
	Observers.observeTag("Base", function(baseFolder: Folder)
		return Observers.observeAttribute(baseFolder, "Owner", function(ownerName)
			local trove = Trove.new()
			local owner: Player = Players:FindFirstChild(ownerName)
			
			local isOwner = owner == player
			
			-- base components
			trove:Add(mountFloors(baseFolder, owner))
			trove:Add(mountRollStand(baseFolder, owner))
			trove:Add(mountEggCollector(baseFolder, owner))
			
			if isOwner then
				mountSellStand(baseFolder)
			end
			
			return function() trove:Destroy() end
		end)
	end)
end



--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------


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


return BaseController :: BaseController