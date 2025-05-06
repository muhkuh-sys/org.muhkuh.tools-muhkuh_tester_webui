-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_cli_init'


local class = require 'pl.class'
local TestSystem = class()

function TestSystem:_init(usServerPort)
  -- Get the LUA version number in the form major * 100 + minor .
  local strMaj, strMin = string.match(_VERSION, '^Lua (%d+)%.(%d+)$')
  if strMaj~=nil then
    self.LUA_VER_NUM = tonumber(strMaj) * 100 + tonumber(strMin)
  end

  self.date = require 'date'
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



function TestSystem.__quote_with_ticks(strInput)
  local s = string.gsub(strInput, "'", "\\'")
  s = string.gsub(s, "\n", "\\n")
  return s
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
  -- It does not use the formatter function 'fmt' (1st argument) or the date
  -- 'now' (4th argument). This is done at the server side.
  local tLogWriterFn = function(_, msg, lvl, _)
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


function TestSystem:sendTestRunStart()
  local tData = {
    attributes = self.m_atSystemParameter
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('TDS'..strJson)
end



function TestSystem:sendTestRunFinished()
  self.m_zmqSocket:send('TDF')
end



function TestSystem:sendTestStepStart(uiStepIndex, strTestCaseId, strTestCaseName)
  local tData = {
    stepIndex=uiStepIndex,
    testId=strTestCaseId,
    testName=strTestCaseName,
    attributes = self.m_atSystemParameter
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



function TestSystem:sendDisableLogging(fDisableLogging)
  local tData = {
    fDisableLogging = (fDisableLogging == true)
  }
  local strJson = self.json.encode(tData)
  self.m_zmqSocket:send('DLO'..strJson)
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
    tLogSystem.error(
      'The test description specifies %d tests, but the selection covers %d tests.',
      uiNumberOfTests,
      uiTestsFromGui
    )
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



function TestSystem:__apply_parameters(atModules, tTestDescription, _)
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
          tLogSystem.fatal(
            'The parameter "%s" does not exist in test case %d (%s).',
            strParameterName,
            uiTestIndex,
            strTestCaseName
          )
          tResult = false
          break
        -- Is the parameter an "output"?
        elseif tParameter.fIsOutput==true then
          self.tLogSystem.fatal(
            'The parameter "%s" in test case %d (%s) is an output.',
            strParameterName,
            uiTestIndex,
            strTestCaseName
          )
          tResult = false
          break
        else
          if strParameterValue~=nil then
            -- This is a direct assignment of a value.
            tParameter:set(strParameterValue)
          elseif strParameterConnection~=nil then
            -- This is a connection to another value or an output parameter.
            local strClass, strName = string.match(strParameterConnection, '^([^:]+):(.+)')
            if strClass==nil then
              tLogSystem.fatal(
                'Parameter "%s" of test %d has an invalid connection "%s".',
                strParameterName,
                uiTestIndex,
                strParameterConnection
              )
              tResult = false
              break
            else
              -- Is this a connection to a system parameter?
              if strClass=='system' then
                local tValue = self.m_atSystemParameter[strName]
                if tValue==nil then
                  tLogSystem.fatal(
                    'The connection target "%s" has an unknown name.',
                    strParameterConnection
                  )
                  tResult = false
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
                    tLogSystem.fatal(
                      'The connection "%s" uses an unknown test name: "%s".',
                      strParameterConnection,
                      strClass
                    )
                    tResult = false
                    break
                  end
                end
                if uiConnectionTargetTestCase~=nil then
                  -- Get the target module.
                  local tTargetModule = atModules[uiConnectionTargetTestCase]
                  if tTargetModule==nil then
                    tLogSystem.info(
                      'Ignoring the connection "%s" to an inactive target: "%s".',
                      strParameterConnection,
                      strClass
                    )
                  else
                    -- Get the parameter list of the target module.
                    local atTargetParameters = tTargetModule.atParameter or {}
                    -- Does the target module have a matching parameter?
                    local tTargetParameter = atTargetParameters[strName]
                    if tTargetParameter==nil then
                      tLogSystem.fatal(
                        'The connection "%s" uses a non-existing parameter at the target: "%s".',
                        strParameterConnection,
                        strName
                      )
                      tResult = false
                      break
                    else
                      self.tLogSystem.info(
                        'Connecting %02d:%s to %02d:%s .',
                        uiTestIndex,
                        strParameterName,
                        uiConnectionTargetTestCase,
                        tTargetParameter.strName
                      )
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



function TestSystem:__check_parameters(atModules, tTestDescription)
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
            fParametersOk = false
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
        local strLuaSrc, strErrorRead = pl.utils.readfile(strAction, false)
        if strLuaSrc==nil then
          strMessage = string.format('Failed to read the action file "%s": %s', strAction, strErrorRead)
        else
          -- Parse the LUA source.
          local tChunk, strErrorLoad = load(strLuaSrc, strAction)
          if tChunk==nil then
            strMessage = string.format('Failed to parse the LUA action from "%s": %s', strAction, strErrorLoad)
          else
            -- Run the LUA chunk.
            local fStatus, tResult = xpcall(
              tChunk,
              function(tErr)
                tLogSystem.debug(debug.traceback())
                return tErr
              end,
              tLogSystem
            )

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



function TestSystem:__runInSandbox(atValues, strExpression)
  local tResult
  local strMessage
  local pl = self.pl

  -- Create a sandbox with the following system functions and modules.
  local atEnv = {
    ['error']=error,
    ['ipairs']=ipairs,
    ['next']=next,
    ['pairs']=pairs,
    ['print']=print,
    ['select']=select,
    ['tonumber']=tonumber,
    ['tostring']=tostring,
    ['type']=type,
    ['math']=math,
    ['string']=string,
    ['table']=table
  }
  -- Add the user values.
  pl.tablex.update(atEnv, atValues)

  local strCode = string.format('return %s', strExpression)
  local tFn, strError = pl.compat.load(strCode, 'condition code', 't', atEnv)
  if tFn==nil then
    strMessage = string.format('Invalid expression "%s": %s', strExpression, tostring(strError))
  else
    local fRun, tFnResult = pcall(tFn)
    if fRun==false then
      strMessage = string.format('Failed to run the expression "%s": %s', strExpression, tostring(tFnResult))
    else
      local strType = type(tFnResult)
      if strType=='boolean' then
        tResult = tFnResult
      else
        strMessage = string.format('Invalid condition return type for expression "%s": %s', strExpression, strType)
      end
    end
  end

  return tResult, strMessage
end



function TestSystem:__checkConditions(atConditions, atConditionAttributes)
  local fCondition = false
  local astrMessages = {}
  local tLogSystem = self.tLogSystem

  -- Loop over all conditions.
  for _, tCondition in ipairs(atConditions) do
    local strCondition = tCondition.condition
    local tResult, strMessage = self:__runInSandbox(atConditionAttributes, strCondition)
    tLogSystem.debug('Condition "%s": %s', strCondition, tostring(tResult))
    -- Stop immediately if a condition could not be evaluated.
    if tResult==nil then
      fCondition = nil
      astrMessages = { strMessage }
      break
    elseif tResult==true then
      fCondition = true
      -- Does the condition have a message?
      strMessage = tCondition.message
      if strMessage==nil or strMessage=='' then
        -- No message -> create a generic message from the condition.
        strMessage = string.format('The condition is true: %s', strCondition)
      end
      table.insert(astrMessages, strMessage)
    end
  end

  return fCondition, astrMessages
end



function TestSystem:run_tests(atModules, tTestDescription)
  local date = self.date
  local pl = self.pl
  local tLogSystem = self.tLogSystem
  -- Run all enabled modules with their parameter.
  local fTestIsNotCanceled = true

  local astrTestNames = tTestDescription:getTestNames()
  local uiNumberOfTests = tTestDescription:getNumberOfTests()

  -- Create an array with all attributes for the condition checks.
  local atTestSteps = {}
  for uiTestIndex = 1, uiNumberOfTests do
    local strTestCaseName = astrTestNames[uiTestIndex]
    local strState = 'pending'
    local tModule = atModules[uiTestIndex]
    if tModule==nil then
      strState = 'inactive'
    end
    local strTestCaseId = tTestDescription:getTestCaseId(uiTestIndex)
    -- Create a new table for each test case.
    local atAttr = {
      name = strTestCaseName,
      id = strTestCaseId,
      parameter = {},
      state = strState,
      message = ''
    }
    -- Register it under the test index and the test name.
    atTestSteps[uiTestIndex] = atAttr
    atTestSteps[strTestCaseName] = atAttr
  end
  local atConditionAttributes = {
    start = date(false):fmt('%Y-%m-%d %H:%M:%S'),
    status_total = true,
    steps = atTestSteps,
    system_parameter = self.m_atSystemParameter
  }

  -- Run a pre action if present.
  local strAction = tTestDescription:getPre()
  local fTestResult, tResult = self:run_action(strAction)
  atConditionAttributes.pre_result = fTestResult
  atConditionAttributes.status_total = fTestResult
  if fTestResult~=true then
    local strError
    if tResult~=nil then
      strError = tostring(tResult)
    else
      strError = 'No error message.'
    end
    atConditionAttributes.pre_message = strError
    tLogSystem.error('Error running the global pre action: %s', strError)

  else
    for uiTestIndex = 1, uiNumberOfTests do
      -- Get a shortcut to the attributes of the current test step.
      local atTestStep = atConditionAttributes.steps[uiTestIndex]

      local fContinueWithNextTestCase = true
      repeat
        local fExitTestCase = true

        -- Get the module for the test index.
        local tModule = atModules[uiTestIndex]
        local strTestCaseName = astrTestNames[uiTestIndex]
        if tModule==nil then
          tLogSystem.info('Not running deactivated test case %02d (%s).', uiTestIndex, strTestCaseName)
        else
          local strTestCaseId = tTestDescription:getTestCaseId(uiTestIndex)
          self:sendTestStepStart(uiTestIndex, strTestCaseId, strTestCaseName)

          local fStatus = true
          local strTestState
          local strTestMessage = ''

          -- Get the list of exclude conditions.
          local fCondition, astrMessages
          local atConditions = tTestDescription:getTestCaseExcludeIf(uiTestIndex)
          if atConditions==nil then
            -- Failed to get the conditions. Complain but run the test case.
            tLogSystem.warning(
              'Failed to get the exclude conditions for test case %d (%s). Assuming it is not excluded.',
              uiTestIndex,
              strTestCaseName
            )
            fCondition = false
          else
            -- Check if at least one condition is true.
            fCondition, astrMessages = self:__checkConditions(atConditions, atConditionAttributes)
          end
          if fCondition==nil then
            tLogSystem.error(
              'Failed to evaluate the ExcludeIf conditions for test case %d (%s): %s',
              uiTestIndex,
              strTestCaseName,
              table.concat(astrMessages, ', ')
            )
            fContinueWithNextTestCase = false
            break

          elseif fCondition==true then
            tLogSystem.info(
              'Execution of the test case %d (%s) was prevented by the following ExcludeIf conditions:',
              uiTestIndex,
              strTestCaseName
            )
            for _, strMessage in ipairs(astrMessages) do
              tLogSystem.info('  * %s', strMessage)
            end

            strTestState = 'excluded'
            fStatus = nil
            strTestMessage = table.concat(astrMessages, ', ')
          else
            atConditions = tTestDescription:getTestCaseErrorIf(uiTestIndex)
            if atConditions==nil then
              -- Failed to get the conditions. Complain but run the test case.
              tLogSystem.warning(
                'Failed to get the error conditions for test case %d (%s). Assuming it is not in error state.',
                uiTestIndex,
                strTestCaseName
              )
              fCondition = false
            else
              -- Check if at least one condition is true.
              fCondition, astrMessages = self:__checkConditions(atConditions, atConditionAttributes)
            end
            if fCondition==nil then
              tLogSystem.error(
                'Failed to evaluate the ErrorIf conditions for test case %d (%s): %s',
                uiTestIndex,
                strTestCaseName,
                table.concat(astrMessages, ', ')
              )
              fContinueWithNextTestCase = false
              break

            elseif fCondition==true then
              tLogSystem.error(
                'Execution of the test case %d (%s) was prevented by the following ErrorIf conditions:',
                uiTestIndex,
                strTestCaseName
              )
              for _, strMessage in ipairs(astrMessages) do
                tLogSystem.error('  * %s', strMessage)
              end

              strTestState = 'error'
              fStatus = false
              strTestMessage = table.concat(astrMessages, ', ')
            else
              tLogSystem.info('Running testcase %d (%s).', uiTestIndex, strTestCaseName)

              -- Set the start time of the test step.
              atTestStep['start'] = date(false):fmt('%Y-%m-%d %H:%M:%S')

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
                    tLogSystem.fatal(
                      'Failed to validate the parameter %02d:%s : %s',
                      uiTestIndex,
                      strParameterName,
                      strError
                    )
                    fStatus = false
                    fTestResult = false
                    atConditionAttributes.status_total = false
                    fContinueWithNextTestCase = false
                    break
                  end
                end
              end
              if fStatus~=true then
                break
              end

              -- Clear any old parameters.
              atTestStep.parameter = {}

              -- Show all parameters for the test case.
              tLogSystem.info("__/Parameters/________________________________________________________________")
              if pl.tablex.size(atParameters)==0 then
                tLogSystem.info('Testcase %d (%s) has no parameter.', uiTestIndex, strTestCaseName)
              else
                tLogSystem.info('Parameters for testcase %d (%s):', uiTestIndex, strTestCaseName)
                for _, tParameter in pairs(atParameters) do
                  -- Do not dump output parameter. They have no value yet.
                  if tParameter.fIsOutput~=true then
                    local strValue = tParameter:get_pretty()
                    atTestStep.parameter[tParameter.strName] = strValue
                    tLogSystem.info('  %02d:%s = %s', uiTestIndex, tParameter.strName, strValue)
                  end
                end
              end
              tLogSystem.info("______________________________________________________________________________")

              -- Run a pre action if present.
              strAction = tTestDescription:getTestCaseActionPre(uiTestIndex)
              fStatus, tResult = self:run_action(strAction)
              atTestStep.pre_result = fStatus
              if fStatus==true then
                -- Execute the test code. Write a stack trace to the debug logger if the test case crashes.
                fStatus, tResult = xpcall(
                  self.debug_hooks.run_teststep,
                  function(tErr)
                    tLogSystem.debug(debug.traceback())
                    return tErr
                  end,
                  tModule,
                  uiTestIndex
                )
                tLogSystem.info('Testcase %d (%s) finished.', uiTestIndex, strTestCaseName)
                if fStatus==true then
                  -- Run a post action if present.
                  strAction = tTestDescription:getTestCaseActionPost(uiTestIndex)
                  fStatus, tResult = self:run_action(strAction)
                  atTestStep.post_result = fStatus
                  if fStatus~=true then
                    local strError
                    if tResult~=nil then
                      strError = tostring(tResult)
                    else
                      strError = 'No error message.'
                    end
                    atTestStep.post_message = strError
                  end
                end
              else
                local strError
                if tResult~=nil then
                  strError = tostring(tResult)
                else
                  strError = 'No error message.'
                end
                atTestStep.pre_message = strError
              end
              -- Run a complete garbare collection after the test case.
              collectgarbage()

              -- Validate all output parameters.
              for strParameterName, tParameter in pairs(atParameters) do
                if tParameter.fIsOutput==true then
                  local fValid, strError = tParameter:validate()
                  if fValid==false then
                    tLogSystem.warning(
                      'Failed to validate the output parameter %02d:%s : %s',
                      uiTestIndex,
                      strParameterName,
                      strError
                    )
                  end
                end
              end

              -- Get the test message.
              if fStatus~=true then
                local strError
                if tResult~=nil then
                  strError = tostring(tResult)
                else
                  strError = 'No error message.'
                end
                strTestMessage = strError
                tLogSystem.error('Error running the test: %s', strError)
              end

              -- Get the test state.
              strTestState = 'error'
              if fStatus==true then
                strTestState = 'ok'
              end

              -- Set the end time of the test step.
              atTestStep['end'] = date(false):fmt('%Y-%m-%d %H:%M:%S')
            end
          end

          -- Update the condition attributes to the test result.
          atTestStep.state = strTestState
          atTestStep.result = fStatus
          atTestStep.message = strTestMessage

          -- Send the result to the GUI.
          local tEventTestRun = {
            start = atTestStep.start,
            ['end'] = atTestStep['end'],
            parameter= atTestStep.parameter,
            state = atTestStep.state,
            result = atTestStep.result,
            message = atTestStep.message
          }
          _G.tester:sendLogEvent('muhkuh.test.run', tEventTestRun)
          self:sendTestStepFinished(strTestState)

          if fStatus==false then
            tResult = _G.tester:setInteractionGetJson('jsx/test_failed.jsx', {
              ['FAILED_TEST_IDX']=uiTestIndex,
              ['FAILED_TEST_NAME']=self.__quote_with_ticks(strTestCaseName),
              ['FAILED_TEST_MESSAGE']=self.__quote_with_ticks(atTestStep.message)
            })
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
                atConditionAttributes.status_total = false
                fContinueWithNextTestCase = false
              elseif tJson.button=='ignore' then
                fTestResult = false
                atConditionAttributes.status_total = false
              else
                fTestResult = false
                atConditionAttributes.status_total = false
                fTestIsNotCanceled = false
              end
            end
          end
        end
      until fExitTestCase==true

      if fContinueWithNextTestCase~=true then
        break
      end
    end

    atConditionAttributes['end'] = date(false):fmt('%Y-%m-%d %H:%M:%S')

    -- Collect all results in the "test result" event.
    local atTestStepsI = {}
    for uiIdx, tStep in ipairs(atConditionAttributes.steps) do
      atTestStepsI[uiIdx] = tStep
    end
    local tEventTestResult = {
      start = atConditionAttributes.start,
      ['end'] = atConditionAttributes['end'],
      steps = atTestStepsI,
      result = tostring(fTestResult)
    }
    _G.tester:sendLogEvent('muhkuh.test.result', tEventTestResult)

    -- Close all connections to the netX.
    if _G.tester.closeAllCommonPlugins~=nil then
      _G.tester:closeAllCommonPlugins()
    else
      _G.tester:closeCommonPlugin()
    end

    -- HACK: the post action needs to know if the board should be finalized or
    --       trashed. Just add a global which can be used in the post action.
    _G.__MUHKUH_WEBUI_TESTRESULT = fTestResult

    -- Run a post action if present.
    strAction = tTestDescription:getPost()
    local fStatus
    fStatus, tResult = self:run_action(strAction)
    atConditionAttributes.post_result = fStatus
    if fStatus~=true then
      local strError
      if tResult~=nil then
        strError = tostring(tResult)
      else
        strError = 'No error message.'
      end
      atConditionAttributes.post_message = strError
      tLogSystem.error('Error running the global post action: %s', strError)
      -- The test failed if the post action failed.
      fTestResult = false
      atConditionAttributes.status_total = false
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



function TestSystem.__updateTestStati(abActiveTests)
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



function TestSystem.__addLevel(atLevelLookup, uiLevel, tPluginInstance)
  local atLevel = atLevelLookup[uiLevel]
  if atLevel==nil then
    atLevel = {}
    atLevelLookup[uiLevel] = atLevel
  end
  table.insert(atLevel, tPluginInstance)
end



function TestSystem.__sortLevelTable(atLevelLookup)
  -- Get a sorted list of all levels in the lookup table.
  local atSortedLevels = {}
  for uiLevel in pairs(atLevelLookup) do
    table.insert(atSortedLevels, uiLevel)
  end
  table.sort(atSortedLevels)

  -- Loop over the sorted levels.
  local atSortedPluginInstances = {}
  for _, uiLevel in ipairs(atSortedLevels) do
    local atLevel = atLevelLookup[uiLevel]
    for _, tPluginInstance in ipairs(atLevel) do
      table.insert(atSortedPluginInstances, tPluginInstance)
    end
  end

  return atSortedPluginInstances
end



function TestSystem:__setInputPluginsConfiguration(tInputPluginsConfiguration)
  local tLogSystem = self.tLogSystem

  -- Get all input plugins as a lookup table.
  -- Create also lists for the functions "get_jsx" and "get_data" sorted by the levels.
  local atInputPlugins = {}
  local atGetJsxCfg = {}
  local atGetDataCfg = {}
  local fPluginsOk = true
  for uiPluginIdx, tPluginCfg in ipairs(tInputPluginsConfiguration) do
    local strPluginCfgId = tPluginCfg.id
    local strPluginCfgPlugin = tPluginCfg.plugin
    local tPluginParameter = tPluginCfg.parameter
    if strPluginCfgId==nil then
      tLogSystem.error('Error in definition of input plugin #%d: missing mandatory attribute "id".', uiPluginIdx)
      fPluginsOk = false
    elseif strPluginCfgPlugin==nil then
      tLogSystem.error('Error in definition of input plugin #%d: missing mandatory attribute "plugin".', uiPluginIdx)
      fPluginsOk = false
    else
      if atInputPlugins[strPluginCfgId]~=nil then
        tLogSystem.error(
          'Error in definition of input plugin #%d: the value "%s" of attribute "id" is not unique.',
          uiPluginIdx,
          strPluginCfgId
        )
        fPluginsOk = false
      else
        local strPluginLuaId = 'webui.input.' .. strPluginCfgPlugin
        local fPcallReqRes, tInputPlugin = pcall(require, strPluginLuaId)
        if fPcallReqRes~=true then
          tLogSystem.error(
            'Failed to load input plugin #%d ("%s"): %s',
            uiPluginIdx,
            strPluginLuaId,
            tostring(tInputPlugin)
          )
          fPluginsOk = false
        else
          -- Try to create an instance of the plugin.
          local tPluginInstance = tInputPlugin(tLogSystem, tPluginParameter)
          if tPluginInstance==nil then
            tLogSystem.error(
              'Failed to instanciate input plugin #%d ("%s").',
              uiPluginIdx,
              strPluginLuaId
            )
            fPluginsOk = false

          elseif type(tPluginInstance.get_jsx)~='function' then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): missing "get_jsx" method.',
              uiPluginIdx,
              strPluginLuaId
            )
            fPluginsOk = false

          elseif type(tPluginInstance.get_data)~='function' then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): missing "get_data" method.',
              uiPluginIdx,
              strPluginLuaId
            )
            fPluginsOk = false

          elseif type(tPluginInstance.get_jsx_level)~='number' then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): missing "get_jsx_level" attribute.',
              uiPluginIdx,
              strPluginLuaId
            )
            fPluginsOk = false

          elseif type(tPluginInstance.get_data_level)~='number' then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): missing "get_data_level" attribute.',
              uiPluginIdx,
              strPluginLuaId
            )
            fPluginsOk = false

          elseif tPluginInstance.get_jsx_level<0 or tPluginInstance.get_jsx_level>99 then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): attribute "get_jsx_level" exceeds the valid range of [0;99]: %d',
              uiPluginIdx,
              strPluginLuaId,
              tPluginInstance.get_jsx_level
            )
            fPluginsOk = false

          elseif tPluginInstance.get_data_level<0 or tPluginInstance.get_data_level>99 then
            tLogSystem.error(
              'Invalid input plugin #%d ("%s"): attribute "get_data_level" exceeds the valid range of [0;99]: %d',
              uiPluginIdx,
              strPluginLuaId,
              tPluginInstance.get_data_level
            )
            fPluginsOk = false

          else
            tPluginInstance.m_strPluginCfgId = strPluginCfgId
            self.__addLevel(atGetJsxCfg, tPluginInstance.get_jsx_level, tPluginInstance)
            self.__addLevel(atGetDataCfg, tPluginInstance.get_data_level, tPluginInstance)

            atInputPlugins[strPluginCfgId] = tPluginInstance
          end
        end
      end
    end
  end

  if fPluginsOk then
    self.m_atInputPlugins = atInputPlugins
    self.m_atInputPluginsGetJsx = self.__sortLevelTable(atGetJsxCfg)
    self.m_atInputPluginsGetData = self.__sortLevelTable(atGetDataCfg)
  end

  return fPluginsOk
