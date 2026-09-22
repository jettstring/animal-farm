local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient"))
local NotificationServiceClient = require(ReplicatedStorage.Source.Features.Notification.NotificationServiceClient)
local InteractionServiceClient = require(ReplicatedStorage.Source.Features.Interaction.InteractionServiceClient)
local AnimalServiceClient = require(ReplicatedStorage.Source.Features.Animal.AnimalServiceClient)
local BaseServiceClient = require(ReplicatedStorage.Source.Features.Base.BaseServiceClient)
local CarryServiceClient = require(ReplicatedStorage.Source.Features.Carry.CarryServiceClient)


NotificationServiceClient:Init()
InteractionServiceClient:Init()
AnimalServiceClient:Init()
BaseServiceClient:Init()
CarryServiceClient:Init()

NotificationServiceClient:Start()
InteractionServiceClient:Start()
AnimalServiceClient:Start()
BaseServiceClient:Start()
CarryServiceClient:Start()


CmdrClient:SetActivationKeys({ Enum.KeyCode.F2 , Enum.KeyCode.Semicolon})