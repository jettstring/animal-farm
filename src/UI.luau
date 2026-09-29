for _, uiModule in script:GetDescendants() do
    if not uiModule:IsA("ModuleScript") then
        continue
    end

    local element = require(uiModule)
    if type(element) == "table" and element.init then
        element.init()
    end
end
 