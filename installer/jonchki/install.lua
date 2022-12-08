local t = ...
local tResult = true

-- Copy the test system to the root folder.
t:install('test_system.lua', '${install_base}/')

-- Copy the complete "lua" folder.
t:install('lua/', '${install_lua_path}/')

-- Copy the complete "jsx" folder.
t:install('jsx/', '${install_base}/jsx')

-- Copy the complete "doc" folder.
--t:install('doc/', '${install_doc}/')

return tResult
