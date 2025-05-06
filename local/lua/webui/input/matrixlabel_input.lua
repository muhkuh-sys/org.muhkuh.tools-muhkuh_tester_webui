--
-- Example:
--    <Configuration>
--      <Parameter name="Inputs">[
--        ...
--        {
--          "id": "matrixlabel",
--          "plugin": "matrixlabel_input",
--          "parameter": {
--            "validation": {
--              "function": "PREFIX-LIST",
--              "datatyp": "CSV",
--              "data": "12345678"
--            }
--          }
--        }
--      ]</Parameter>




local class = require 'pl.class'
local _M = class()

function _M:_init(tLog, tParameter)
  self.tLog = tLog

  -- Set the default label validator to "NONE".
  local strLabelValidationFnId = 'NONE'
  local strLabelValidationDataTyp = 'STRING'
  local strLabelValidationData = ''

  -- Overwrite the defaults with the parameters.
  if type(tParameter)=='table' then
    local tValidationCfg = tParameter['validation']
    if type(tValidationCfg)=='table' then
      local strValidatorFnId = tValidationCfg['function']
      if type(strValidatorFnId)=='string' then
        strLabelValidationFnId = string.upper(strValidatorFnId);
      end

      local strValidationDataTyp = tValidationCfg['datatyp']
      if type(strValidationDataTyp)=='string' then
        strLabelValidationDataTyp = string.upper(strValidationDataTyp);
      end

      local strValidationData = tValidationCfg['data']
      if type(strValidationData)=='string' then
        strLabelValidationData = strValidationData;
      end
    end
  end

  self.m_astrReplacements = {
    ['LABEL_VALIDATION_FUNCTION'] = strLabelValidationFnId,
    ['LABEL_VALIDATION_DATA_TYP'] = strLabelValidationDataTyp,
    ['LABEL_VALIDATION_DATA'] = strLabelValidationData
  }
end



