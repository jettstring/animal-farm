-- // Visual Config
local CONE_HEIGHT = 0.5
local LINE_THICKNESS = 2
local TRANSPARENCY = 0.2
local ALWAYS_ON_TOP = true
local Debris = game:GetService("Debris")
-- // CastVisualiser Class
local CastVisualiser = {}

-- // Private Methods \\ --

-- // Public Methods \\ --
function CastVisualiser:Hide()
	self.CastOriginPart.Parent = nil
end

function CastVisualiser:Raycast(Origin: Vector3, Direction: Vector3, RaycastParameters: RaycastParams?, duration: number?)
	local self: CastVisualiserPrivate = self
	
	local Cast = self.WorldRoot:Raycast(Origin, Direction, RaycastParameters)
	
	local rayFinalPosition: Vector3
	local rayDistance: number
	if not Cast then
		rayFinalPosition = Origin + Direction
		rayDistance = (Direction).Magnitude
	else
		rayFinalPosition = Cast.Position
		rayDistance = Cast.Distance

	end
	
	self.CastOriginPart.CFrame = CFrame.lookAt(Origin, rayFinalPosition)

	self.LineVisual.Length = rayDistance
	if self.ConeVisual then
		self.ConeVisual.CFrame = CFrame.new(0, 0, -rayDistance + CONE_HEIGHT)		
	end
	
	self.BoxVisual.Visible = false
	self.SphereVisual.Visible = false
	self.CastOriginPart.Parent = self.WorldRoot:FindFirstChild("RayIgnore") or self.WorldRoot
end


function CastVisualiser:Blockcast(CF: CFrame, Size: Vector3, Direction: Vector3, RaycastParameters: RaycastParams?)
	local self: CastVisualiserPrivate = self
	
	local Cast = self.WorldRoot:Blockcast(CF, Size, Direction, RaycastParameters)
	if not Cast then
		self:Hide()
		return
	end
	
	self.CastOriginPart.CFrame = CF
	
	local LookAt = CFrame.lookAt(Vector3.zero, Direction.Unit)
	local BoxCF = CFrame.new(Direction.Unit * Cast.Distance)
	
	self.LineVisual.Length = Cast.Distance - CONE_HEIGHT
	self.LineVisual.CFrame = LookAt
	
	self.ConeVisual.CFrame = CFrame.lookAt(BoxCF.Position - (Direction.Unit * CONE_HEIGHT), BoxCF.Position + Direction)
	
	self.BoxVisual.CFrame = BoxCF
	self.BoxVisual.Size = Size
	
	self.BoxVisual.Visible = true
	self.SphereVisual.Visible = false
	
	self.CastOriginPart.Parent = self.WorldRoot:FindFirstChild("RayIgnore") or self.WorldRoot
end


function CastVisualiser:SphereCast(Origin: Vector3, Radius: number, Direction: Vector3, RaycastParameters: RaycastParams?)
	local self: CastVisualiserPrivate = self
	
	local Cast = self.WorldRoot:Spherecast(Origin, Radius, Direction, RaycastParameters)
	if not Cast then
		self:Hide()
		return
	end
	
	local FinalPos = Origin + (Direction.Unit * Cast.Distance)

	self.CastOriginPart.CFrame = CFrame.lookAt(Origin, FinalPos)

	self.LineVisual.Length = Cast.Distance - CONE_HEIGHT
	self.ConeVisual.CFrame = CFrame.new(0, 0, -Cast.Distance)
	
	self.SphereVisual.CFrame = CFrame.new(0, 0, -Cast.Distance)
	self.SphereVisual.Radius = Radius
	
	self.SphereVisual.Visible = true
	self.BoxVisual.Visible = false
	
	self.CastOriginPart.Parent = self.WorldRoot:FindFirstChild("RayIgnore") or self.WorldRoot
end

-- Types
export type CastVisualiser = typeof(CastVisualiser)
type CastVisualiserPrivate = CastVisualiser & {
	Color: Color3,
	WorldRoot: WorldRoot,
	CastOriginPart: BasePart,
	
	LineVisual: LineHandleAdornment,
	ConeVisual: ConeHandleAdornment,
	BoxVisual: BoxHandleAdornment,
	SphereVisual: SphereHandleAdornment,
}