end



function TestSystem:run()
  local pl = self.pl
  local tLogSystem = self.tLogSystem

  -- Read the package file.
  local tPackageInfo
  local strPackageInfoFile = pl.path.join('.jonchki', 'package.txt')
  if pl.path.isfile(strPackageInfoFile)~=true then
    tLogSystem.debug('The package file "%s" does not exist.', strPackageInfoFile)
  else
    tLogSystem.debug('Reading the package file "%s".', strPackageInfoFile)
    local strError
    tPackageInfo, strError = pl.config.read(strPackageInfoFile)
    if tPackageInfo==nil then
      tLogSystem.debug('Failed to read the package file "%s": %s', strPackageInfoFile, tostring(strError))
    end
  end

  -- Read the test.xml file.
  local tTestDescription = self.TestDescription(tLogSystem)
  local tResult = tTestDescription:parse('tests.xml')
  if tResult~=true then
    tLogSystem.error('Failed to parse the test description.')
  else
    local astrTestNames = tTestDescription:getTestNames()
    -- Get all test names in the style of a table.
    local astrQuotedTests = {}
    local abInitialStates = {}
    for _, strName in ipairs(astrTestNames) do
      table.insert(astrQuotedTests, string.format('"%s"', strName))
      table.insert(abInitialStates, true)
    end
    local strTestNames = table.concat(astrQuotedTests, ', ')

    self:sendTestNames(astrTestNames)
    local astrStati = self.__updateTestStati(abInitialStates)
    self:sendTestStati(astrStati)

    -- Get the configuration as a lookup table.
    local atConfigurationParameter = tTestDescription:getConfigurationParameter()
    local atConfigurationLookup = {}
    for _, tParameter in ipairs(atConfigurationParameter) do
      local strName = tParameter.name
      local strValue = tParameter.value
      local strOldValue = atConfigurationLookup[strName]
      if strOldValue==nil then
        tLogSystem.info('Setting configuration parameter "%s" to "%s".', strName, strValue)
      else
        tLogSystem.warning(
          'Replacing configuration parameter "%s". Old value was "%s", now it is "%s".',
          strName,
          strOldValue,
          strValue
        )
      end
      atConfigurationLookup[strName] = strValue
    end
    -- Apply some defaults.
    local atConfigurationDefaults = {
      ['Inputs'] = '[' ..
                     '{"id": "fertigungsauftrag", "plugin": "fertigungsauftrag_input"},' ..
                     '{"id": "matrixlabel", "plugin": "matrixlabel_input"}' ..
                   ']',
      ['DataProvider'] = '[]'
    }
    for strName, strValue in pairs(atConfigurationDefaults) do
      if atConfigurationLookup[strName]==nil then
        atConfigurationLookup[strName] = strValue
        tLogSystem.info('Setting default value for configuration parameter "%s" to "%s".', strName, strValue)
      end
    end

    -- Parse the configuration and assign it to the tester.
    local tDataProviderConfiguration, strDataProviderError = self.json.decode(atConfigurationLookup.DataProvider)
    local tInputPluginsConfiguration, strInputPluginsError = self.json.decode(atConfigurationLookup.Inputs)
    if tDataProviderConfiguration==nil then
      tLogSystem.fatal('Failed to parse the data provider configuration: ' .. tostring(strDataProviderError))
    elseif tInputPluginsConfiguration==nil then
      tLogSystem.fatal('Failed to parse the input plugins configuration: ' .. tostring(strInputPluginsError))
    elseif self:__setInputPluginsConfiguration(tInputPluginsConfiguration)~=true then
      tLogSystem.fatal('Failed to set the input plugins configuration.')
    else
      _G.tester:setDataProviderConfiguration(tDataProviderConfiguration, self.tLogWriterFn, self.strLogLevel)

      -- Run the test until a fatal error occured.
      local fTestSystemOk = true
      local strCurrentProductionNumber = ''
      local strSystemErrorMessage
      repeat
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
              tLogSystem.warning(
                'Replacing system parameter "%s". Old value was "%s", now it is "%s".',
                strName,
                strOldValue,
                strValue
              )
            end
            atSystemParameter[strName] = strValue
          end
        end
        self.m_atSystemParameter = atSystemParameter
        _G.tester:setSystemParameter(atSystemParameter)

        -- Collect the JSX code for all input elements.
        local astrInputObjects = {}
        for _, tPluginInstance in ipairs(self.m_atInputPluginsGetJsx) do
          local strJsx = tPluginInstance:get_jsx()
          if type(strJsx)=='string' then
            table.insert(astrInputObjects, strJsx)
          end
        end
        local strInputObjects = table.concat(astrInputObjects, ',\n')

        -- Read the first interaction code.
        tResult = _G.tester:setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', {
          ['TEST_NAMES'] = strTestNames,
          ['LAST_PRODUCTION_NUMBER'] = strCurrentProductionNumber,
          ['INPUT_ELEMENTS'] = strInputObjects
        })
        if tResult==nil then
          strSystemErrorMessage = 'Failed to set the interaction to select the serial range and tests.'
          fTestSystemOk = false
        else
          local tJson = tResult

          _G.tester:clearInteraction()

          -- Add all system parameters from the LUA side.
          local tAdditionalSystemParameter = tJson.systemParameter or {}
          local astrPluginErrors = {}
          for _, tInputPluginInstance in ipairs(self.m_atInputPluginsGetData) do
            local fPcallRes, fPluginRes, strPluginError = pcall(
              tInputPluginInstance.get_data,
              tInputPluginInstance,
              tAdditionalSystemParameter
            )
            if fPcallRes~=true then
              if strPluginError==nil then
                strPluginError = 'No error message'
              end
              table.insert(
                astrPluginErrors,
                string.format(
                  'The "get_data" method of plugin "%s" crashed: %s',
                  tInputPluginInstance.m_strPluginCfgId,
                  tostring(fPluginRes)
                )
              )

            elseif fPluginRes~=true then
              if strPluginError==nil then
                strPluginError = 'No error message'
              end
              table.insert(
                astrPluginErrors,
                string.format(
                  'Failed to get input values from plugin "%s": %s',
                  tInputPluginInstance.m_strPluginCfgId,
                  tostring(strPluginError)
                )
              )

            end
          end
          if #astrPluginErrors>0 then
            strSystemErrorMessage = table.concat(astrPluginErrors, '\n');
            fTestSystemOk = false
          else
            -- Add the system parameter from the dialog.
            pl.tablex.update(self.m_atSystemParameter, tAdditionalSystemParameter)

            self:sendTestRunStart()

            pl.pretty.dump(tJson)
            _G.tester:sendLogEvent('muhkuh.test.start', {
              package = tPackageInfo,
              selection = tJson.activeTests
            })

            self.m_atTestExecutionParameter = tJson
            _G.tester:clearInteraction()

            -- Remember the production number for the next run.
            strCurrentProductionNumber = self.m_atSystemParameter.production_number

            self:sendDisableLogging(tJson.fDisableLogging)

            if tJson.fActivateDebugging==true then
              local strTargetIp = _G.tester:getCurrentPeerName()
              if strTargetIp=='' then
                tLogSystem.alert('Failed to get the current peer name -> unable to setup debugging.')
              else
                tLogSystem.debug('The current peer name is "%s".', strTargetIp)

                local fAgain = false
                local fOk
                repeat
                  local tDebugResult = _G.tester:setInteractionGetJson(
                    'jsx/connect_debugger.jsx',
                    {
                      ['IP']=strTargetIp,
                      ['AGAIN']=tostring(fAgain)
                    }
                  )
                  if tDebugResult==nil then
                    tLogSystem.fatal('Failed to read interaction.')
                    break
                  else
                    pl.pretty.dump(tDebugResult)
                    if tDebugResult.button=='connect' then
                      tLogSystem.info('Connecting to debug server.')
                      local tInitResult = self.debug_hooks.init(tDebugResult.IP,tDebugResult.Port)
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

            -- Update the test stati.
            astrStati = self.__updateTestStati(self.m_atTestExecutionParameter.activeTests)
            self:sendTestStati(astrStati)

            -- Get the current serial number.
            local ulSerialCurrent = tonumber(self.m_atSystemParameter.serial)
            self:sendCurrentSerial(ulSerialCurrent)

            tLogSystem.info('Testing serial %d .', ulSerialCurrent)

            tResult = self:collect_testcases(tTestDescription, tJson.activeTests)
            if tResult==nil then
              strSystemErrorMessage = 'Failed to collect all test cases.'
              fTestSystemOk = false
            else
              local atModules = tResult

              tResult = self:__apply_parameters(atModules, tTestDescription, ulSerialCurrent)
              if tResult~=true then
                strSystemErrorMessage = 'Failed to apply the parameters.'
                fTestSystemOk = false
              else
                tResult = self:__check_parameters(atModules, tTestDescription)
                if tResult~=true then
                  strSystemErrorMessage = 'Failed to check the parameters.'
                  fTestSystemOk = false
                else
                  tResult = self:run_tests(atModules, tTestDescription)
                  if tResult~=true then
                    break
                  end
                end
              end
            end

            self:sendTestRunFinished()

            -- Reset all test stati to idle or disabled.
            astrStati = self.__updateTestStati(self.m_atTestExecutionParameter.activeTests)
            self:sendTestStati(astrStati)
          end
        end
      until fTestSystemOk~=true

      -- Show an error message.
      if strSystemErrorMessage==nil then
        strSystemErrorMessage = 'No message.'
      end
      tLogSystem.fatal(strSystemErrorMessage)
      _G.tester:setInteractionGetJson('jsx/fatal_system_error.jsx', {
        ['ERROR_MESSAGE'] = strSystemErrorMessage
      })
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
