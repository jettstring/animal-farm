
local DroneUtils = {}

function DroneUtils.getPhaseProgress(startsAt: number, endsAt: number, now: number): number
    if endsAt <= startsAt then
        return 1
    end
    return (now - startsAt) / (endsAt - startsAt)
end

function DroneUtils.CalculateCollectTime(level: number): number
    --return math.max((1 / (1 + 0.1 * level)), 0.5)
    return 3
end

function DroneUtils.CalculateStepTime(level: number): number
    -- return math.max((3 / (1 + 0.1 * level)), 0.5)
    return 1
end

return DroneUtils