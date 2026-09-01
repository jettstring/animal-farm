local Util = require(script.Parent.Parent.Shared.Util)

return function(registry)
	registry:RegisterType("currency", registry.Cmdr.Util.MakeEnumType("currency", {
		"Money",
		"Research",
		"Dogtags",
	}))
end