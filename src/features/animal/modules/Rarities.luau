export type RarityInfo = {
    name: string,
    gradient: ColorSequence,
    odds: number,
}
local rarities = {

    Common = {
        name = "Common",
        odds = 1,
        gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.666667, 0.152941, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
    },


    Uncommon = {
        name = "Uncommon",
        odds = 1/10,
        gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 255, 19)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.333333, 0.392157, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(62, 255, 19)),
        }),
    },

    Rare = {
        name = "Rare",
        odds = 1/25,
        gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 197, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.521452, 0.396078, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 197, 255)),
        }),
    },

}


local sortedRarities = {}
for _, rarity in pairs(rarities) do
    table.insert(sortedRarities, rarity)
end

table.sort(sortedRarities, function(a, b)
    return a.odds > b.odds
end)


local Rarities = {}

function Rarities.getRarityForOdds(odds: number): RarityInfo?
    for i = #sortedRarities, 1, -1 do
        local rarity = sortedRarities[i]
        if odds <= rarity.odds then
            return rarity
        end
    end

    return sortedRarities[1]
end


function Rarities.getRarityInfo(rarity: string): RarityInfo?
    return rarities[rarity]
end


return Rarities





