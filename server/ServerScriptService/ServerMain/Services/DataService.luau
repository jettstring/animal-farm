local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	GetProfile = remotesFolder.Data.GetProfile,
	GetPurchaseProfile = remotesFolder.Data.GetPurchaseProfile,
}

local INCREMENTABLE_CURRENCIES = {
	["Money"] = true,
}

local ProfileTemplate = require(ReplicatedStorage.Modules:WaitForChild("ProfileTemplate"))
local PurchaseProfileTemplate = require(ReplicatedStorage.Modules:WaitForChild("PurchaseProfileTemplate"))


--------------------------------------------------
-- TYPES -- 
--------------------------------------------------

type Profile = ProfileTemplate.ProfileTemplate

--------------------------------------------------
-- STATE --
--------------------------------------------------
local DataService = {}
DataService.Services = {}
DataService.Signals = {
	DataLoaded = Signal.new(),
}

DataService.MainKey = "DEV-07"
DataService.PurchaseKey = "DEV-PURCHASES-01"

DataService.DATA_CONFIG = {
	Mock = true, 
}

DataService.PlayerStore = ProfileStore.New(DataService.MainKey, ProfileTemplate)
DataService.PurchaseStore = ProfileStore.New(DataService.PurchaseKey, PurchaseProfileTemplate)

if RunService:IsStudio() and DataService.DATA_CONFIG.Mock == true then
	DataService.PlayerStore = DataService.PlayerStore.Mock
	DataService.PurchaseStore = DataService.PurchaseStore.Mock
	warn("[DataService] ⚠️ MOCK PROFILE ACTIVE ⚠️")
end

DataService.Profiles = {}
DataService.PurchaseProfiles = {}

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------z

local function _playerAdded(player: Player)
	local profile = DataService.PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	local purchaseProfile = DataService.PurchaseStore:StartSessionAsync(`{player.UserId}_purchases`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil and purchaseProfile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		purchaseProfile:AddUserId(player.UserId)
		purchaseProfile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			if DataService.Profiles[player] then
				DataService.Profiles[player].Data.LastSessionTimestamp =  workspace:GetServerTimeNow()
			end
			DataService.Profiles[player] = nil
			player:SetAttribute("Loaded", false)
			player:Kick(`Profile session end - Please rejoin`)
		end)

		purchaseProfile.OnSessionEnd:Connect(function()
			DataService.PurchaseProfiles[player] = nil
		end)


		if player.Parent == Players then
			DataService.Profiles[player] = profile
			DataService.PurchaseProfiles[player] = purchaseProfile

			if RunService:IsStudio() then
				print("PROFILE: ", profile.Data)
				print("PURCHASE PROFILE: ", purchaseProfile.Data)
			end
			

			-- Set Shared Attributes
			DataService:UpdateAttributes(player)
			
			player:SetAttribute("Loaded", true)
			DataService.Signals.DataLoaded:Fire(player)
		else
			profile:EndSession()
			purchaseProfile:EndSession()
		end
	else
		player:Kick(`Profile load fail - Please rejoin`)
	end
end

local function _playerRemoved(player: Player)
	local profile = DataService.Profiles[player]
	local purchaseProfile = DataService.PurchaseProfiles[player]

	if profile then
		profile.Data.LastSessionTimestamp = os.time()
		profile:EndSession()
	end

	if purchaseProfile then
		purchaseProfile:EndSession()
	end
end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function DataService.GetProfile(self: DataService, player: Player): Profile
	local profile = self.Profiles[player]

	if not profile then
		warn("[GetProfile] No profile found for player:", player.Name)
		warn(debug.traceback())
		return nil
	end

	return profile.Data
end

function DataService.GetPurchaseProfile(self: DataService, player: Player)
	local purchaseProfile = self.PurchaseProfiles[player]

	if not purchaseProfile then
		warn("[GetPurchaseProfile] No purchaseProfile found for player:", player.Name)
		return nil
	end

	return purchaseProfile.Data
end


function DataService.UpdateAttributes(self: DataService, player: Player)
	local profile: Profile = self:GetProfile(player)
	if not profile then warn("[UpdateAttributes] No profile found for player:", player.Name) return end
	
	for valueName in INCREMENTABLE_CURRENCIES do
		player:SetAttribute(valueName, profile.currency[valueName])
	end
end

function DataService.IncrementCurrency(self: DataService, player: Player, currencyName: string, amount: number, source: string?, suppressAnalytics: boolean?): string
	if not INCREMENTABLE_CURRENCIES[currencyName] then
		return 'Invalid currency'
	end
	
	local profile: Profile = self:GetProfile(player)
	if not profile then return 'Profile not found' end
	
	if typeof(amount) ~= "number" then
		return "Amount must be a number."
	end

	local currentValue = profile.currency[currencyName]
	if typeof(currentValue) ~= "number" then
		currentValue = 0
	end

	local newValue = currentValue + amount
	profile.currency[currencyName] = newValue

	-- Update attributes
	self:UpdateAttributes(player)

	local transactionAmount = math.abs(amount)
	if not suppressAnalytics then
		if amount > 0 then
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, currencyName,
				transactionAmount,
				newValue,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				nil,
				{
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = source,
				} 
			)
		elseif amount < 0 then
			AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, currencyName,
				transactionAmount,
				newValue,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				nil,
				{
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = source,
				} 
			)
		end
	end
	
	return `{player.Name} now has {newValue} {currentValue}.`
end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function DataService.Init(self: DataService, services)
	self.Services = services
	
	print("✅ DataService initiated")
end

function DataService.Start(self: DataService)
	for _, player in Players:GetPlayers() do
		_playerAdded(player)
	end
	Players.PlayerAdded:Connect(_playerAdded)
	Players.PlayerRemoving:Connect(_playerRemoved)
	
	
	remotes.GetProfile.OnServerInvoke = function(player)
		return self:GetProfile(player)
	end
	
	remotes.GetPurchaseProfile.OnServerInvoke = function(player)
		return self:GetPurchaseProfile(player)
	end
	
	print("✅ DataService started")
end

type DataService = typeof(DataService) & {
	
}

return DataService
