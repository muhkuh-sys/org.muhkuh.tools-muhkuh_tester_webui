--
-- Example:
--   <Configuration>
--    <Parameter name="Inputs">[
--      {
--        "id": "aoi_top",
--        "plugin": "regexp_input",
--        "parameter": {
--          "label": "AOI Label Oberseite",
--          "required": "true",
--          "regexp": "^[0-9]+$",
--          "level": 12
--        }
--      },
--      ...


local class = require 'pl.class'
local _M = class()

function _M:_init(tLog, tOrderInfo, tPluginCfg)
  self.tLog = tLog
  self.m_tOrderInfo = tOrderInfo

  local astrReplacements = {
    INPUT_ID = tPluginCfg.id,
    INPUT_LABEL = 'Misconfigured input "' .. tostring(tPluginCfg.id) .. '"',
    INPUT_REQUIRED = false,
    INPUT_REGEXP = '.+'
  }

  local uiLevel = 99

  if type(tPluginCfg.parameter)~='table' then
    tLog.error('The input plugin configuration has no "parameter" table.')

  elseif type(tPluginCfg.parameter.label)~='string' then
    tLog.error('The input plugin parameters must have a "label" attribute of the type "string".')


  elseif type(tPluginCfg.parameter.regexp)~='string' then
    tLog.error('The input plugin parameters must have a "regexp" attribute of the type "string".')

  else
    --- @type boolean|nil
    local fRequired = false
    if tPluginCfg.parameter.required~=nil then
      fRequired = self.__parseBoolean(tPluginCfg.parameter.required)
      if fRequired==nil then
        tLog.error('The "required" attribute of the input plugin must have a type of "boolean".')
      end
    end

    if tPluginCfg.parameter.level~=nil then
      local uiLevelParam = tonumber(tPluginCfg.parameter.level)
      if uiLevelParam==nil then
        tLog.error('The input plugin parameters must have a "level" attribute of the type "number".')

      else
        uiLevel = uiLevelParam
      end
    end

    if fRequired~=nil then
      astrReplacements.INPUT_LABEL = tPluginCfg.parameter.label
      astrReplacements.INPUT_REQUIRED = tPluginCfg.parameter.required
      astrReplacements.INPUT_REGEXP = tPluginCfg.parameter.regexp
    end
  end

  self.m_astrReplacements = astrReplacements
  self.get_jsx_level = uiLevel
  self.get_data_level = uiLevel
end



function _M.__parseBoolean(tValue)
  local tResult
  if type(tValue)=='boolean' then
    tResult = tValue
  else
    local strValue = string.lower(tostring(tValue))
    if strValue=='true' then
      tResult = true
    elseif strValue=='false' then
      tResult = false
    end
  end

  return tResult
end



function _M:get_jsx()
  local strJsx = string.gsub(
    [[
      {
        initialize(tThis, _tState) {
          this.tThis = tThis;

          this.tRegExp_%%INPUT_ID%% = new RegExp('%%INPUT_REGEXP%%');

          let fInputError = false;
          let strInputHelper = '';
          if( %%INPUT_REQUIRED%% ) {
            fInputError = true;
            strInputHelper = 'Missing value';
          }

          _tState['%%INPUT_ID%%_value'] = '';
          _tState['%%INPUT_ID%%_error'] = fInputError;
          _tState['%%INPUT_ID%%_helper'] = strInputHelper;
        },


        handleChange_%%INPUT_ID%%(event) {
          const val = event.target.value;
          let err = false;
          let msg = '';

          if( val=='' ) {
            err = true;
            msg = 'Missing production number';
          } else {
            let tReg = this.tRegExp_%%INPUT_ID%%;
            if( tReg.test(val)==true ) {
              err = false;
            } else {
              err = true;
              msg = 'The input does not match the expected form.';
            }
          }
          this.tThis.setState(
            {
              %%INPUT_ID%%_value: val,
              %%INPUT_ID%%_error: err,
              %%INPUT_ID%%_helper: msg
            },
            fnPersistState
          );
        },


        get_ui() {
          const tThis = this.tThis
          const tState = tThis.state;
          const tValue = tState['%%INPUT_ID%%_value'];
          const tError = tState['%%INPUT_ID%%_error'];
          const strHelper = tState['%%INPUT_ID%%_helper'];
          let tAdditionalInputElement = (
            <TextField
              id="%%INPUT_ID%%"
              label="%%INPUT_LABEL%%"
              value={tValue}
              onChange={(event) => {this.handleChange_%%INPUT_ID%%(event);}}
              error={tError}
              helperText={strHelper}
              required={true}
              InputProps={{
                onKeyDown: tThis.handleKeyDown,
                style: { fontSize: '2em' }
              }}
              inputRef={ref => tThis.inputRefs.push(ref)}
              InputLabelProps={{
                shrink: true,
              }}
              margin="normal"
            />
          );

          return tAdditionalInputElement;
        },

        store_result(_tSystemParameter) {
            _tSystemParameter['%%INPUT_ID%%'] = this.tThis.state.%%INPUT_ID%%_value;
            console.log('Added result "%%INPUT_ID%%": ' + this.tThis.state.%%INPUT_ID%%_value.toString());
        }
      }
    ]],
    '%%%%([%w_]+)%%%%',
    self.m_astrReplacements
  )

  return strJsx
end



function _M:get_data()
  return true
end


return _M
