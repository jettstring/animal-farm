local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Scribe = require(ReplicatedStorage.Packages.Scribe)
local Trove = require(ReplicatedStorage.Packages.Trove)

local DataTemplate = require(ReplicatedStorage.Source.Game.DataTemplate)
local DroneUtils = require(ReplicatedStorage.Source.Features.Base.Modules.DroneUtils)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.Modules.BaseTypes)
local AnimalStandServer = require(ServerScriptService.Features.Base.Classes.AnimalStandServer)

type DroneState = BaseTypes.DroneState
type DronePhase = BaseTypes.DronePhase
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

function DroneServer.new(floorFolder: Folder, animalStands: { [number]: AnimalStandServer }, floorUpgrades: Scribe.PlayerData<DataTemplate.FloorUpgrades>): DroneServer
    local self = setmetatable({} :: self, DroneServer)

    self.trove = Trove.new()
    self.floorFolder = floorFolder
    self.animalStands = animalStands
    self.floorUpgrades = floorUpgrades
    self.direction = 1

    local now = workspace:GetServerTimeNow()
    self:setState("Idle", 1, 1, now, now)

    return self
end

-- Called every Heartbeat by BaseServer. Returns the egg collected this tick, if any.
function DroneServer.update(self: DroneServer, now: number): CollectedEgg?
    local state = self.state

    -- mid-trip: re-aim at the nearest target ahead of where the drone is right now
    if state.phase == "Moving" and now < state.phaseEnd then
        local stepTime = (state.phaseEnd - state.phaseStart) / math.abs(state.toStand - state.fromStand)
        local position = state.fromStand + self.direction * (now - state.phaseStart) / stepTime
        local target = self:findTarget(position, self.direction, now)
        if target and target ~= state.toStand then
            self:setState("Moving", state.fromStand, target, state.phaseStart, state.phaseStart + math.abs(target - state.fromStand) * stepTime)
        end
        return nil
    end

    if state.phase == "Collecting" and now < state.phaseEnd then
        return nil
    end

    -- phase finished (or idle). Continue from the exact end time so timing never drifts.
    local t = if state.phase == "Idle" then now else state.phaseEnd
    local here = state.toStand
    local stand = self.animalStands[here]
    local collected: CollectedEgg? = nil

    if state.phase == "Collecting" and stand and stand:IsEggReady(t) then
        local earnings = stand:CollectEgg()
        if earnings then
            collected = { standIndex = here, collectTime = t, earnings = earnings }
        end
    end

    if stand and stand:IsEggReady(t) then
        self:setState("Collecting", here, here, t, t + self:getCollectTime())
        return collected
    end

    -- keep sweeping; reverse at the edge
    local target = self:findTarget(here, self.direction, t)
    if not target then
        self.direction = -self.direction
        target = self:findTarget(here, self.direction, t)
    end

    if target then
        self:setState("Moving", here, target, t, t + math.abs(target - here) * self:getStepTime())
    elseif state.phase ~= "Idle" then
        self:setState("Idle", here, here, t, t) -- 0 or 1 unlocked stands: nowhere to go
    end

    return collected
end

-- Nearest ready stand ahead of `position`. If none is ready, the furthest unlocked stand
-- ahead (the patrol edge). nil if there's nothing unlocked ahead.
function DroneServer.findTarget(self: DroneServer, position: number, dir: number, now: number): number?
    local i = if dir > 0 then math.floor(position) + 1 else math.ceil(position) - 1
    local edge = nil
    while self.animalStands[i] do
        local stand = self.animalStands[i]
        if stand:IsEggReady(now) then
            return i
        end
        if stand.StandData.unlocked.Get() then
            edge = i
        end
        i += dir
    end
    return edge
end

function DroneServer.setState(self: DroneServer, phase: DronePhase, fromStand: number, toStand: number, phaseStart: number, phaseEnd: number)
    self.state = {
        phase = phase,
        fromStand = fromStand,
        toStand = toStand,
        phaseStart = phaseStart,
        phaseEnd = phaseEnd,
    }
    self.floorFolder:SetAttribute("DroneState", HttpService:JSONEncode(self.state))
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