_M.get_jsx_level = 11
function _M:get_jsx()
  local strTemplate = [[
    {
      initialize(tThis, _tState) {
        this.tThis = tThis;

        this.tRegExp_matrix_label = new RegExp('^([0-9]{7})([0-9a-z])([0-9]{5,6})$');

        this.ulDeviceNr = null;
        this.ucHwRev = null;
        this.ulSerial = null;

        let strProductionNumber = '@LAST_PRODUCTION_NUMBER@';
        this.fHaveLastProductionNumber = true;
        if( strProductionNumber=='' ) {
          this.fHaveLastProductionNumber = false;
        }

        let atPredefinedValidators = new Map();
        atPredefinedValidators.set('NONE', '');
        atPredefinedValidators.set('PREFIX-LIST',
          'const strLabel = arguments[0];\n' +
          'const tData = arguments[1];\n' +
          'const fnTest = (strPrefix) => strLabel.toLowerCase().startsWith(strPrefix.toLowerCase());\n' +
          'const iIdx = tData.findIndex(fnTest);\n' +
          'return iIdx!=-1;');

        let strFunctionLabelIsValid = '@LABEL_VALIDATION_FUNCTION@';
        if( atPredefinedValidators.has(strFunctionLabelIsValid)==true ) {
          strFunctionLabelIsValid = atPredefinedValidators.get(strFunctionLabelIsValid);
        }

        let fnLabelIsValid = null;
        if( strFunctionLabelIsValid!=='' ) {
          try {
            fnLabelIsValid = new Function(strFunctionLabelIsValid);
          } catch (error) {
            console.error('Failed to parse the label validation function.');
            fnLabelIsValid = false;
          }
        }
        this.fnLabelIsValid = fnLabelIsValid;

        let strLabelValidationDataTyp = '@LABEL_VALIDATION_DATA_TYP@';
        strLabelValidationDataTyp = strLabelValidationDataTyp.toUpperCase();
        const strLabelValidationData = '@LABEL_VALIDATION_DATA@';
        let tLabelValidationData = null;
        if( strLabelValidationDataTyp=='JSON' ) {
          try {
            tLabelValidationData = JSON.parse(strLabelValidationData);
          } catch (error) {
            console.error('Failed to parse the label validation data.');
          }
        } else if( strLabelValidationDataTyp=='CSV' ) {
          tLabelValidationData = strLabelValidationData.split(',').map(strValue => strValue.trim());
        } else if( strLabelValidationDataTyp=='STRING' ) {
          tLabelValidationData = strLabelValidationData;
        }
        this.tLabelValidationData = tLabelValidationData;

        _tState.matrix_label_value = '';
        _tState.matrix_label_error = true;
        _tState.matrix_label_helper = 'Missing matrix label';
      },


      handleChange_MatrixLabel(event) {
        const tThis = this.tThis;
        const val = event.target.value;
        let err = false;
        let msg = '';

        if( val=='' ) {
          err = true;
          msg = 'Missing matrix label';
        } else {
          let strMatrixLabel = val.toLowerCase();
          let tReg = this.tRegExp_matrix_label;
          let astrMatchMatrixLabel = strMatrixLabel.match(tReg);
          if( Array.isArray(astrMatchMatrixLabel)==true ) {
            // The hardware revision starts with the numbers 0-9 and continues for
            // revision 10 with the letter "a". Convert the letters to a number.
            let tHwRev = astrMatchMatrixLabel[2];
            if( tHwRev>='a' ) {
              tHwRev = 10 + tHwRev.charCodeAt(0) - 'a'.charCodeAt(0);
            }
            tHwRev = parseInt(tHwRev);

            this.ulDeviceNr = parseInt(astrMatchMatrixLabel[1]);
            this.ucHwRev = parseInt(tHwRev);
            this.ulSerial = parseInt(astrMatchMatrixLabel[3]);

            // Does a validation function exist?
            const fnValidation = this.fnLabelIsValid;
            const tLabelValidationData = this.tLabelValidationData;
            if( fnValidation===null ) {
              // No validation function means that everything is valid.
              console.log('No fn');
              err = false;
              msg = '';
            } else if( fnValidation===false ) {
              err = true;
              msg = 'The label validation function is not correct. This is a configuration problem of the teststation.';
            } else if( tLabelValidationData==null ) {
              err = true;
              msg = 'The label validation data is not correct. This is a configuration problem of the teststation.';
            } else {
              /* Check if the matrix label starts with one of the elements of the
                * valid boards array.
                */
              try {
                const fIsValid = fnValidation(strMatrixLabel, tLabelValidationData);
                if( fIsValid==true ) {
                  err = false;
                  msg = '';
                } else {
                  err = true;
                  msg = 'This device is not supported by the test.';
                }
              } catch (error) {
                err = true;
                msg = 'The validation function crashed!';
              }
            }
          } else {
            err = true;
            msg = 'Must be 7 digits device number followed by 1 character revision (0-9, a-z) and finally 5 to 6 digits serial number.';
          }
        }
        tThis.setState(
          {
            matrix_label_value: val,
            matrix_label_error: err,
            matrix_label_helper: msg
          },
          fnPersistState
        );
      },

      get_ui() {
          const tThis = this.tThis;
          const tState = tThis.state;
          const strValue = tState.matrix_label_value;
          const strError = tState.matrix_label_error;
          const strHelper = tState.matrix_label_helper;
          let tAdditionalInputElement = (
              <TextField
              id="matrix_label"
              label="Matrix Label"
              value={strValue}
              onChange={(event) => {this.handleChange_MatrixLabel(event);}}
              error={strError}
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
              autoFocus={this.fHaveLastProductionNumber===true}
              action={
                actions => {
                  this.initialFocus = actions;
                }
              }
            />
          );
          return tAdditionalInputElement;
      },

      store_result(_tSystemParameter) {
          _tSystemParameter.devicenr = this.ulDeviceNr;
          console.log('Added result "devicenr": ' + this.ulDeviceNr.toString());
          _tSystemParameter.hwrev = this.ucHwRev;
          console.log('Added result "hwrev": ' + this.ucHwRev.toString());
          _tSystemParameter.serial = this.ulSerial;
          console.log('Added result "serial": ' + this.ulSerial.toString());
      }
    }
  ]]
  -- NOTE: Do not directly return the result of "gsub". The function returns 2 parameters.
  local strReplaced = string.gsub(strTemplate, '@([%w_]+)@', self.m_astrReplacements)
  return strReplaced
end



_M.get_data_level = 11
function _M:get_data()
end


return _M
