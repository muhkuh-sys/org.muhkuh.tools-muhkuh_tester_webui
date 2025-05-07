--
-- Example:
--   <Configuration>
--    <Parameter name="Inputs">[
--      {"id": "fertigungsauftrag", "plugin": "fertigungsauftrag_input"},
--      ...


local class = require 'pl.class'
local _M = class()

function _M:_init(tLog, tOrderInfo)
  self.tLog = tLog
  self.m_tOrderInfo = tOrderInfo
end



_M.get_jsx_level = 10
function _M:get_jsx()
  local strOrderNr
  if type(self.m_tOrderInfo)=='table' and type(self.m_tOrderInfo.ordernr)=='string' then
    strOrderNr = self.m_tOrderInfo.ordernr
  end

  local strJsx
  if strOrderNr==nil then
    strJsx = [[
      {
        initialize(tThis, _tState) {
          this.tThis = tThis;

          this.tRegExp_production_number = new RegExp('^F[0-9]{6}$');

          let strProductionNumber = '@LAST_PRODUCTION_NUMBER@';
          let fProductionNumberError = false;
          let strProductionNumberHelper = '';
          this.fHaveLastProductionNumber = true;
          if( strProductionNumber=='' ) {
            fProductionNumberError = true;
            strProductionNumberHelper = 'Missing production number';
            this.fHaveLastProductionNumber = false;
          }

          _tState['production_number_value'] = strProductionNumber;
          _tState['production_number_error'] = fProductionNumberError;
          _tState['production_number_helper'] = strProductionNumberHelper;
        },


        handleChange_ProductionNumber(event) {
          const val = event.target.value;
          let err = false;
          let msg = '';

          if( val=='' ) {
            err = true;
            msg = 'Missing production number';
          } else {
            let tReg = this.tRegExp_production_number;
            if( tReg.test(val)==true ) {
              err = false;
            } else {
              err = true;
              msg = 'Must be "F" followed by 6 numbers.';
            }
          }
          this.tThis.setState(
            {
              production_number_value: val,
              production_number_error: err,
              production_number_helper: msg
            },
            fnPersistState
          );
        },


        get_ui() {
          const tThis = this.tThis
          const tState = tThis.state;
          const tValue = tState['production_number_value'];
          const tError = tState['production_number_error'];
          const strHelper = tState['production_number_helper'];
          let tAdditionalInputElement = (
            <TextField
              id="production_number"
              label="Production Number"
              value={tValue}
              onChange={(event) => {this.handleChange_ProductionNumber(event);}}
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
              autoFocus={this.fHaveLastProductionNumber===false}
              action={
                actions => {
                  tThis.initialFocus = actions;
                }
              }
            />
          );

          return tAdditionalInputElement;
        },

        store_result(_tSystemParameter) {
            _tSystemParameter.production_number = this.tThis.state.production_number_value;
            console.log('Added result "production_number": ' + this.tThis.state.production_number_value.toString());
        }
      }
    ]]
  else
    local atReplacements = {
      ORDER_NR = strOrderNr
    }
    strJsx = string.gsub(
      [[
        {
          initialize(tThis, _tState) {
            this.tThis = tThis;

            _tState['production_number_value'] = '%%ORDER_NR%%';
          },


          get_ui() {
            const tThis = this.tThis
            const tState = tThis.state;
            const tValue = tState['production_number_value'];
            let tAdditionalInputElement = (
              <TextField
                id="production_number"
                label="Production Number"
                value={tValue}
                disabled={true}
                InputLabelProps={{
                  shrink: true,
                }}
                margin="normal"
              />
            );

            return tAdditionalInputElement;
          },

          store_result(_tSystemParameter) {
              _tSystemParameter.production_number = this.tThis.state.production_number_value;
              console.log('Added result "production_number": ' + this.tThis.state.production_number_value.toString());
          }
        }
      ]],
      '%%%%([%w_]+)%%%%',
      atReplacements
    )
  end

  return strJsx
end



_M.get_data_level = 10
function _M:get_data()
  return true
end


return _M
