class Interaction extends React.Component {
  constructor(props) {
    super(props);

    let astrTests = [
      @TEST_NAMES@
    ];
    this.astrTests = astrTests;

    let _astrStati = [];
    astrTests.forEach(function(strTest, uiIndex) {
      _astrStati.push('idle');
    });

    this.production_number_reg = new RegExp('^F[0-9]{6}$');

    this.initialFocus = null;

    this.inputRefs = [];

    this.state = {
      production_number: '',
      production_number_error: true,
      production_number_helper: 'Missing production number',
      serial_first: 20000,
      number_of_boards: 1,
      strTestsSummary: 'all',
      uiTestsSelected: astrTests.length,
      astrStati: _astrStati,
      fActivateDebugging: false
    };
  }

  componentDidMount() {
    if( this.initialFocus!==null ) {
      this.initialFocus.focusVisible();
    }
  }

  handleKeyDown = e => {
    console.debug(e);
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
      if( this.production_number_reg.test(val)==true ) {
        err = false;
      } else {
        err = true;
        msg = 'Must be "F" followed by 6 numbers.';
      }
    }
    this.setState({
      production_number: val,
      production_number_error: err,
      production_number_helper: msg
    });
  };

  handleChange_FirstSerial = () => event => {
    const val = parseInt(event.target.value);
    if( isNaN(val)==false && val>=0 )
    {
      this.setState({serial_first: val});
    }
  };

  handleChange_NumberOfBoards = () => event => {
    const val = parseInt(event.target.value);
    if( isNaN(val)==false && val>0 )
    {
      this.setState({number_of_boards: val});
    }
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

  handleStartButton = () => {
    console.log('Start testing.');

    let atActiveTests = [];
    this.state.astrStati.forEach(function(strState, uiIndex) {
      atActiveTests.push( (strState=='idle') );
    }, this);

    const tMsg = {
      serialFirst: this.state.serial_first,
      numberOfBoards: this.state.number_of_boards,
      activeTests: atActiveTests,
      fActivateDebugging: this.state.fActivateDebugging,
      systemParameter: {
        production_number: this.state.production_number
      }
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <Paper style={{padding: '1em'}}>
        <div style={{display: 'block', margin: '1em'}}>
          <TextField
            id="production_number"
            label="Production Number"
            value={this.state.production_number}
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
            autoFocus
            action={
              actions => {
                this.initialFocus = actions;
              }
            }
          />
        </div>
        <div style={{display: 'block', margin: '1em'}}>
          <TextField
            id="serial_first"
            label="First Serial"
            value={this.state.serial_first}
            onChange={this.handleChange_FirstSerial()}
            type="number"
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
          />
        </div>
        <div style={{display: 'block', margin: '1em'}}>
          <TextField
            id="number_of_boards"
            label="Number Of Boards"
            value={this.state.number_of_boards}
            onChange={this.handleChange_NumberOfBoards()}
            type="number"
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
          />
        </div>
        <Typography variant="subtitle1" gutterBottom>The first serial in the test will be {this.state.serial_first}, the last {this.state.serial_first + this.state.number_of_boards - 1} .</Typography>

        <Button
          disabled={this.state.uiTestsSelected===0 || this.state.production_number_error===true}
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
            <FormControlLabel value="end" label="Activate debugging" control={<Checkbox checked={this.state.fActivateDebugging} onChange={this.handleActivateDebuggingClick} />} />
          </ExpansionPanelDetails>
        </ExpansionPanel>
      </Paper>
    );
  }
}
