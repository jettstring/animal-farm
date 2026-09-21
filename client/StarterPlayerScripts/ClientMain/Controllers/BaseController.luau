local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")


local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Abbreviate = require(ReplicatedStorage.Packages.Abbreviate)
local Bezier = require(ReplicatedStorage.Packages.Bezier)


--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

-- Controllers
local CarryController = require(StarterPlayer.StarterPlayerScripts.ClientMain.Controllers.CarryController)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Modules
local ProfileTemplate = require(ReplicatedStorage.Modules.ProfileTemplate)
local BaseTypes = require(ReplicatedStorage.Modules.BaseTypes)


-- Utils
local Utils = ReplicatedStorage:FindFirstChild("Utils")
local BaseUtil = require(Utils.BaseUtil)
local AnimalUtil = require(Utils.AnimalUtil)

-- Base Assets
local Assets = ReplicatedStorage:WaitForChild("Assets")
local BaseAssets = Assets:WaitForChild("Base")

-- Animal Assets
local AnimalAssets = Assets:WaitForChild("Animals")
local AnimalConfig = require(AnimalAssets:WaitForChild("AnimalConfig"))
local AnimalDefinitions = AnimalConfig.AnimalDefinitions
local MutationGradients = AnimalAssets:WaitForChild("MutationGradients")


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

type AnimationDefinition = AnimalConfig.AnimalDefinition
type AnimalMutation = AnimalConfig.AnimalMutation

type Profile = ProfileTemplate.ProfileTemplate
type AnimalData = ProfileTemplate.AnimalData

