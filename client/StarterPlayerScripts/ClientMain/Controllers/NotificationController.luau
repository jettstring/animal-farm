local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--------------------------------------------------
-- DEPENDENCIES -- 
--------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- UI
local notificationGui = playerGui:WaitForChild("NotificationsGui")
local notificationsFrame = notificationGui:WaitForChild("Notifications")
local notifTemplate = notificationsFrame.UIListLayout:WaitForChild("NotificationTemplate")
local bannerFrame = notificationsFrame:WaitForChild("BannerFrame")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	Notify = remotesFolder.Notification:WaitForChild("Notify"),
	CreateBanner = remotesFolder.Notification:WaitForChild("CreateBanner"),
}

--------------------------------------------------
-- STATE --
--------------------------------------------------
local NotificationController = {}
NotificationController.Controllers = {}
NotificationController.Signals = {}

local currentBanner = nil

--------------------------------------------------
-- VARIABLES --
--------------------------------------------------

-- Constants

--------------------------------------------------
-- PRIVATE FUNCTIONS --
--------------------------------------------------

local function CreateNotification(text: string, color: Color3, sound: Sound, icon: string)
	local notification = notifTemplate:Clone()
	local textLabel = notification:WaitForChild("Text")
	local iconLabel = notification:WaitForChild("Icon")

	textLabel.Text = text
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
	textLabel.TextTransparency = 0
	textLabel.UIStroke.Transparency = 0
	notification.UIScale.Scale = 0.4
	notification.Parent = notificationsFrame

	if icon then
		iconLabel.Image = icon
		iconLabel.Visible = true
	else
		iconLabel.Visible = false
	end

	-- Scale up animation
	local scaleUp = TweenService:Create(notification.UIScale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Scale = 1
	})
	scaleUp:Play()

	-- Play sound

	if sound then 
		sound:Play()
	else 
		SoundService.UISounds.Notification1:Play()
	end


	-- Fade out after delay
	task.delay(2.5, function()
		local fadeText = TweenService:Create(textLabel, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			TextTransparency = 1
		})

		local fadeStroke = TweenService:Create(textLabel.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			Transparency = 1
		})

		local fadeBacking = TweenService:Create(notification, TweenInfo.new(1, Enum.EasingStyle.Quad), {
			Transparency = 1
		})

		fadeText:Play()
		fadeStroke:Play()
		fadeBacking:Play()

		task.wait(1.2)
		notification:Destroy()
	end)

	notification.Visible = true
end


local function CreateBanner(show: boolean, ID: string, text, color: Color3, sound: Sound)
	if currentBanner then
		currentBanner = nil

		-- Scale up animation
		local scaleDown = TweenService:Create(bannerFrame.UIScale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 0
		})
		scaleDown:Play()
		scaleDown.Completed:Wait()
		bannerFrame.Visible = false
	end
	if not show then return false end

	currentBanner = ID
	
	local textLabel = bannerFrame:WaitForChild("Text")

	textLabel.Text = text
	textLabel.TextColor3 = color or Color3.new(1, 1, 1)
	textLabel.TextTransparency = 0
	textLabel.UIStroke.Transparency = 0
	bannerFrame.UIScale.Scale = 0.4
	bannerFrame.Parent = notificationsFrame
	bannerFrame.Visible = true

	-- Scale up animation
	local scaleUp = TweenService:Create(bannerFrame.UIScale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Scale = 1
	})
	scaleUp:Play()

	if sound then 
		sound:Play()
	else 
		SoundService.SFX.UI.Notification1:Play()
	end

end

--------------------------------------------------
-- PUBLIC FUNCTIONS --
--------------------------------------------------

function NotificationController.Notify(self: NotificationController, text: string, color: Color3, sound: Sound, icon: string)
	CreateNotification(text, color, sound, icon)
end

--------------------------------------------------
-- MAIN --
--------------------------------------------------

function NotificationController.Init(self: NotificationController, controllers)
	self.Controllers = controllers

end

function NotificationController.Start(self: NotificationController)
	remotes.Notify.OnClientEvent:Connect(CreateNotification)
	remotes.CreateBanner.OnClientEvent:Connect(CreateBanner)
end

type NotificationController = typeof(NotificationController) & {}

return NotificationController