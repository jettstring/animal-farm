--!strict
-- Bezier.lua
-- Supports Linear (2 pts), Quadratic (3 pts), Cubic (4 pts)

local Bezier = {}
Bezier.__index = Bezier

export type Bezier = {
	_points: {Vector3},  -- 2..4 points
	_samples: number,
	_parent: Instance?,

	_vizEnabled: boolean,
	_vizFolder: Folder?,
	_ctrlSpheres: {BasePart},
	_pathSpheres: {BasePart},
	_anchorParts: {BasePart},
	_attachments: {Attachment},
	_beams: {Beam},

	-- methods
	positionAt: (self: Bezier, t: number) -> Vector3,
	updateControlPoints: (self: Bezier, ...Vector3) -> (),
	toggleVisualization: (self: Bezier, visible: boolean) -> (),
	Destroy: (self: Bezier) -> (),
}

--===== Utils =====--

local function clamp01(x: number): number
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function makeSphere(pos: Vector3, color: Color3, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	--p.Size = Vector3.new(0.25, 0.25, 0.25)
	p.Size = Vector3.new(0.05, 0.05, 0.05)

	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 0.5
	p.Color = color
	p.CFrame = CFrame.new(pos)
	p.Name = "BezierSphere"
	p.Parent = parent
	return p
end

local function makeAnchorWithAttachment(pos: Vector3, parent: Instance?): (BasePart, Attachment)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Name = "BezierAnchor"
	part.CFrame = CFrame.new(pos)
	part.Parent = parent

	local att = Instance.new("Attachment")
	att.Name = "BezierAttachment"
	att.Parent = part

	return part, att
end

local function makeBeam(a0: Attachment, a1: Attachment, parent: Instance?): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 0.02
	b.Width1 = 0.02
	b.Color = ColorSequence.new(Color3.fromRGB(255, 208, 0))
	b.Transparency = NumberSequence.new(0)
	b.LightEmission = 0.1
	b.Name = "BezierBeam"
	b.Parent = parent
	return b
end

-- De Casteljau for Vector3 (works for any degree)
local function deCasteljau(points: {Vector3}, t: number): Vector3
	local tmp = table.create(#points)
	for i = 1, #points do
		tmp[i] = points[i]
	end
	for r = 1, #points - 1 do
		for i = 1, #points - r do
			tmp[i] = tmp[i] * (1 - t) + tmp[i + 1] * t
		end
	end
	return tmp[1]
end

--===== Class =====--

local function validatePoints(points: {Vector3})
	assert(#points >= 2 and #points <= 4, "Bezier: control points must be 2 (linear), 3 (quadratic), or 4 (cubic)")
end

function Bezier.new(points: {Vector3}, parent: Instance?, samples: number?): Bezier
	validatePoints(points)
	local self: Bezier = setmetatable({}, Bezier)
	self._points = { table.unpack(points) }
	self._samples = math.max(8, samples or 32)
	self._parent = parent

	self._vizEnabled = false
	self._vizFolder = nil
	self._ctrlSpheres = {}
	self._pathSpheres = {}
	self._anchorParts = {}
	self._attachments = {}
	self._beams = {}
	return self
end

function Bezier:_degree(): number
	return #self._points - 1
end

function Bezier:positionAt(t: number): Vector3
	t = clamp01(t)
	return deCasteljau(self._points, t)
end

-- Update all control points; pass 2, 3, or 4 Vector3s to change degree.
function Bezier:updateControlPoints(...: Vector3)
	local args = {...}
	validatePoints(args)
	self._points = args
	if self._vizEnabled then
		self:_refreshVisualization(true) -- true => rebuild control spheres if count changed
	end
end

function Bezier:toggleVisualization(visible: boolean)
	if visible == self._vizEnabled then return end
	self._vizEnabled = visible
	if visible then
		self:_buildVisualization()
	else
		self:_destroyVisualization()
	end
end

--===== Visualization internals =====--

function Bezier:_buildVisualization()
	local folder = Instance.new("Folder")
	folder.Name = "BezierViz"
	folder.Parent = self._parent or workspace
	self._vizFolder = folder

	-- Control points
	self:_buildControlSpheres()
	-- Sampled path (anchors, attachments, small spheres + beams)
	self:_rebuildSamples()
end

function Bezier:_buildControlSpheres()
	-- clear prior
	for _, s in ipairs(self._ctrlSpheres) do s:Destroy() end
	self._ctrlSpheres = {}
	if not self._vizFolder then return end

	-- Colors: endpoints gold, interior controls orange
	for i, p in ipairs(self._points) do
		local isEnd = (i == 1 or i == #self._points)
		local color = isEnd and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 128, 0)
		local s = makeSphere(p, color, self._vizFolder)
		s.Name = isEnd and "Endpoint" or "Control"
		table.insert(self._ctrlSpheres, s)
	end
end

function Bezier:_destroyVisualization()
	if self._vizFolder then
		self._vizFolder:Destroy()
	end
	self._vizFolder = nil
	self._ctrlSpheres = {}
	self._pathSpheres = {}
	self._anchorParts = {}
	self._attachments = {}
	self._beams = {}
end

function Bezier:_refreshVisualization(rebuildControls: boolean?)
	if not self._vizEnabled or not self._vizFolder then return end

	if rebuildControls then
		self:_buildControlSpheres()
	else
		-- move control spheres if counts same
		if #self._ctrlSpheres == #self._points then
			for i, p in ipairs(self._points) do
				self._ctrlSpheres[i].CFrame = CFrame.new(p)
			end
		else
			self:_buildControlSpheres()
		end
	end

	-- Update sampled geometry
	local n = self._samples
	for i = 0, n - 1 do
		local t = i/(n-1)
		local pos = self:positionAt(t)
		local anchor = self._anchorParts[i+1]
		if anchor then
			anchor.CFrame = CFrame.new(pos)
			self._pathSpheres[i+1].CFrame = CFrame.new(pos)
		end
	end
	-- Beams auto-follow attachments
end

function Bezier:_rebuildSamples()
	-- clear prior
	for _, b in ipairs(self._beams) do b:Destroy() end
	for _, s in ipairs(self._pathSpheres) do s:Destroy() end
	for _, a in ipairs(self._anchorParts) do a:Destroy() end
	self._beams = {}
	self._pathSpheres = {}
	self._anchorParts = {}
	self._attachments = {}

	if not self._vizFolder then return end
	local n = self._samples

	for i = 0, n - 1 do
		local t = i/(n-1)
		local pos = self:positionAt(t)

		local anchor, att = makeAnchorWithAttachment(pos, self._vizFolder)
		table.insert(self._anchorParts, anchor)
		table.insert(self._attachments, att)

		local s = makeSphere(pos, Color3.fromRGB(0, 200, 255), self._vizFolder)
		s.Name = "BezierPathPoint"
		if i % 2 == 1 then s.Transparency = 0.25 end
		table.insert(self._pathSpheres, s)
	end

	for i = 1, n - 1 do
		local beam = makeBeam(self._attachments[i], self._attachments[i+1], self._vizFolder)
		table.insert(self._beams, beam)
	end
end

function Bezier:Destroy()
	self:_destroyVisualization()
	setmetatable(self, nil :: any)
end

return Bezier
