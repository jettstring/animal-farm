local ReplicatedStorage = game:GetService("ReplicatedStorage")


--function getAllNames(): {string}
--	local items = {}
--	for itemName, itemDef: ItemDefinitions.ItemDefinition in ItemDefinitions do
--		table.insert(items, itemName)
--	end
--	return items
--end

return {
	Name = "addFloor";
	Aliases = {};
	Description = "";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player to give item to.",
		},
		--function(context)
		--	return {
		--		Type = context.Cmdr.Util.MakeEnumType("Item", getAllNames()),
		--		Name = "Item";
		--		Description = "Item to give.";
		--		Optional = false;
		--	}
		--end,
	};
}
