local DebugHooks = {}

function DebugHooks.init(strTargetIp,uiPortNumb)
  -- Try to load the remote debugger.
  local tResult, tLuaPanda = pcall(require, 'LuaPanda')

  if tResult==true then

	-- start the client with the given IP and port number
	LuaPanda.start(strTargetIp,uiPortNumb)

	-- check the connection
	tResult = LuaPanda.isConnected()

	DebugHooks.tLuaPanda = tLuaPanda

  end

  return tResult
end



function DebugHooks.run_teststep(tTestInstance, uiTestStep)
  -- Hard breakpoint to stop at the start of every test step at this position.
if DebugHooks.tLuaPanda ~= nil then
  DebugHooks.tLuaPanda.BP()
end
  -- Debug into this function call to get to the test code.
  tTestInstance:run()
end


return DebugHooks
