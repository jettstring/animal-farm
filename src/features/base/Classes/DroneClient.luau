local EncodingService = game:GetService("EncodingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Observers = require(ReplicatedStorage.Packages.Observers)


local DroneUtils = require(ReplicatedStorage.Source.Features.Base.Modules.DroneUtils)
local BaseTypes = require(ReplicatedStorage.Source.Features.Base.Modules.BaseTypes)

type DroneState = BaseTypes.DroneState
type Phase = BaseTypes.DronePhase


local DroneClient = {}
DroneClient.__index = DroneClient

type self = {
    trove: Trove.Trove,
    floorFolder: Folder,
    waypointParts: {[number]: Part},
    droneRoot: Part,
    droneModel: Model,
    droneState: DroneState,
    tracks: { [string]: AnimationTrack }
}

export type DroneClient = typeof(setmetatable({} :: self, DroneClient))

function DroneClient.new(floorFolder: Folder)
	local self = setmetatable({} :: self, DroneClient)

	self.trove = Trove.new()
	self.floorFolder = floorFolder
    self.waypointParts = {}

    self:_setupDrone()

	local standsContainer = floorFolder:WaitForChild("AnimalStands")
	for _, standFolder: Folder in standsContainer:GetChildren() do
		local standIndex: number = tonumber(standFolder.Name)
		if not standIndex then warn("[mountDrone] invalid stand index: ", standIndex); continue end
		if not self.waypointParts[standIndex] then
			self.waypointParts[standIndex] = standFolder:WaitForChild("DroneWaypoint")
		end
	end

    self.trove:Add(Observers.observeAttribute(floorFolder, "DroneState", function(newState: string)
        local state = HttpService:JSONDecode(newState) :: DroneState
        self.droneState = state
    end))

    self.trove:Add(RunService.Heartbeat:Connect(function()
        if not self.droneState then return end
        
        local toStand = self.droneState.toStand
        local fromStand = self.droneState.fromStand
        local phaseStart = self.droneState.phaseStart
        local phaseEnd = self.droneState.phaseEnd

        -- resolve which 2 waypoint parts the drone would be based on progress (since all the waypoint parts create a curved path, but a straight line is formed between the 2 nearest waypoints)
        local progress = DroneUtils.getPhaseProgress(phaseStart, phaseEnd, workspace:GetServerTimeNow())
        local standsBetween = toStand - fromStand
        local droneStandPosition = fromStand + standsBetween * progress
        local dir = math.sign(standsBetween)

        local behindIndex = if dir >= 0 then math.floor(droneStandPosition) else math.ceil(droneStandPosition)
        local aheadIndex = if dir >= 0 then behindIndex + 1 else behindIndex - 1 

        local behindWaypoint = self.waypointParts[behindIndex]
        local aheadWaypoint = self.waypointParts[aheadIndex]

        local progressBetween = math.abs(droneStandPosition - behindIndex)
        if progressBetween <= 0 or not aheadWaypoint then
            self.droneRoot:PivotTo(behindWaypoint.CFrame)
            return
        end

        local droneCFrame = behindWaypoint.CFrame:Lerp(aheadWaypoint.CFrame, progressBetween)
        self.droneRoot:PivotTo(droneCFrame)
    end))

	return self
end

function DroneClient._setupDrone(self: DroneClient)
    local baseAssets = ReplicatedStorage.Assets.Base
    local droneAssets = baseAssets.Drone

    local droneModel = self.trove:Add(droneAssets.DroneModel:Clone())
    self.droneModel = droneModel

    local droneRoot = self.trove:Add(Instance.new("Part"))
	droneRoot.Name = "DroneRoot"
	droneRoot.Anchored = true
	droneRoot.CanCollide = false
	droneRoot.Transparency = 0
	droneRoot.Material = Enum.Material.ForceField
	droneRoot.Parent = self.floorFolder
    self.droneRoot = droneRoot

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = droneRoot
	weld.Part1 = droneModel.PrimaryPart
	weld.Parent = droneModel.PrimaryPart
	droneModel:PivotTo(droneRoot.CFrame)
    droneModel.Parent = self.floorFolder

	local animator = droneModel.AnimationController:WaitForChild("Animator")
    local animations = droneAssets.Animations
    self.tracks = {
		left = animator:LoadAnimation(animations.Left),
		right = animator:LoadAnimation(animations.Right),
		vacuum = animator:LoadAnimation(animations.Vacuuming)
	}
end

function DroneClient.spawnEggs(self: DroneClient)
    
end

function DroneClient.destroy(self: DroneClient)
    self.trove:Destroy()
end

return DroneClient