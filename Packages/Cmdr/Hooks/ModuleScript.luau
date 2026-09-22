
local GROUP_ID = 476026804

local WHITELISTED_USER_IDS  = {
	[268447516] = true, -- @drifty_v
	[50726202] = true, -- @SwiftStandardLibrary
	[664097056] = true, -- @palatix
	
	-- Test players
	[-1] = true, -- @Player1
	[-2] = true, -- @Player1
}

local WHITELISTED_GROUP_RANKS = {
	255, -- Owner
	254, -- Developer
}


return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		-- UserId match
		if WHITELISTED_USER_IDS[context.Executor.UserId] or context.Executor.UserId == -1 then
			return 
		end

		-- Group rank match
		local success, rank = pcall(function()
			return context.Executor:GetRankInGroupAsync(476026804)
		end)
		
		if success and table.find(WHITELISTED_GROUP_RANKS, rank) then
			return 
		end
		
		return "You don't have permission to run this command"

	end)
end