type SlotResult = BaseTypes.SlotResult
type RollResult = BaseTypes.RollResult

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
	local trove = standDisplayTrove
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
		buy1Button.PriceLabel.Text  = "$" .. Abbreviate.AbbreviateNumber(AnimalUtil.getLevelUpCost(defKey, level, 1), 1)
		buy10Button.PriceLabel.Text = "$" .. Abbreviate.AbbreviateNumber(AnimalUtil.getLevelUpCost(defKey, level, 10), 1)

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
			trove:Add(BaseController.Controllers.InteractionController:Register(standModel, function()
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
					local animalModel = renderTrove:Add(AnimalUtil.getAnimalModel(animalData))
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
				local travelTime = BaseUtil.getConveyorTravelTime(floorIndex, targetIndex) 

				for i = 1, 5 do
					local eggModel = AnimalUtil.getEggModel(animalData)
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
			BaseUtil.showInstance(upgradesSign, isOwner and isActive)
			
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
		local carrying = isOwner and CarryController.source == "EggCollector"
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
		if isOwner and CarryController.source == "EggCollector" then
			CarryController:SetCrateCount(getCrateCount())
		end
		updateDisplayCrates()
	end))
	
	-- setup egg collector
	if isOwner then
		local pickupPrompt = pickupPart:WaitForChild("PickupPrompt") :: ProximityPrompt
		pickupPrompt.Triggered:Connect(function()
			if CarryController:IsCarrying() then return end
			CarryController:Carry("EggCollector", BaseAssets.Crate, getCrateCount())
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
		if not CarryController:IsCarrying() or inSellZone then return end
		if hit.Parent == player.Character then 
			inSellZone = true
			remotes.SellEggs:FireServer(CarryController.source)
			
			-- suck effect
			local crateModels = CarryController:Take()
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
					local path = Bezier.new({startPos, controlPos, endPos})
					path:toggleVisualization(true)
					
					local DURATION = 0.5
					local elapsed = 0
					local conn: RBXScriptConnection
					conn = RunService.PreRender:Connect(function(deltaTime)
						elapsed += deltaTime
						local a = math.min(elapsed / DURATION, 1)
						local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						
						crate:PivotTo(CFrame.new(path:positionAt(e)) * startCF.Rotation:Lerp(endCF.Rotation, e))						
						crate:ScaleTo(math.max(1 - e / 2, 0.5))
						for _, basePart: BasePart in parts do
							basePart.Transparency = e/2
						end
						
						if a >= 1 then
							conn:Disconnect()
							crate:Destroy()
							path:Destroy()
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
	
	BaseUtil.showInstance(container, true)
end

local function mountRollStand(baseFolder: Folder, owner: Player)
	local trove = Trove.new()
	local isOwner = owner == player

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
	
	-- slots
	local slotParts: {Part} = {}
	for _, slot in slots:GetChildren() do
		local slotIndex = tonumber(slot.Name)
		local middlePart: Part = slot:WaitForChild("Middle")
		local model = slot:WaitForChild("Model")
		local buyPrompt: ProximityPrompt = middlePart:WaitForChild("BuyPrompt")
		local stealPrompt: ProximityPrompt= middlePart:WaitForChild("StealPrompt")
		
		local animalTrove = trove:Extend()
		slotParts[slotIndex] = middlePart
		
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
			animalTrove:Clean()
			local active = slot:GetAttribute("Active")
			local inCutscene = rollStand:GetAttribute("RevealCutscene")
			local definitionKey = slot:GetAttribute("DefinitionKey")
			
			local showAnimal = active and definitionKey and not inCutscene
			
			buyPrompt.Enabled = showAnimal and isOwner
			stealPrompt.Enabled = showAnimal and not isOwner
			
			if not showAnimal then return end
			
			local animalData: AnimalData = {
				definitionKey = definitionKey,
			}

			local animalModel = animalTrove:Add(AnimalUtil.getAnimalModel(animalData))
			if animalModel then
				animalModel.Parent = model
				animalModel:PivotTo(middlePart:GetPivot())
			end
		end
		
		trove:Add(slot:GetAttributeChangedSignal("Active"):Connect(update))
		trove:Add(slot:GetAttributeChangedSignal("DefinitionKey"):Connect(update))
		trove:Add(slot:GetAttributeChangedSignal("RevealCutscene"):Connect(update))
		update()
		
	end
	
	
	-- listen for roll result
	if isOwner then
		local rollTrove = trove:Extend()
		trove:Add(remotes.RollAnimal.OnClientEvent:Connect(function(rollResult: RollResult)
			rollTrove:Clean()
			
			for slotIndex, slotResult in rollResult.slots do
				local defKey = slotResult.definitionKey
				local isNew = slotResult.isNew
				local slotPart = slotParts[slotIndex]
				if not defKey then warn("[mountRollStand] missing definitionKey for slot ", slotIndex) continue end
				if not slotPart then warn("[mountRollStand] missing slot part for index ", slotIndex) continue end

				local animalData: AnimalData = {
					definitionKey = defKey,
				}
				
				rollTrove:Add(task.spawn(function()
					

					for i = 1, 5 do
						local randomAnimal = AnimalUtil.getRandomAnimalModel(true)
						if not randomAnimal then warn("[mountRollStand] failed to get random animal model") end
					
						local shadow = rollTrove:Add(Instance.new("Highlight"))
						shadow.FillColor = Color3.fromRGB(0, 0, 0)
						shadow.FillTransparency = 0
						shadow.OutlineTransparency = 0
						shadow.Parent = randomAnimal
					
						randomAnimal:ScaleTo(0.25)
						randomAnimal.Parent = slotPart
						randomAnimal:PivotTo(slotPart:GetPivot())
						
						local revealLength = 0.2 * i
						
						local elapsed = 0
						local connection: RBXScriptConnection
						connection = rollTrove:Add(RunService.PreRender:Connect(function(dt)
							elapsed += dt
							local a = math.min(elapsed / revealLength, 1)
							randomAnimal:ScaleTo(0.25 + (0.75 * a))
							
							print(randomAnimal:GetScale())
							if a >= 1 then
								connection:Disconnect()
								randomAnimal:Destroy()
							end
						end))
						
						if slotIndex == 1 then
							task.delay(0.1, function()
								local sound = SoundService.SFX.Pop:Clone()
								sound.PlaybackSpeed = 1 + (i * 0.1)
								SoundService:PlayLocalSound(sound)
								Debris:AddItem(sound, sound.TimeLength + 0.1)
							end)
						end
		
						task.wait(revealLength)
					end
				end))
				
				
			end
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