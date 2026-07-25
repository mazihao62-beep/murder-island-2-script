local file = io.open("G:\谋杀之岛2\murder_island_v1.1.lua", "r")
if not file then return nil end
local content = file:read("*a")
file:close()
return content