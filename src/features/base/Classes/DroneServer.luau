local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Data = require(ReplicatedStorage.Source.Game.Data).Server
local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local DroneUtils = require(ReplicatedStorage.Source.Features.Base.Modules.DroneUtils)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.Modules.BaseTypes)
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)


type DroneState = BaseTypes.DroneState
type CollectedEgg = BaseTypes.CollectedEgg
type AnimalStandServer = AnimalStandServer.AnimalStandServer

local DroneServer = {}
DroneServer.__index = DroneServer

type self = {
    trove: Trove.Trove,
    state: DroneState,
    direction: number,
    floorFolder: Folder,
    animalStands: { [number]: AnimalStandServer },
    floorUpgrades: Scribe.PlayerData<DataTemplate.FloorUpgrades>,
}

export type DroneServer = typeof(setmetatable({} :: self, DroneServer))

function DroneServer.new(floorFolder: Folder, animalStands: { [number]: AnimalStandServer } , floorUpgrades: Scribe.PlayerData<DataTemplate.FloorUpgrades>)
    local self = setmetatable({} :: self, DroneServer)
    
    self.trove = Trove.new()
    self.floorFolder = floorFolder
    self.animalStands = animalStands
    self.floorUpgrades = floorUpgrades
    self.state = nil
    self.direction = 1

    return self
end

function DroneServer.update(self: DroneServer, now: number): CollectedEgg?
    local state = self.state
    local phase = state.phase
    local toStand = state.toStand
    local fromStand = state.fromStand
    local phaseEnd = state.phaseEnd
    local phaseStart = state.phaseStart
    
    if now < phaseEnd then
        -- re-check for new target stand mid phase
        -- if new target new then change target stand and recompute new endTime

        return nil -- mid phase
    end


    -- collect currrent stand if we are collecting 
    local collected: CollectedEgg? = nil
    if phase == "Collecting" then
        local stand = self.animalStands[toStand]
        local earnings = stand and stand:CollectEgg()
        if earnings then
            collected = { standIndex = toStand, collectTime = phaseEnd, earnings = earnings } :: CollectedEgg
        end
    end

    -- get next target stand ..

    -- if target in current direction
        -- set new state to moving towards target
    -- elseif target in opposite direction
        -- set new state to moving towards target in opposite direction
    -- else
        -- current stand is the only stand
        -- change state to idle

  
    return collected
end


function DroneServer.setState(self: DroneServer, state: DroneState)
    self.state = state
    self.floorFolder:SetAttribute("DroneState", HttpService:JSONEncode(state))
end

function DroneServer.getTargetInDirection(self: DroneServer, dir: number): AnimalStandServer? -- should this take in currentIndex, and current time? answer:
    local state = self.state

    -- check for any unlocked stands in current direction
    -- if yes
        -- check for closest ready stand in that direction
            -- if yes return
        -- else return outer most unlocked in current direction
    
    
end

function DroneServer.getClosestReadyAhead(self: DroneServer, fromIndex: number, dir: number, now: number)
    local nextIndex = fromIndex + dir
    while self.animalStands[nextIndex] do
        local stand = self.animalStands[nextIndex]
        if stand:IsEggReady(now) then
            return stand        
        end

        nextIndex += dir
    end

    return nil
end

function DroneServer.getFurthestUnlockedAhead(self: DroneServer, dir: number): AnimalStandServer?
    -- return the outer most unlocked stand in the given direction
    local startIndex = dir == 1 and 1 or #self.animalStands
    local furthestUnlockedStand: AnimalStandServer? = nil
    for i = startIndex, dir == 1 and #self.animalStands or 1, dir do
        local stand = self.animalStands[i]
        if stand and stand:isUnlocked() then
            furthestUnlockedStand = stand
        end
    end
    
    return furthestUnlockedStand
end




function DroneServer.getStepTime(self: DroneServer): number
    return DroneUtils.CalculateStepTime(self.floorUpgrades.droneSpeed.Get() or 0)
end

function DroneServer.getCollectTime(self: DroneServer): number
    return DroneUtils.CalculateCollectTime(self.floorUpgrades.collectSpeed.Get() or 0)
end

function DroneServer.destroy(self: DroneServer)
    self.trove:Destroy()
end

return DroneServer