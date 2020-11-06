-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_cli_init'


local class = require 'pl.class'
local TestSystem = class()

function TestSystem:_init(usServerPort)
  self.debug_hooks = require 'debug_hooks'
  self.pl = require'pl.import_into'()
  self.json = require 'dkjson'
  self.zmq = require 'lzmq'
  self.TestDescription = require 'test_description'

  -- Register the tester as a global module.
  local cTester = require 'tester_webgui'
  _G.tester = cTester()

  self.m_zmqPort = usServerPort
  self.m_zmqContext = nil
  self.m_zmqSocket = nil
  self.m_atTestExecutionParameter = nil
  self.m_atSystemParameter = nil
end



function TestSystem:connect()
  local usServerPort = self.m_zmqPort
  local strAddress = string.format('tcp://127.0.0.1:%d', usServerPort)
  print(string.format("Connecting to %s", strAddress))

  -- Create the 0MQ context.
  local zmq = self.zmq
  local tZContext, strErrorCtx = zmq.context()
  if tZContext==nil then
    error('Failed to create ZMQ context: ' .. tostring(strErrorCtx))
  end
  self.m_zmqContext = tZContext

  -- Create the socket.
  local tZSocket, strErrorSocket = tZContext:socket(zmq.PAIR)
  if tZSocket==nil then
    error('Failed to create ZMQ socket: ' .. tostring(strErrorSocket))
  end

  -- Connect the socket to the server.
  local tResult, strErrorConnect = tZSocket:connect(strAddress)
  if tResult==nil then
    error('Failed to connect the socket: ' .. tostring(strErrorConnect))
  end
  self.m_zmqSocket = tZSocket
  _G.tester:setSocket(tZSocket)

  print(string.format('0MQ socket connected to tcp://127.0.0.1:%d', usServerPort))
end



function TestSystem:createLogger()
  local m_zmqSocket = self.m_zmqSocket

  ------------------------------------------------------------------------------
  -- Now create the logger. It sends the data to the ZMQ socket.
  -- It does not use the formatter function 'fmt' or the date 'now'. This is
  -- done at the server side.
  local tLogWriterFn = function(fmt, msg, lvl, now)
    m_zmqSocket:send(string.format('LOG%d,%s', lvl, msg))
  end
  self.tLogWriterFn = tLogWriterFn

  -- This is the default log level. Note that the filtering should happen in
  -- the GUI and all messages which are already filtered with this level here
  -- will never be available in the GUI.
  local strLogLevel = 'debug'
  self.strLogLevel = strLogLevel

  -- Create a new log target with "SYSTEM" prefix.
  local tLogWriterSystem = require 'log.writer.prefix'.new('[System] ', tLogWriterFn)
  local tLogSystem = require "log".new(
    strLogLevel,
    tLogWriterSystem,
    require "log.formatter.format".new()
  )
  _G.tester:setLog(tLogSystem)
  self.tLogSystem = tLogSystem
end


------------------------------------------------------------------------------

