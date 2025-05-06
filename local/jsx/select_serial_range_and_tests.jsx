class Interaction extends React.Component {
  constructor(props) {
    super(props);

    let astrTests = [
      @TEST_NAMES@
    ];
    this.astrTests = astrTests;

    this.atInputElements = [
        @INPUT_ELEMENTS@
    ];

    // The function "fnGetTestStati" returns the test stati of the previous run.
    // If this is the first run on an old tester, it returns an empty array.
    // Set all tests to "idle" in this case.
    let _astrStati = fnGetTestStati();
    if( _astrStati.length!==astrTests.length ) {
      _astrStati = [];
      astrTests.forEach(function(strTest, uiIndex) {
        _astrStati.push('idle');
      });
    }

    this.initialFocus = null;

    this.inputRefs = [];

    let _atRequired = {};
    this.atRequired = _atRequired;

    let _atLabels = {};
    this.atLabels = _atLabels;

    let _tState = fnGetPersistentState();
    if( _tState===null ) {
      _tState = {};
      /* Add all inputs. */
      this.atInputElements.forEach(function(tInputObject) {
          tInputObject.initialize(this, _tState);
        },
        this
      );

      _tState.strTestsSummary = 'all';
      _tState.uiTestsSelected = astrTests.length;
      _tState.astrStati = _astrStati;
      _tState.fDisableLogging = false;
      _tState.fActivateDebugging = false;
      _tState.fAllowInvalidPnMl = false;
    }

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
    this.setState(tUpdate, fnPersistState);
  };

  handleTestClick = (uiIndex) => {
    let _astrStati = this.state.astrStati.slice();
    let strState = _astrStati[uiIndex];
    if( strState=='disabled' ) {
      strState = 'idle';
    } else {
      strState = 'disabled';
    }
    _astrStati[uiIndex] = strState;
    fnSetLocalTestState(uiIndex, strState);

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
    this.setState(
      {
        strTestsSummary: strSummary,
        astrStati: _astrStati,
        uiTestsSelected: uiActive
      },
      fnPersistState
    );
  };

  handleDisableLoggingClick = () => {
    const val = !this.state.fDisableLogging;
    this.setState(
      {
        fDisableLogging: val
      },
      fnPersistState
    );
  };

  handleActivateDebuggingClick = () => {
    const val = !this.state.fActivateDebugging;
    this.setState(
      {
        fActivateDebugging: val
      },
      fnPersistState
    );
  };

  handleAllowInvalidPnMlClick = () => {
    const val = !this.state.fAllowInvalidPnMl;
    this.setState(
      {
        fAllowInvalidPnMl: val
      },
      fnPersistState
    );
  };

  handleStartButton = () => {
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

    // Store all results in the system parameters.
    this.atInputElements.forEach(function(tInputObject) {
        tInputObject.store_result(tSystemParameter);
      },
      this
    );

    const tMsg = {
      activeTests: atActiveTests,
      fDisableLogging: this.state.fDisableLogging,
      fActivateDebugging: this.state.fActivateDebugging,
      systemParameter: tSystemParameter
    };
    fnSend(tMsg);
  };

  render() {
    let _tInputElements = [];
    this.atInputElements.forEach(
      function(tInputObject) {
        const tElement = tInputObject.get_ui();
        if( tElement!=null ) {
          _tInputElements.push(<div style={{display: 'block', margin: '0.5em'}}>{tElement}</div>);
        }
      },
      this
    );

    const bEnricoMode = fnGetEnricoMode();

    return (
      <Paper style={{padding: '1em'}}>
        {_tInputElements}

        <Button
          disabled={this.state.uiTestsSelected===0 || (this.state.fAllowInvalidPnMl===false && (this.state.production_number_error===true || this.state.matrix_label_error===true))}
          color="primary"
          variant="contained"
          onClick={this.handleStartButton}
          ref={ref => this.inputRefs.push(ref)}
        >
          <SvgIcon>
            <path d="M0 0h24v24H0z" fill="none"/><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/>
          </SvgIcon>
          Start testing
        </Button>

        <ExpansionPanel style={{margin: '1em'}} disabled={!bEnricoMode}>
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

        <ExpansionPanel style={{margin: '1em'}} disabled={!bEnricoMode}>
          <ExpansionPanelSummary expandIcon={<SvgIcon><path d="M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z"/><path d="M0 0h24v24H0z" fill="none"/></SvgIcon>}>
            <Typography>Advanced options</Typography>
          </ExpansionPanelSummary>
          <ExpansionPanelDetails>
            <List>
              <ListItem key="DisableLogging" role={undefined} dense button onClick={() => this.handleDisableLoggingClick()}>
                <Checkbox
                  checked={this.state.fDisableLogging}
                  tabIndex={-1}
                  disableRipple
                />
                <ListItemText primary="Do not send log messages to the database."/>
              </ListItem>
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
