local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Scribe = require(ReplicatedStorage.Packages.Scribe)
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)

return Scribe({
    ProfileStoreIndex = "DEV-12",
    ProfileKeyPrefix = "", -- ["" .. UserId]
    Mode = "Live", -- Live / Mock / NoSave
    Template = DataTemplate
})