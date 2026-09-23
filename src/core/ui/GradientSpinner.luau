local RunService = game:GetService("RunService")


local DEFAULT_SPEED = 90 -- degrees per second

local GradientSpinner = {}
local active: {[UIGradient]: number} = {} 
local connection: RBXScriptConnection? = nil


local function step(deltaTime: number)
    for gradient, speed in pairs(active) do
        if not gradient.Parent then 
            active[gradient] = nil
            continue
        end
        
        gradient.Rotation = (gradient.Rotation + speed * deltaTime) % 360
    end
end

function GradientSpinner.start()
    if connection then return end
    connection = RunService.RenderStepped:Connect(step)
end

function GradientSpinner.stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
end

function GradientSpinner.spin(gradient: UIGradient, speed: number): () -> ()
    if active[gradient] then
        active[gradient] = speed or DEFAULT_SPEED
        return function() end
    end

    active[gradient] = speed or DEFAULT_SPEED
    GradientSpinner.start()

    return function()
        if not active[gradient] then return end
        active[gradient] = nil
        if not next(active) then
            GradientSpinner.stop()
        end
    end
end



return GradientSpinner