-- Do not buffer stdout and stderr.
io.stdout:setvbuf('no')
io.stderr:setvbuf('no')

require 'muhkuh_cli_init'

local pl = require'pl.import_into'()
local json = require 'dkjson'
local zmq = require 'lzmq'
local TestDescription = require 'test_description'

-- Register the tester as a global module.
local cTester = require 'tester_webgui'
_G.tester = cTester()

local usServerPort = tonumber(arg[1])

local m_zmqPort = usServerPort
strAddress = string.format('tcp://127.0.0.1:%d', usServerPort)
print(string.format("Connecting to %s", strAddress))

-- Create the 0MQ context.
local zmq = require 'lzmq'
local tZContext, strError = zmq.context()
if tZContext==nil then
  error('Failed to create ZMQ context: ' .. tostring(strError))
end
local m_zmqContext = tZContext

-- Create the socket.
local tZSocket, strError = tZContext:socket(zmq.PAIR)
if tZSocket==nil then
  error('Failed to create ZMQ socket: ' .. tostring(strError))
end

-- Connect the socket to the server.
local tResult, strError = tZSocket:connect(strAddress)
if tResult==nil then
  error('Failed to connect the socket: ' .. tostring(strError))
end
local m_zmqSocket = tZSocket
tester:setSocket(m_zmqSocket)

print(string.format('0MQ socket connected to tcp://127.0.0.1:%d', usServerPort))

local m_atSystemParameter = nil


------------------------------------------------------------------------------
-- Now create the logger. It sends the data to the ZMQ socket.
-- It does not use the formatter function 'fmt' or the date 'now'. This is
-- done at the server side.
local tLogWriterFn = function(fmt, msg, lvl, now)
  m_zmqSocket:send(string.format('LOG%d,%s', lvl, msg))
end

-- This is the default log level. Note that the filtering should happen in
-- the GUI and all messages which are already filtered with this level here
-- will never be available in the GUI.
local strLogLevel = 'debug'

-- Create a new log target with "SYSTEM" prefix.
local tLogWriterSystem = require 'log.writer.prefix'.new('[System] ', tLogWriterFn)
local tLogSystem = require "log".new(
  strLogLevel,
  tLogWriterSystem,
  require "log.formatter.format".new()
)
tester:setLog(tLogSystem)

------------------------------------------------------------------------------

local function sendTitles(strTitle, strSubtitle)
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
  local strJson = json.encode(tData)
  m_zmqSocket:send('TTL'..strJson)
end