function TestSystem:sendTitles(strTitle, strSubtitle)
  if strTitle==nil then
    strTitle = 'No title'
  else
    strTitle = tostring(strTitle)
  end
  if strSubtitle==nil then
    strSubtitle = 'No subtitle'
  else
    strSubtitle = tostring(strSubtitle)
  end

  local tData = {
    title=strTitle,
    subtitle=strSubtitle
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('TTL'..strJson)
end



function TestSystem:sendSerials(ulSerialFirst, ulSerialLast)
  local tData = {
    hasSerial=true,
    firstSerial=ulSerialFirst,
    lastSerial=ulSerialLast
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('SER'..strJson)
end



function TestSystem:sendTestNames(astrTestNames)
  local strJson = self.json.encode(astrTestNames)
  self.m_zmqSocket:send('NAM'..strJson)
end



function TestSystem:sendTestStati(astrTestStati)
  local strJson = self.json.encode(astrTestStati)
  self.m_zmqSocket:send('STA'..strJson)
end



function TestSystem:sendCurrentSerial(uiCurrentSerial)
  local tData = {
    currentSerial=uiCurrentSerial
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('CUR'..strJson)
end


--[[
function TestSystem:sendRunningTest(uiRunningTest)
  local tData = {
    runningTest=uiRunningTest
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('RUN'..strJson)
end



function TestSystem:sendTestState(strTestState)
  local tData = {
    testState=strTestState
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('RES'..strJson)
end
--]]



function TestSystem:sendTestDeviceStart()
  self.m_zmqSocket:send('TDS')
end



function TestSystem:sendTestDeviceFinished()
  self.m_zmqSocket:send('TDF')
end



function TestSystem:sendTestStepStart(uiStepIndex)
  local tData = {
    stepIndex=uiStepIndex
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('TSS'..strJson)
end



function TestSystem:sendTestStepFinished(strTestStepState)
  local tData = {
    testStepState=strTestStepState
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('TSF'..strJson)
end



function TestSystem:load_test_module(uiTestIndex)
  local tLogSystem = self.tLogSystem

  local strModuleName = string.format("test%02d", uiTestIndex)
  tLogSystem.debug('Reading module for test %d from %s .', uiTestIndex, strModuleName)

  local tClass = require(strModuleName)
  local tModule = tClass(uiTestIndex, self.tLogWriterFn, self.strLogLevel)
  return tModule
end



function TestSystem:collect_testcases(tTestDescription, aActiveTests)
  local tLogSystem = self.tLogSystem
  local tResult

  -- Get the number of tests from the test description.
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  -- Get the number of tests specified in the GUI response.
  local uiTestsFromGui = #aActiveTests
  -- Both test counts must match or there is something wrong.
  if uiNumberOfTests~=uiTestsFromGui then
    tLogSystem.error('The test description specifies %d tests, but the selection covers %d tests.', uiNumberOfTests, uiTestsFromGui)
  else
    local aModules = {}
    local astrTestNames = tTestDescription:getTestNames()
    local fAllModulesOk = true
    for uiTestIndex, fTestCaseIsActive in ipairs(aActiveTests) do
      local strTestName = astrTestNames[uiTestIndex]
      -- Only process test cases which are active.
      if fTestCaseIsActive==true then
        local fOk, tValue = pcall(self.load_test_module, self, uiTestIndex)
        if fOk~=true then
          tLogSystem.error('Failed to load the module for test case %d: %s', uiTestIndex, tostring(tValue))
          fAllModulesOk = false
        else
          local tModule = tValue

          -- The ID defined in the class must match the ID from the test description.
          local strDefinitionId = tTestDescription:getTestCaseName(uiTestIndex)
          local strModuleId = tModule.CFG_strTestName
          if strModuleId~=strDefinitionId then
            tLogSystem.fatal('The ID of test %d differs between the test definition and the module.', uiTestIndex)
            tLogSystem.debug('The ID of test %d in the test definition is "%s".', uiTestIndex, strDefinitionId)
            tLogSystem.debug('The ID of test %d in the module is "%s".', uiTestIndex, strModuleId)
            fAllModulesOk = false
          else
            aModules[uiTestIndex] = tModule
          end
        end
      else
        tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestName)
      end
    end

    if fAllModulesOk==true then
      tResult = aModules
    end
  end

  return tResult
end



function TestSystem:apply_parameters(atModules, tTestDescription, ulSerial)
  local tLogSystem = self.tLogSystem
  local tResult = true

  local astrTestNames = tTestDescription:getTestNames()

  -- Loop over all active tests and apply the tests from the XML.
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
    local tModule = atModules[uiTestIndex]
    local strTestCaseName = astrTestNames[uiTestIndex]

    if tModule==nil then
      tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestCaseName)
    else
      -- Get the parameters for the module.
      local atParametersModule = tModule.atParameter or {}

      -- Get the parameters from the XML.
      local atParametersXml = tTestDescription:getTestCaseParameters(uiTestIndex)
      for _, tParameter in ipairs(atParametersXml) do
        local strParameterName = tParameter.name
        local strParameterValue = tParameter.value
        local strParameterConnection = tParameter.connection

        -- Does the parameter exist?
        tParameter = atParametersModule[strParameterName]
        if tParameter==nil then
          tLogSystem.fatal('The parameter "%s" does not exist in test case %d (%s).', strParameterName, uiTestIndex, strTestCaseName)
          tResult = nil
          break
        -- Is the parameter an "output"?
        elseif tParameter.fIsOutput==true then
          self.tLogSystem.fatal('The parameter "%s" in test case %d (%s) is an output.', strParameterName, uiTestIndex, strTestCaseName)
          tResult = nil
          break
        else
          if strParameterValue~=nil then
            -- This is a direct assignment of a value.
            tParameter:set(strParameterValue)
          elseif strParameterConnection~=nil then
            -- This is a connection to another value or an output parameter.
            local strClass, strName = string.match(strParameterConnection, '^([^:]+):(.+)')
            if strClass==nil then
              tLogSystem.fatal('Parameter "%s" of test %d has an invalid connection "%s".', strParameterName, uiTestIndex, strParameterConnection)
              tResult = nil
              break
            else
              -- Is this a connection to a system parameter?
              if strClass=='system' then
                local tValue = self.m_atSystemParameter[strName]
                if tValue==nil then
                  tLogSystem.fatal('The connection target "%s" has an unknown name.', strParameterConnection)
                  tResult = nil
                  break
                else
                  tParameter:set(tostring(tValue))
                end
              else
                -- This is not a system parameter.
                -- Try to interpret the class as a test number.
                local uiConnectionTargetTestCase = tonumber(strClass)
                if uiConnectionTargetTestCase==nil then
                  -- The class is no number. Search the name.
                  uiConnectionTargetTestCase = tTestDescription:getTestCaseIndex(strClass)
                  if uiConnectionTargetTestCase==nil then
                    tLogSystem.fatal('The connection "%s" uses an unknown test name: "%s".', strParameterConnection, strClass)
                    tResult = nil
                    break
                  end
                end
                if uiConnectionTargetTestCase~=nil then
                  -- Get the target module.
                  local tTargetModule = atModules[uiConnectionTargetTestCase]
                  if tTargetModule==nil then
                    tLogSystem.info('Ignoring the connection "%s" to an inactive target: "%s".', strParameterConnection, strClass)
                  else
                    -- Get the parameter list of the target module.
                    local atTargetParameters = tTargetModule.atParameter or {}
                    -- Does the target module have a matching parameter?
                    local tTargetParameter = atTargetParameters[strName]
                    if tTargetParameter==nil then
                      tLogSystem.fatal('The connection "%s" uses a non-existing parameter at the target: "%s".', strParameterConnection, strName)
                      tResult = nil
                      break
                    else
                      self.tLogSystem.info('Connecting %02d:%s to %02d:%s .', uiTestIndex, strParameterName, uiConnectionTargetTestCase, tTargetParameter.strName)
                      tParameter:connect(tTargetParameter)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return tResult
end



function TestSystem:check_parameters(atModules, tTestDescription)
  local tLogSystem = self.tLogSystem
  -- Check all parameters.
  local fParametersOk = true

  local astrTestNames = tTestDescription:getTestNames()
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  for uiTestIndex = 1, uiNumberOfTests do
    local tModule = atModules[uiTestIndex]
    local strTestCaseName = astrTestNames[uiTestIndex]
    if tModule==nil then
      tLogSystem.debug('Skipping deactivated test %02d:%s .', uiTestIndex, strTestCaseName)
    else
      for _, tParameter in ipairs(tModule.CFG_aParameterDefinitions) do
        -- Ignore output parameter. They will be set when the test is executed.
        if tParameter.fIsOutput==true then
          self.tLogSystem.debug('Ignoring output parameter %02d:%s .', uiTestIndex, tParameter.strName)

        -- Ignore also parameters connected to something. They might get their values when the test is executed.
        elseif tParameter:isConnected()==true then
          self.tLogSystem.debug('Ignoring the connected parameter %02d:%s .', uiTestIndex, tParameter.strName)

        else
          -- Validate the parameter.
          local fValid, strError = tParameter:validate()
          if fValid==false then
            tLogSystem.fatal('The parameter %02d:%s is invalid: %s', uiTestIndex, tParameter.strName, strError)
            fParametersOk = nil
          end
        end
      end
    end
  end

  if fParametersOk~=true then
    tLogSystem.fatal('One or more parameters were invalid. Not running the tests!')
  end

  return fParametersOk
end



function TestSystem:run_action(strAction)
  local pl = self.pl
  local tLogSystem = self.tLogSystem
  local tActionResult = nil
  local strMessage = nil

  if strAction==nil then
    tActionResult = true

  else
    local strExt = string.sub(strAction, -4)

    -- If the action is a JSX file, this is a static GUI element.
    if strExt=='.jsx' then
      local tResult = _G.tester:setInteraction(strAction)
      if tResult==nil then
        strMessage = 'Failed to load the JSX.'
      else
        tActionResult = true
      end

    elseif strExt=='.lua' then
      -- Read the LUA file.
      if pl.path.exists(strAction)~=strAction then
        strMessage = string.format('The action file "%s" does not exist.', strAction)
      elseif pl.path.isfile(strAction)~=true then
        strMessage = string.format('The action "%s" is not a file.', strAction)
      else
        local strLuaSrc, strMsg = pl.utils.readfile(strAction, false)
        if strLuaSrc==nil then
          strMessage = string.format('Failed to read the action file "%s": %s', strAction, strMsg)
        else
          -- Parse the LUA source.
          local _loadstring = loadstring or load
          local tChunk, strMsg = _loadstring(strLuaSrc, strAction)
          if tChunk==nil then
            strMessage = string.format('Failed to parse the LUA action from "%s": %s', strAction, strMsg)
          else
            -- Run the LUA chunk.
            local fStatus, tResult = xpcall(tChunk, function(tErr) tLogSystem.debug(debug.traceback()) return tErr end)
            if fStatus==true then
              tActionResult = tResult
            else
              if tResult~=nil then
                strMessage = tostring(tResult)
              else
                strMessage = 'No error message.'
              end
            end
          end
        end
      end
    else
      error('Unknown action: ' .. tostring(strAction))
    end
  end

  return tActionResult, strMessage
end



function TestSystem:run_tests(atModules, tTestDescription)
  local pl = self.pl
  local tLogSystem = self.tLogSystem
  -- Run all enabled modules with their parameter.
  local fTestIsNotCanceled = true

  -- Run a pre action if present.
  local strAction = tTestDescription:getPre()
  local fTestResult, tResult = self:run_action(strAction)
  if fTestResult~=true then
    local strError
    if tResult~=nil then
      strError = tostring(tResult)
    else
      strError = 'No error message.'
    end
    tLogSystem.error('Error running the global pre action: %s', strError)

  else
    local astrTestNames = tTestDescription:getTestNames()
    local uiNumberOfTests = tTestDescription:getNumberOfTests()
    for uiTestIndex = 1, uiNumberOfTests do
      repeat
        local fExitTestCase = true

        -- Get the module for the test index.
        local tModule = atModules[uiTestIndex]
        local strTestCaseName = astrTestNames[uiTestIndex]
        if tModule==nil then
          tLogSystem.info('Not running deactivated test case %02d (%s).', uiTestIndex, strTestCaseName)
        else
          tLogSystem.info('Running testcase %d (%s).', uiTestIndex, strTestCaseName)

          -- Get the parameters for the module.
          local atParameters = tModule.atParameter
          if atParameters==nil then
            atParameters = {}
          end

          -- Validate all input parameters.
          for strParameterName, tParameter in pairs(atParameters) do
            if tParameter.fIsOutput~=true then
              local fValid, strError = tParameter:validate()
              if fValid==false then
                tLogSystem.fatal('Failed to validate the parameter %02d:%s : %s', uiTestIndex, strParameterName, strError)
                fTestResult = false
                break
              end
            end
          end

          -- Show all parameters for the test case.
          tLogSystem.info("__/Parameters/________________________________________________________________")
          if pl.tablex.size(atParameters)==0 then
            tLogSystem.info('Testcase %d (%s) has no parameter.', uiTestIndex, strTestCaseName)
          else
            tLogSystem.info('Parameters for testcase %d (%s):', uiTestIndex, strTestCaseName)
            for _, tParameter in pairs(atParameters) do
              -- Do not dump output parameter. They have no value yet.
              if tParameter.fIsOutput~=true then
                tLogSystem.info('  %02d:%s = %s', uiTestIndex, tParameter.strName, tParameter:get_pretty())
              end
            end
          end
          tLogSystem.info("______________________________________________________________________________")

--          self:sendRunningTest(uiTestIndex)
--          self:sendTestState('idle')
          self:sendTestStepStart(uiTestIndex)

          -- Run a pre action if present.
          local strAction = tTestDescription:getTestCaseActionPre(uiTestIndex)
          local fStatus
          fStatus, tResult = self:run_action(strAction)
          if fStatus==true then
            -- Execute the test code. Write a stack trace to the debug logger if the test case crashes.
            fStatus, tResult = xpcall(self.debug_hooks.run_teststep, function(tErr) tLogSystem.debug(debug.traceback()) return tErr end, tModule, uiTestIndex)
            tLogSystem.info('Testcase %d (%s) finished.', uiTestIndex, strTestCaseName)
            if fStatus==true then
              -- Run a post action if present.
              local strAction = tTestDescription:getTestCaseActionPost(uiTestIndex)
              fStatus, tResult = self:run_action(strAction)
            end
          end
          -- Run a complete garbare collection after the test case.
          collectgarbage()

          -- Validate all output parameters.
          for strParameterName, tParameter in pairs(atParameters) do
            if tParameter.fIsOutput==true then
              local fValid, strError = tParameter:validate()
              if fValid==false then
                tLogSystem.warning('Failed to validate the output parameter %02d:%s : %s', uiTestIndex, strParameterName, strError)
              end
            end
          end

          -- Send the result to the GUI.
          local strTestState = 'error'
          if fStatus==true then
            strTestState = 'ok'
          end
--          self:sendTestState(strTestState)
--          self:sendRunningTest(nil)
          self:sendTestStepFinished(strTestState)

          if fStatus~=true then
            local strError
            if tResult~=nil then
              strError = tostring(tResult)
            else
              strError = 'No error message.'
            end
            tLogSystem.error('Error running the test: %s', strError)

            local tResult = tester:setInteractionGetJson('jsx/test_failed.jsx', {})
            if tResult==nil then
              tLogSystem.fatal('Failed to read interaction.')
            else
              local tJson = tResult
              pl.pretty.dump(tJson)
              _G.tester:clearInteraction()

              if tJson.button=='again' then
                fExitTestCase = false
              elseif tJson.button=='error' then
                fTestResult = false
              else
                fTestResult = false
                fTestIsNotCanceled = false
              end
            end
          end
        end
      until fExitTestCase==true

      if fTestResult~=true then
        break
      end
    end

    -- Close the connection to the netX.
    _G.tester:closeCommonPlugin()

    -- HACK: the post action needs to know if the board should be finalized or
    --       trashed. Just add a global which can be used in the post action.
    _G.__MUHKUH_WEBUI_TESTRESULT = fTestResult

    -- Run a post action if present.
    local strAction = tTestDescription:getPost()
    local fStatus
    fStatus, tResult = self:run_action(strAction)
    if fStatus~=true then
      local strError
      if tResult~=nil then
        strError = tostring(tResult)
      else
        strError = 'No error message.'
      end
      tLogSystem.error('Error running the global post action: %s', strError)
      -- The test failed if the post action failed.
      fTestResult = false
    end

    -- Print the result in huge letters.
    if fTestResult==true then
      tLogSystem.info('***************************************')
      tLogSystem.info('*                                     *')
      tLogSystem.info('* ######## ########  ######  ######## *')
      tLogSystem.info('*    ##    ##       ##    ##    ##    *')
      tLogSystem.info('*    ##    ##       ##          ##    *')
      tLogSystem.info('*    ##    ######    ######     ##    *')
      tLogSystem.info('*    ##    ##             ##    ##    *')
      tLogSystem.info('*    ##    ##       ##    ##    ##    *')
      tLogSystem.info('*    ##    ########  ######     ##    *')
      tLogSystem.info('*                                     *')
      tLogSystem.info('*          #######  ##    ##          *')
      tLogSystem.info('*         ##     ## ##   ##           *')
      tLogSystem.info('*         ##     ## ##  ##            *')
      tLogSystem.info('*         ##     ## #####             *')
      tLogSystem.info('*         ##     ## ##  ##            *')
      tLogSystem.info('*         ##     ## ##   ##           *')
      tLogSystem.info('*          #######  ##    ##          *')
      tLogSystem.info('*                                     *')
      tLogSystem.info('***************************************')
    else
      tLogSystem.error('*******************************************************')
      tLogSystem.error('*                                                     *')
      tLogSystem.error('*         ######## ########  ######  ########         *')
      tLogSystem.error('*            ##    ##       ##    ##    ##            *')
      tLogSystem.error('*            ##    ##       ##          ##            *')
      tLogSystem.error('*            ##    ######    ######     ##            *')
      tLogSystem.error('*            ##    ##             ##    ##            *')
      tLogSystem.error('*            ##    ##       ##    ##    ##            *')
      tLogSystem.error('*            ##    ########  ######     ##            *')
      tLogSystem.error('*                                                     *')
      tLogSystem.error('* ########    ###    #### ##       ######## ########  *')
      tLogSystem.error('* ##         ## ##    ##  ##       ##       ##     ## *')
      tLogSystem.error('* ##        ##   ##   ##  ##       ##       ##     ## *')
      tLogSystem.error('* ######   ##     ##  ##  ##       ######   ##     ## *')
      tLogSystem.error('* ##       #########  ##  ##       ##       ##     ## *')
      tLogSystem.error('* ##       ##     ##  ##  ##       ##       ##     ## *')
      tLogSystem.error('* ##       ##     ## #### ######## ######## ########  *')
      tLogSystem.error('*                                                     *')
      tLogSystem.error('*******************************************************')
    end
  end

  return fTestIsNotCanceled
end



function TestSystem:__updateTestStati(abActiveTests)
  local astrStati = {}
  local astrStatiQuoted = {}

  for _, fIsEnabled in ipairs(abActiveTests) do
    local strState = 'idle'
    if fIsEnabled==false then
      strState = 'disabled'
    end
    table.insert(astrStati, strState)
    table.insert(astrStatiQuoted, string.format('"%s"', strState))
  end

  return astrStati, astrStatiQuoted
end



function TestSystem:run()
  local pl = self.pl
  local tLogSystem = self.tLogSystem

  -- Read the test.xml file.
  local tTestDescription = self.TestDescription(tLogSystem)
  local tResult = tTestDescription:parse('tests.xml')
  if tResult~=true then
    tLogSystem.error('Failed to parse the test description.')
  else
    -- Create all system parameter.
    local atSystemParameter = {}
    local tSystemParameter = tTestDescription:getSystemParameter()
    if tSystemParameter~=nil then
      for _, tParameter in ipairs(tSystemParameter) do
        local strName = tParameter.name
        local strValue = tParameter.value
        local strOldValue = atSystemParameter[strName]
        if strOldValue==nil then
          tLogSystem.info('Setting system parameter "%s" to "%s".', strName, strValue)
        else
          tLogSystem.warning('Replacing system parameter "%s". Old value was "%s", now it is "%s".', strName, strOldValue, strValue)
        end
        atSystemParameter[strName] = strValue
      end
    end
    self.m_atSystemParameter = atSystemParameter

    local astrTestNames = tTestDescription:getTestNames()
    -- Get all test names in the style of a table.
    local astrQuotedTests = {}
    for _, strName in ipairs(astrTestNames) do
      table.insert(astrQuotedTests, string.format('"%s"', strName))
    end
    local strTestNames = table.concat(astrQuotedTests, ', ')

    -- Now set a new interaction.

    -- Read the first interaction code.
    tResult = _G.tester:setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', { ['TEST_NAMES']=strTestNames })
    if tResult==nil then
      tLogSystem.fatal('Failed to read interaction.')
    else
      local tJson = tResult
      pl.pretty.dump(tJson)
      self.m_atTestExecutionParameter = tJson
      _G.tester:clearInteraction()

      if tJson.fActivateDebugging==true then
        local strTargetIp = _G.tester:getCurrentPeerName()
        if strTargetIp=='' then
          tLogSystem.alert('Failed to get the current peer name -> unable to setup debugging.')
        else
          tLogSystem.debug('The current peer name is "%s".', strTargetIp)

          local fAgain = false
          local fOk = false
          repeat
            local tDebugResult = _G.tester:setInteractionGetJson('jsx/connect_debugger.jsx', { ['IP']=strTargetIp, ['AGAIN']=tostring(fAgain) })
            if tDebugResult==nil then
              tLogSystem.fatal('Failed to read interaction.')
              break
            else
              pl.pretty.dump(tDebugResult)
              if tDebugResult.button=='connect' then
                tLogSystem.info('Connecting to debug server on %s.', strTargetIp)
                local tInitResult = self.debug_hooks.init(strTargetIp)
                tLogSystem.info('Debug init: %s', tostring(tInitResult))
                if tInitResult==true then
                  fOk = true
                else
                  fOk = false
                  fAgain = true
                end
              elseif tDebugResult.button=='cancel' then
                fOk = true
              else
                fOk = false
              end
            end
          until fOk==true

          _G.tester:clearInteraction()
        end
      end

      -- Loop over all serials.
      -- ulSerialFirst is the first serial to test
      -- ulSerialLast is the last serial to test
      local ulSerialFirst = tonumber(tJson.serialFirst)
      local ulSerialLast = ulSerialFirst + tonumber(tJson.numberOfBoards) - 1
      tLogSystem.info('Running over the serials [%d,%d] .', ulSerialFirst, ulSerialLast)

      -- Build the initial test states.
      local astrStati, astrStatiQuoted = self:__updateTestStati(self.m_atTestExecutionParameter.activeTests)

      -- Set the serial numbers.
      self:sendSerials(ulSerialFirst, ulSerialLast)
      self:sendTestNames(tTestDescription:getTestNames())
      self:sendTestStati(astrStati)

      -- Do not show the serial selector for the first board.
      local fThisIsTheFirstBoard = true

      local ulSerialCurrent = ulSerialFirst
      repeat
        if fThisIsTheFirstBoard~=true then
          -- Reset all tests which are not deactivated to 'idle'.
          astrStati, astrStatiQuoted = self:__updateTestStati(self.m_atTestExecutionParameter.activeTests)
          self:sendTestStati(astrStati)

          -- Show the next serial to test even if it might be changed. This is a good memory hook.
          self:sendCurrentSerial(ulSerialCurrent)

          -- Read the serial selector interaction code.
          tResult = _G.tester:setInteractionGetJson('jsx/select_next_serial_and_tests.jsx', {
            ['TEST_NAMES'] = strTestNames,
            ['TEST_STATI'] = table.concat(astrStatiQuoted, ', '),
            ['SERIAL_FIRST'] = ulSerialFirst,
            ['SERIAL_CURRENT'] = ulSerialCurrent,
            ['SERIAL_LAST'] = ulSerialLast
          })
          if tResult==nil then
            tLogSystem.fatal('Failed to read interaction.')
            break
          end
          local tJson = tResult
          pl.pretty.dump(tJson)
          _G.tester:clearInteraction()
          -- Update the active boards.
          self.m_atTestExecutionParameter.activeTests = tJson.activeTests
          -- Get the next serial number to test.
          ulSerialCurrent = tonumber(tJson.serialNext)
          astrStati, astrStatiQuoted = self:__updateTestStati(self.m_atTestExecutionParameter.activeTests)
          self:sendTestStati(astrStati)
        end

        tLogSystem.info('Testing serial %d .', ulSerialCurrent)
        self.m_atSystemParameter.serial = ulSerialCurrent
        self:sendCurrentSerial(ulSerialCurrent)

        tResult = self:collect_testcases(tTestDescription, tJson.activeTests)
        if tResult==nil then
          tLogSystem.fatal('Failed to collect all test cases.')
        else
          local atModules = tResult

          tResult = self:apply_parameters(atModules, tTestDescription, ulSerialCurrent)
          if tResult==nil then
            tLogSystem.fatal('Failed to apply the parameters.')
          else
            tResult = self:check_parameters(atModules, tTestDescription)
            if tResult==nil then
              tLogSystem.fatal('Failed to check the parameters.')
            else
              tResult = self:run_tests(atModules, tTestDescription)
              if tResult~=true then
                break
              end
            end
          end
        end

        -- Show the serial selector before the next test run.
        fThisIsTheFirstBoard = false

        -- Show a finish message if this is the last board.
        if ulSerialCurrent==ulSerialLast then
          tResult = _G.tester:setInteractionGetJson('jsx/test_last_board.jsx')
          if tResult==nil then
            tLogSystem.fatal('Failed to read interaction.')
            break
          end
          local tJson = tResult
          pl.pretty.dump(tJson)
          _G.tester:clearInteraction()
          if tJson.button=='back' then
            -- The user does not want to quit.
            -- Keep the serial at the same number and go on.
          else
            -- The user agreed to quit.
            ulSerialCurrent = ulSerialCurrent + 1
          end
        else
          -- Move to the next board.
          ulSerialCurrent = ulSerialCurrent + 1
        end
      until ulSerialCurrent>ulSerialLast
    end
  end
end



function TestSystem:disconnect()
  local m_zmqSocket = self.m_zmqSocket
  if m_zmqSocket~=nil then
    if m_zmqSocket:closed()==false then
      m_zmqSocket:close()
    end
    self.m_zmqSocket = nil
  end

  local m_zmqContext = self.m_zmqContext
  if m_zmqContext~=nil then
    m_zmqContext:destroy()
    self.m_zmqContext = nil
  end
end





local usServerPort = tonumber(arg[1])
local tTestSystem = TestSystem(usServerPort)
tTestSystem:connect()
tTestSystem:createLogger()
tTestSystem:run()
tTestSystem:disconnect()
