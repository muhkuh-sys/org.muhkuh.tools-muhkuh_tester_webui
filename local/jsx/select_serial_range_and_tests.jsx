class Interaction extends React.Component {
  constructor(props) {
    super(props);

    let astrTests = [
      @TEST_NAMES@
    ];
    this.astrTests = astrTests;

    let atPredefinedValidators = new Map();
    atPredefinedValidators.set('NONE', '');
    atPredefinedValidators.set('PREFIX-LIST',
      'const strLabel = arguments[0];\n' +
      'const tData = arguments[1];\n' +
      'const fnTest = (strPrefix) => strLabel.startsWith(strPrefix);\n' +
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

    let strAdditionalInputs = '@ADDITIONAL_INPUTS@';
    let tAdditionalInputsDefinition = null;
    try {
      tAdditionalInputsDefinition = JSON.parse(strAdditionalInputs);

      const ajv = new Ajv();
      const tSchemaAdditionalInputs = {
        items: {
          properties: {
            id: {
              type: "string"
            },
            label: {
              type: "string"
            },
            required: {
              type: "string",
              enum: ["true", "false"]
            },
            regexp: {
              type: "string"
            }
          },
          type: "object",
          required: ["id", "label"],
          additionalProperties: false
        },
        type: "array"
      };
      const fnValidateAdditionalInputs = ajv.compile(tSchemaAdditionalInputs);
      const fValidAdditionalInputs = fnValidateAdditionalInputs(tAdditionalInputsDefinition);
      if( !fValidAdditionalInputs ) {
        console.error('AdditionalInputs are invalid!');
        tAdditionalInputsDefinition = null;
      }
    } catch (error) {
      console.error('Failed to parse the additional inputs definition.');
      console.error('Input data: "' + strAdditionalInputs + '"');
      console.error(error);
    }
    this.tAdditionalInputsDefinition = tAdditionalInputsDefinition;

    let strProductionNumber = '@LAST_PRODUCTION_NUMBER@';
    let fProductionNumberError = false;
    let strProductionNumberHelper = '';
    this.fHaveLastProductionNumber = true;
    if( strProductionNumber=='' ) {
      fProductionNumberError = true;
      strProductionNumberHelper = 'Missing production number';
      this.fHaveLastProductionNumber = false;
    }

    let _astrStati = [];
    astrTests.forEach(function(strTest, uiIndex) {
      _astrStati.push('idle');
    });

    let _atRegExp = {}
    _atRegExp.production_number = new RegExp('^F[0-9]{6}$');
    _atRegExp.matrix_label = new RegExp('^([0-9]{7})([0-9a-z])([0-9]{5,6})$');
    this.atRegExp = _atRegExp

    this.initialFocus = null;

    this.inputRefs = [];

    this.ulDeviceNr = null;
    this.ucHwRev = null;
    this.ulSerial = null;

    let _atRequired = {};
    this.atRequired = _atRequired;

    let _atLabels = {};
    this.atLabels = _atLabels;

    let _tState = {}
    /* Add the additional inputs first, so they can not overwrite any standard keys. */
    if( tAdditionalInputsDefinition!=null ) {
      tAdditionalInputsDefinition.forEach(function(tInput, uiIndex) {
        let strId = tInput.id;

        let strLabel = tInput.label;
        _atLabels[strId] = strLabel;

        let tReg = null;
        if( 'regexp' in tInput ) {
          tReg = new RegExp(tInput.regexp);
          _atRegExp[strId] = tReg;
        }

        let tRequired = false;
        if( 'required' in tInput ) {
          let strRequired = String(tInput.required).toUpperCase();
          if( strRequired=="TRUE" || strRequired=="1" ) {
            tRequired = true;
          }
        }
        _atRequired[strId] = tRequired;

        let strDefault = '';
        if( 'default' in tInput ) {
          strDefault = tInput.default;
        }

        let fError = false;
        let strHelper = '';
        if( strDefault=='' ) {
          if( tRequired==true ) {
            fError = true;
            strHelper = 'Missing value.';
          }
        } else if( tReg!=null ) {
          if( tReg.test(strDefault)==true ) {
            fError = false;
          } else {
            fError = true;
            strHelper = 'The input is invalid.';
          }
        }
        _tState[strId+'_value'] = strDefault;
        _tState[strId+'_error'] = fError;
        _tState[strId+'_helper'] = strHelper;
      });
    }

    _tState.production_number_value = strProductionNumber;
    _tState.production_number_error = fProductionNumberError;
    _tState.production_number_helper = strProductionNumberHelper;
    _tState.matrix_label_value = '';
    _tState.matrix_label_error = true;
    _tState.matrix_label_helper = 'Missing matrix label';
    _tState.strTestsSummary = 'all';
    _tState.uiTestsSelected = astrTests.length;
    _tState.astrStati = _astrStati;
    _tState.fActivateDebugging = false;
    _tState.fAllowInvalidPnMl = false;

    this.state = _tState;
  }

  componentDidMount() {
    if( this.initialFocus!==null ) {
      this.initialFocus.focusVisible();
    }
  }

  handleKeyDown = e => {
    const event = e;
    const { currentTarget } = e;
    if( event.key==='Enter' ) {
      let inputIndex = this.inputRefs.indexOf(currentTarget);
      if( inputIndex!==-1 ) {
        ++inputIndex;
        if( inputIndex>=this.inputRefs.length ) {
          inputIndex = 0;
        }
        this.inputRefs[inputIndex].focus();
        event.preventDefault();
      }
    }
  };

  handleChange_ProductionNumber = () => event => {
    const val = event.target.value;
    let err = false;
    let msg = '';

    if( val=='' ) {
      err = true;
      msg = 'Missing production number';
    } else {
      let tReg = this.atRegExp.production_number;
      if( tReg.test(val)==true ) {
        err = false;
      } else {
        err = true;
        msg = 'Must be "F" followed by 6 numbers.';
      }
    }
    this.setState({
      production_number_value: val,
      production_number_error: err,
      production_number_helper: msg
    });
  };

  handleChange_MatrixLabel = () => event => {
    const val = event.target.value;
    let err = false;
    let msg = '';

    if( val=='' ) {
      err = true;
      msg = 'Missing matrix label';
    } else {
      let strMatrixLabel = val.toLowerCase();
      let tReg = this.atRegExp.matrix_label;
      let astrMatchMatrixLabel = strMatrixLabel.match(tReg);
      if( Array.isArray(astrMatchMatrixLabel)==true ) {
        /* The hardware revision starts with the numbers 0-9 and continues for
         * revision 10 with the letter "a". Convert the letters to a number.
         */
        let tHwRev = astrMatchMatrixLabel[2];
        if( tHwRev>='a' ) {
          tHwRev = 10 + tHwRev.charCodeAt(0) - 'a'.charCodeAt(0);
        }
        tHwRev = parseInt(tHwRev);

        this.ulDeviceNr = parseInt(astrMatchMatrixLabel[1]);
        this.ucHwRev = parseInt(tHwRev);
        this.ulSerial = parseInt(astrMatchMatrixLabel[3]);

        /* Does a validation function exist? */
        const fnValidation = this.fnLabelIsValid;
        const tLabelValidationData = this.tLabelValidationData;
        if( fnValidation===null ) {
          /* No validation function means that everything is valid. */
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
            const fIsValid = this.fnLabelIsValid(strMatrixLabel, tLabelValidationData);
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
    this.setState({
      matrix_label_value: val,
      matrix_label_error: err,
      matrix_label_helper: msg
    });
  };

  handleChange_additional = (strId) => event => {
    const val = event.target.value;
    let err = false;
    let msg = '';

    if( val=='' ) {
      err = true;
      msg = 'Missing input';
    } else {
      if( strId in this.atRegExp ) {
        let tReg = this.atRegExp[strId];
        if( tReg.test(val)==true ) {
          err = false;
        } else {
          err = true;
          msg = 'Invalid input.';
        }
      } else {
        err = false;
      }
    }

    let tUpdate = {}
    tUpdate[strId+'_value'] = val;
    tUpdate[strId+'_error'] = err;
    tUpdate[strId+'_helper'] = msg;
    this.setState(tUpdate);
  };

  handleTestClick = (uiIndex) => {
    console.log('Click', uiIndex);
    let _astrStati = this.state.astrStati.slice();
    let strState = _astrStati[uiIndex];
    if( strState=='disabled' ) {
      strState = 'idle';
    } else {
      strState = 'disabled';
    }
    _astrStati[uiIndex] = strState;

    let uiActive = 0;
    _astrStati.forEach(function(strState, uiIndex) {
      if( strState=='idle' ) {
        uiActive += 1;
      }
    }, this);
    const uiAll = this.astrTests.length;
    let strSummary = 'all';
    if( uiActive===0 ) {
      strSummary = 'none';
    } else if( uiAll>uiActive ) {
      strSummary = String(uiActive) + ' / ' + String(uiAll);
    }
    this.setState({
      strTestsSummary: strSummary,
      astrStati: _astrStati,
      uiTestsSelected: uiActive
    });
  };

  handleActivateDebuggingClick = () => {
    const val = !this.state.fActivateDebugging;
    this.setState({
      fActivateDebugging: val
    });
  };

  handleAllowInvalidPnMlClick = () => {
    const val = !this.state.fAllowInvalidPnMl;
    this.setState({
      fAllowInvalidPnMl: val
    });
  };

  handleStartButton = () => {
    console.log('Start testing.');

    let atActiveTests = [];
    this.state.astrStati.forEach(function(strState, uiIndex) {
      atActiveTests.push( (strState=='idle') );
    }, this);

    let tSystemParameter = {};

    let tAdditionalInputsDefinition = this.tAdditionalInputsDefinition;
    if( tAdditionalInputsDefinition!=null ) {
      tAdditionalInputsDefinition.forEach(function(tInput, uiIndex) {
        let strId = tInput.id;
        let tValue = this.state[strId+'_value'];
        tSystemParameter[strId] = tValue;
      }, this);
    }

    tSystemParameter.production_number = this.state.production_number_value;
    tSystemParameter.devicenr = this.ulDeviceNr;
    tSystemParameter.hwrev = this.ucHwRev;
    tSystemParameter.serial = this.ulSerial;

    const tMsg = {
      activeTests: atActiveTests,
      fActivateDebugging: this.state.fActivateDebugging,
      systemParameter: tSystemParameter
    };
    fnSend(tMsg);
  };

  render() {
    let _tAdditionalInputs = [];
    let tAdditionalInputsDefinition = this.tAdditionalInputsDefinition;
    if( tAdditionalInputsDefinition!=null ) {
      tAdditionalInputsDefinition.forEach(function(tInput, uiIndex) {
        let strId = tInput.id;

        let tValue = this.state[strId+'_value'];
        let tError = this.state[strId+'_error'];
        let strHelper = this.state[strId+'_helper'];
        let tAdditionalInputElement = (
          <div style={{display: 'block', margin: '1em'}}>
            <TextField
              id={strId}
              label={this.atLabels[strId]}
              value={tValue}
              onChange={this.handleChange_additional(strId)}
              error={tError}
              helperText={strHelper}
              required={this.atRequired[strId]}
              InputProps={{
                onKeyDown: this.handleKeyDown,
                style: { fontSize: '3em' }
              }}
              inputRef={ref => this.inputRefs.push(ref)}
              InputLabelProps={{
                shrink: true,
              }}
              margin="normal"
            />
          </div>
        );
        _tAdditionalInputs.push(tAdditionalInputElement);
      }, this);
    }

    return (
      <Paper style={{padding: '1em'}}>
        <div style={{display: 'block', margin: '1em'}}>
          <TextField
            id="production_number"
            label="Production Number"
            value={this.state.production_number_value}
            onChange={this.handleChange_ProductionNumber()}
            error={this.state.production_number_error}
            helperText={this.state.production_number_helper}
            required={true}
            InputProps={{
              onKeyDown: this.handleKeyDown,
              style: { fontSize: '3em' }
            }}
            inputRef={ref => this.inputRefs.push(ref)}
            InputLabelProps={{
              shrink: true,
            }}
            margin="normal"
            autoFocus={this.fHaveLastProductionNumber===false}
            action={
              actions => {
                this.initialFocus = actions;
              }
            }
          />
        </div>
        <div style={{display: 'block', margin: '1em'}}>
        <TextField
            id="matrix_label"
            label="Matrix Label"
            value={this.state.matrix_label_value}
            onChange={this.handleChange_MatrixLabel()}
            error={this.state.matrix_label_error}
            helperText={this.state.matrix_label_helper}
            required={true}
            InputProps={{
              onKeyDown: this.handleKeyDown,
              style: { fontSize: '3em' }
            }}
            inputRef={ref => this.inputRefs.push(ref)}
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
        </div>
        {_tAdditionalInputs}

        <Button
          disabled={this.state.uiTestsSelected===0 || (this.state.fAllowInvalidPnMl===false && (this.state.production_number_error===true || this.state.matrix_label_error===true))}
          color="primary"
          variant="contained"
          onClick={this.handleStartButton}
          buttonRef={ref => this.inputRefs.push(ref)}
        >
          <SvgIcon>
            <path d="M0 0h24v24H0z" fill="none"/><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/>
          </SvgIcon>
          Start testing
        </Button>

        <ExpansionPanel style={{margin: '1em'}}>
          <ExpansionPanelSummary expandIcon={<SvgIcon><path d="M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z"/><path d="M0 0h24v24H0z" fill="none"/></SvgIcon>}>
            <Typography>Selected tests: {this.state.strTestsSummary}</Typography>
          </ExpansionPanelSummary>
          <ExpansionPanelDetails>
            <List>
            {this.astrTests.map(function(strTestName, uiIndex) {return (
              <ListItem key={strTestName} role={undefined} dense button onClick={() => this.handleTestClick(uiIndex)}>
                <Checkbox
                  checked={this.state.astrStati[uiIndex]=='idle'}
                  tabIndex={-1}
                  disableRipple
                />
                <ListItemText primary={this.astrTests[uiIndex]} />
              </ListItem>
            );}, this)}
            </List>
          </ExpansionPanelDetails>
        </ExpansionPanel>

        <ExpansionPanel style={{margin: '1em'}}>
          <ExpansionPanelSummary expandIcon={<SvgIcon><path d="M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z"/><path d="M0 0h24v24H0z" fill="none"/></SvgIcon>}>
            <Typography>Advanced options</Typography>
          </ExpansionPanelSummary>
          <ExpansionPanelDetails>
            <List>
              <ListItem key="ActivateDebugging" role={undefined} dense button onClick={() => this.handleActivateDebuggingClick()}>
                <Checkbox
                  checked={this.state.fActivateDebugging}
                  tabIndex={-1}
                  disableRipple
                />
                <ListItemText primary="Activate debugging"/>
              </ListItem>
              <ListItem key="AllowInvalidPnMl" role={undefined} dense button onClick={() => this.handleAllowInvalidPnMlClick()}>
                <Checkbox
                  checked={this.state.fAllowInvalidPnMl}
                  tabIndex={-1}
                  disableRipple
                />
                <ListItemText primary="Allow invalid production number and matrix label."/>
              </ListItem>
            </List>
          </ExpansionPanelDetails>
        </ExpansionPanel>
      </Paper>
    );
  }
}