local function sendSerials(ulSerialFirst, ulSerialLast)
  local tData = {
    hasSerial=true,
    firstSerial=ulSerialFirst,
    lastSerial=ulSerialLast
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('SER'..strJson)
end



local function sendTestNames(astrTestNames)
  local strJson = json.encode(astrTestNames)
  m_zmqSocket:send('NAM'..strJson)
end



local function sendTestStati(astrTestStati)
  local strJson = json.encode(astrTestStati)
  m_zmqSocket:send('STA'..strJson)
end



local function sendCurrentSerial(uiCurrentSerial)
  local tData = {
    currentSerial=uiCurrentSerial
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('CUR'..strJson)
end



local function sendRunningTest(uiRunningTest)
  local tData = {
    runningTest=uiRunningTest
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('RUN'..strJson)
end



local function sendTestState(strTestState)
  local tData = {
    testState=strTestState
  }
  local strJson = json.encode(tData)
  m_zmqSocket:send('RES'..strJson)
end



local function load_test_module(uiTestIndex)
  local strModuleName = string.format("test%02d", uiTestIndex)
  tLogSystem.debug('Reading module for test %d from %s .', uiTestIndex, strModuleName)

  local tClass = require(strModuleName)
  local tModule = tClass(uiTestIndex, tLogWriterFn, strLogLevel)
  return tModule
end



local function collect_testcases(tTestDescription, aActiveTests)
  local tResult

  -- Get the number of tests from the test description.
  local uiNumberOfTests = tTestDescription:getNumberOfTests()
  -- Get the number of tests specified in the GUI response.
  local uiTestsFromGui = table.maxn(aActiveTests)
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
        local fOk, tValue = pcall(load_test_module, uiTestIndex)
        if fOk~=true then
          tLogSystem.error('Failed to load the module for test case %d: %s', uiTestIndex, tostring(tValue))
          fAllModulesOk = false
        else
          aModules[uiTestIndex] = tValue
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



local function apply_parameters(atModules, tTestDescription, ulSerial)
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
        else
          if strParameterValue~=nil then
            -- This is a direct assignment of a value.
            tParameter:set(strParameterValue)
          elseif strParameterConnection~=nil then
            -- This is a connection to another value.
            local strClass, strName = string.match(strParameterConnection, '^([^:]+):(.+)')
            if strClass==nil then
              tLogSystem.fatal('Parameter "%s" of test %d has an invalid connection "%s".', strParameterName, uiTestIndex, strParameterConnection)
              tResult = nil
              break
            else
              -- For now accept only system values.
              if strClass~='system' then
                tLogSystem.fatal('The connection target "%s" has an unknown class.', strParameterConnection)
                tResult = nil
                break
              else
                tValue = m_atSystemParameter[strName]
                if tValue==nil then
                  tLogSystem.fatal('The connection target "%s" has an unknown name.', strParameterConnection)
                  tResult = nil
                  break
                else
                  tParameter:set(tostring(tValue))
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



local function check_parameters(atModules, tTestDescription)
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
        -- Validate the parameter.
        local fValid, strError = tParameter:validate()
        if fValid==false then
          tLogSystem.fatal('The parameter %02d:%s is invalid: %s', uiTestIndex, tParameter.strName, strError)
          fParametersOk = nil
        end
      end
    end
  end

  if fParametersOk~=true then
    tLogSystem.fatal('One or more parameters were invalid. Not running the tests!')
  end

  return fParametersOk
end



local function run_action(strAction)
  local tActionResult = nil
  local strMessage = nil

  if strAction==nil then
    tActionResult = true

  else
    local strExt = string.sub(strAction, -4)

    -- If the action is a JSX file, this is a static GUI element.
    if strExt=='.jsx' then
      tResult = tester:setInteraction(strAction)
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
          local tChunk, strMsg = loadstring(strLuaSrc, strAction)
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



local function run_tests(atModules, tTestDescription)
  -- Run all enabled modules with their parameter.
  local fTestIsNotCanceled = true

  -- Run a pre action if present.
  local strAction = tTestDescription:getPre()
  local fTestResult, tResult = run_action(strAction)
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

          -- Show all parameters for the test case.
          tLogSystem.info("__/Parameters/________________________________________________________________")
          if pl.tablex.size(atParameters)==0 then
            tLogSystem.info('Testcase %d (%s) has no parameter.', uiTestIndex, strTestCaseName)
          else
            tLogSystem.info('Parameters for testcase %d (%s):', uiTestIndex, strTestCaseName)
            for _, tParameter in pairs(atParameters) do
              tLogSystem.info('  %02d:%s = %s', uiTestIndex, tParameter.strName, tParameter:get_pretty())
            end
          end
          tLogSystem.info("______________________________________________________________________________")

          sendRunningTest(uiTestIndex)
          sendTestState('idle')

          -- Run a pre action if present.
          local strAction = tTestDescription:getTestCaseActionPre(uiTestIndex)
          fStatus, tResult = run_action(strAction)
          if fStatus==true then
            -- Execute the test code. Write a stack trace to the debug logger if the test case crashes.
            fStatus, tResult = xpcall(function() tModule:run() end, function(tErr) tLogSystem.debug(debug.traceback()) return tErr end)
            tLogSystem.info('Testcase %d (%s) finished.', uiTestIndex, strTestCaseName)
            if fStatus==true then
              -- Run a post action if present.
              local strAction = tTestDescription:getTestCaseActionPost(uiTestIndex)
              fStatus, tResult = run_action(strAction)
            end
          end
          -- Run a complete garbare collection after the test case.
          collectgarbage()

          -- Send the result to the GUI.
          local strTestState = 'error'
          if fStatus==true then
            strTestState = 'ok'
          end
          sendTestState(strTestState)
          sendRunningTest(nil)

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
              tester:clearInteraction()

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
    tester:closeCommonPlugin()

    -- Run a post action if present.
    local strAction = tTestDescription:getPost()
    fStatus, tResult = run_action(strAction)
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



local function __updateTestStati(abActiveTests)
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



-- Read the test.xml file.
local tTestDescription = TestDescription(tLogSystem)
local tResult = tTestDescription:parse('tests.xml')
if tResult~=true then
  tLogSystem.error('Failed to parse the test description.')
else
  local astrTestNames = tTestDescription:getTestNames()
  -- Get all test names in the style of a table.
  local astrQuotedTests = {}
  for _, strName in ipairs(astrTestNames) do
    table.insert(astrQuotedTests, string.format('"%s"', strName))
  end
  local strTestNames = table.concat(astrQuotedTests, ', ')

  -- Now set a new interaction.

  -- Read the first interaction code.
  tResult = tester:setInteractionGetJson('jsx/select_serial_range_and_tests.jsx', { ['TEST_NAMES']=strTestNames })
  if tResult==nil then
    tLogSystem.fatal('Failed to read interaction.')
  else
    local tJson = tResult
    pl.pretty.dump(tJson)
    m_atSystemParameter = tJson
    tester:clearInteraction()

    -- Loop over all serials.
    -- ulSerialFirst is the first serial to test
    -- ulSerialLast is the last serial to test
    local ulSerialFirst = tonumber(tJson.serialFirst)
    local ulSerialLast = ulSerialFirst + tonumber(tJson.numberOfBoards) - 1
    tLogSystem.info('Running over the serials [%d,%d] .', ulSerialFirst, ulSerialLast)

    -- Build the initial test states.
    local astrStati, astrStatiQuoted = __updateTestStati(m_atSystemParameter.activeTests)

    -- Set the serial numbers.
    sendSerials(ulSerialFirst, ulSerialLast)
    sendTestNames(tTestDescription:getTestNames())
    sendTestStati(astrStati)

    -- Do not show the serial selector for the first board.
    local fThisIsTheFirstBoard = true

    ulSerialCurrent = ulSerialFirst
    repeat
      if fThisIsTheFirstBoard~=true then
        -- Reset all tests which are not deactivated to 'idle'.
        astrStati, astrStatiQuoted = __updateTestStati(m_atSystemParameter.activeTests)
        sendTestStati(astrStati)

        -- Show the next serial to test even if it might be changed. This is a good memory hook.
        sendCurrentSerial(ulSerialCurrent)

        -- Read the serial selector interaction code.
        tResult = tester:setInteractionGetJson('jsx/select_next_serial_and_tests.jsx', {
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
        tester:clearInteraction()
        -- Update the active boards.
        m_atSystemParameter.activeTests = tJson.activeTests
        -- Get the next serial number to test.
        ulSerialCurrent = tonumber(tJson.serialNext)
        astrStati, astrStatiQuoted = __updateTestStati(m_atSystemParameter.activeTests)
        sendTestStati(astrStati)
      end

      tLogSystem.info('Testing serial %d .', ulSerialCurrent)
      m_atSystemParameter.serial = ulSerialCurrent
      sendCurrentSerial(ulSerialCurrent)

      tResult = collect_testcases(tTestDescription, tJson.activeTests)
      if tResult==nil then
        tLogSystem.fatal('Failed to collect all test cases.')
      else
        local atModules = tResult

        tResult = apply_parameters(atModules, tTestDescription, ulSerialCurrent)
        if tResult==nil then
          tLogSystem.fatal('Failed to apply the parameters.')
        else
          tResult = check_parameters(atModules, tTestDescription)
          if tResult==nil then
            tLogSystem.fatal('Failed to check the parameters.')
          else
            tResult = run_tests(atModules, tTestDescription)
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
        tResult = tester:setInteractionGetJson('jsx/test_last_board.jsx')
        if tResult==nil then
          tLogSystem.fatal('Failed to read interaction.')
          break
        end
        local tJson = tResult
        pl.pretty.dump(tJson)
        tester:clearInteraction()
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

if m_zmqSocket~=nil then
  if m_zmqSocket:closed()==false then
    m_zmqSocket:close()
  end
  m_zmqSocket = nil
end

if m_zmqContext~=nil then
  m_zmqContext:destroy()
  m_zmqContext = nil
end
