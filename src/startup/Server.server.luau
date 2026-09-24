local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NotificationServiceServer = require(ServerScriptService.Features.Notification.NotificationServiceServer)
local AnimalServiceServer = require(ServerScriptService.Features.Animal.AnimalServiceServer)
--local BaseServiceServer = require(ServerScriptService.Features.Base.BaseServiceServer)

NotificationServiceServer:Init()
AnimalServiceServer:Init()
-- BaseServiceServer:Init()

NotificationServiceServer:Start()
AnimalServiceServer:Start()
-- BaseServiceServer:Start()


local Cmdr = require(ServerScriptService.ServerPackages.Cmdr)
Cmdr.Registry:RegisterDefaultCommands()
--Cmdr.Registry:RegisterCommandsIn(ReplicatedStorage.Packages.Cmdr.CustomCommands)
--Cmdr.Registry:RegisterHooksIn(ReplicatedStorage.Packages.Cmdr.Hooks)
