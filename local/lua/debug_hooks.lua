local DebugHooks = {}

function DebugHooks.init(strTargetIp)
  -- Try to load the remote debugger.
  local tResult, tMobDebug = pcall(require, 'mobdebug')
  if tResult==true then
    tResult = tMobDebug.start(strTargetIp)

    -- The debugger will stop here.
    -- Set a breakpoint in the function "run_teststep" to stop before every step.
    local iDummy = 1
  end

  return tResult
end



function DebugHooks.run_teststep(tTestInstance, uiTestStep)
  -- Place a breakpoint here to stop at the start of every test step.
  local uiDummy = uiTestStep

  -- Debug into this function call to get to the test code.
  tTestInstance:run()
end


return DebugHooks
