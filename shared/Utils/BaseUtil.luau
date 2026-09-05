local BaseUtil = {}

function BaseUtil.showInstance(instance: Instance, visible: boolean)
	-- BaseParts
	for _, basePart: BasePart in instance:QueryDescendants("BasePart") do
		if not basePart:GetAttribute("OriginalTransparency") then
			basePart:SetAttribute("OriginalTransparency", basePart.Transparency)
		end
		if basePart:GetAttribute("OriginalCollision") == nil then
			basePart:SetAttribute("OriginalCollision", basePart.CanCollide)
		end
	
		basePart.Transparency = visible and basePart:GetAttribute("OriginalTransparency") or 1
		basePart.CanCollide = visible and basePart:GetAttribute("OriginalCollision") or false
	end

	-- Textures
	for _, texture: Texture in instance:QueryDescendants("Texture") do
		if not texture:GetAttribute("OriginalTransparency") then
			texture:SetAttribute("OriginalTransparency", texture.Transparency)
		end
		texture.Transparency = visible and texture:GetAttribute("OriginalTransparency") or 1
	end

	-- Decals
	for _, decal: Decal in instance:QueryDescendants("Decal") do
		if not decal:GetAttribute("OriginalTransparency") then
			decal:SetAttribute("OriginalTransparency", decal.Transparency)
		end
		decal.Transparency = visible and decal:GetAttribute("OriginalTransparency") or 1
	end

	-- Lights
	for _, light: Light in instance:QueryDescendants("Light") do
		light.Enabled = visible
	end

	-- SurfaceGuis
	for _, surfaceGui: SurfaceGui in instance:QueryDescendants("SurfaceGui") do
		surfaceGui.Enabled = visible
	end
end

function BaseUtil.getStandCost(floorIndex: number): number
	return 100 * floorIndex
end

return BaseUtil