-- // Main
local Visuals = {}

--[[

	CastVisualiser Visuals.new(Color: Color3?, WorldRoot: WorldRoot?)
		Creates and returns a CastVisualiser class.

--]]

local Meta = {__index = CastVisualiser}

function Visuals.new(
	Color: Color3?,
	lineThickness: number?,
	origin: boolean?, 
	cones: boolean?,
	lifespan: number?,
	alwaysOnTop: boolean?,
	WorldRoot: WorldRoot?
): CastVisualiser
	local self: CastVisualiserPrivate = setmetatable({
		Color = Color or Color3.new(0, 0, 1),
		WorldRoot = WorldRoot or workspace,
	}, Meta)
	
	-- Origin Part
	
	if lineThickness == nil then
		lineThickness = LINE_THICKNESS
	end

	
	local CastOriginPart = Instance.new("Part")
	CastOriginPart.Color = Color3.new(1,0,0)
	CastOriginPart.Transparency = 0
	CastOriginPart.CanCollide = false
	CastOriginPart.CanQuery = false
	CastOriginPart.CanTouch = false
	CastOriginPart.Anchored = true
	CastOriginPart.Material = Enum.Material.Neon
	CastOriginPart.Shape = Enum.PartType.Ball
	CastOriginPart.Size = Vector3.one * 0.1
	
	if origin == false then
		CastOriginPart.Transparency = 1
	end

	self.CastOriginPart = CastOriginPart

	
	-- Visuals
	if alwaysOnTop == nil then
		alwaysOnTop = ALWAYS_ON_TOP
	end
	local LineHandleAdornment = Instance.new("LineHandleAdornment")
	LineHandleAdornment.Color3 = self.Color
	LineHandleAdornment.AlwaysOnTop = alwaysOnTop
	LineHandleAdornment.Transparency = TRANSPARENCY
	LineHandleAdornment.Thickness = lineThickness
	LineHandleAdornment.ZIndex = 1
	LineHandleAdornment.Adornee = CastOriginPart
	LineHandleAdornment.Parent = CastOriginPart
	self.LineVisual = LineHandleAdornment
	
	if cones == nil then
		cones = true
	end
	if cones then
		local ConeHandleAdornmnet = Instance.new("ConeHandleAdornment")
		ConeHandleAdornmnet.Color3 = self.Color
		ConeHandleAdornmnet.AlwaysOnTop = ALWAYS_ON_TOP
		ConeHandleAdornmnet.Transparency = TRANSPARENCY
		ConeHandleAdornmnet.Radius = 0.1
		ConeHandleAdornmnet.Height = CONE_HEIGHT
		ConeHandleAdornmnet.SizeRelativeOffset = Vector3.new(0, 0, CONE_HEIGHT * 0.5)
		ConeHandleAdornmnet.ZIndex = 1
		ConeHandleAdornmnet.Adornee = CastOriginPart
		ConeHandleAdornmnet.Parent = CastOriginPart

		self.ConeVisual = ConeHandleAdornmnet
	end

	
	local BoxHandleAdornment = Instance.new("BoxHandleAdornment")
	BoxHandleAdornment.Color3 = self.Color
	BoxHandleAdornment.AlwaysOnTop = ALWAYS_ON_TOP
	BoxHandleAdornment.Transparency = TRANSPARENCY
	BoxHandleAdornment.ZIndex = 0
	BoxHandleAdornment.Adornee = CastOriginPart
	BoxHandleAdornment.Parent = CastOriginPart
	
	self.BoxVisual = BoxHandleAdornment
	
	local SphereHandleAdornment = Instance.new("SphereHandleAdornment")
	SphereHandleAdornment.Color3 = self.Color
	SphereHandleAdornment.AlwaysOnTop = ALWAYS_ON_TOP
	SphereHandleAdornment.Transparency = TRANSPARENCY
	SphereHandleAdornment.ZIndex = 0
	SphereHandleAdornment.Adornee = CastOriginPart
	SphereHandleAdornment.Parent = CastOriginPart
	
	self.SphereVisual = SphereHandleAdornment
	
	if lifespan then
		Debris:AddItem(CastOriginPart, lifespan)
	end
	
	return self
end

return Visuals