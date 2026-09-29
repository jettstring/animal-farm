local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Scribe = require(ReplicatedStorage.Packages.Scribe)
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)

return Scribe({
    ProfileStoreIndex = "DEV-14",
    ProfileKeyPrefix = "", -- ["" .. UserId]
    Mode = "Mock", -- Live / Mock / NoSave
    Template = DataTemplate
})