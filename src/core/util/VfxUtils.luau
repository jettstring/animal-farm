local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VfxContainer = ReplicatedStorage.Assets:WaitForChild("VFX")


local CACHE_INTERVAL = 1

local VfxUtils = {}
local cached = {}


function VfxUtils.getVfx(name: string): Instance?
    local existing = cached[name]
    if existing and #existing > 0 then
        local existingVfx = table.remove(existing, 1) :: Instance
        existingVfx.Parent = nil
        return existingVfx
    end

    local vfxInstance = VfxContainer:FindFirstChild(name) :: Instance?
    if not vfxInstance then
        warn("VFX not found: " .. name)
        return nil
    end

    return vfxInstance
end

function VfxUtils.cacheVfx(vfxInstance: Instance)
    local name = vfxInstance.Name
    if not cached[name] then
        cached[name] = {}
    end
    table.insert(cached[name], vfxInstance)
    vfxInstance.Parent = nil
end

function VfxUtils.clearCache()
    for name, vfxList in cached do
        for _, vfxInstance in vfxList do
            vfxInstance:Destroy()
        end
    end

    cached = {}
end


function VfxUtils.emitVfx(name: string, target: (Vector3 | BasePart), playSounds: boolean?): Instance?
    local vfxInstance = VfxUtils.getVfx(name)
    if not vfxInstance then
        return nil
    end

    local clone = vfxInstance:Clone()
    clone.Parent = Workspace.CurrentCamera

    -- Set target location
    if typeof(target) == "Vector3" then
        clone.Position = target
    elseif typeof(target) == "Instance" and target:IsA("BasePart") then
        clone.Parent = target
        clone:PivotTo(target:GetPivot())
    else
        warn("Invalid target for VFX: " .. tostring(target))
        return nil
    end

    local maxTime = 0
    for _, particleEmitter: ParticleEmitter in clone:QueryDescendants("ParticleEmitter") do
        particleEmitter:Emit(particleEmitter:GetAttribute("EmitCount") or particleEmitter.Rate or 1)
        maxTime = math.max(maxTime, particleEmitter.Lifetime.Max)
    end

    if playSounds == nil or playSounds then
        for _, sound: Sound in clone:QueryDescendants("Sound") do
            sound:Play()
        end
    end

    task.delay(maxTime, function()
        VfxUtils.cacheVfx(clone)
    end)

    return clone
end


task.spawn(function()
    while true do
        task.wait(CACHE_INTERVAL)
        VfxUtils.clearCache()
    end
end)

return VfxUtils
