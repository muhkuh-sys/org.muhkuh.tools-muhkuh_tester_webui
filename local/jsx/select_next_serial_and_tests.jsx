class Interaction extends React.Component {
  constructor(props) {
    super(props);

    let astrTests = [
      @TEST_NAMES@
    ];
    this.astrTests = astrTests;

    this.serial_first = @SERIAL_FIRST@;
    this.serial_last = @SERIAL_LAST@;

    let _astrStati = [
      @TEST_STATI@
    ];
    const _atSummary = this.__getTestSelectionSummary(_astrStati);
    this.state = {
      serial_current: @SERIAL_CURRENT@,
      strTestsSummary: _atSummary[1],
      uiTestsSelected: astrTests.length,
      astrStati: _astrStati
    };
  }

  __getTestSelectionSummary(astrStati) {
    let uiActive = 0;
    astrStati.forEach(function(strState, uiIndex) {
      if( strState=='idle' ) {
        uiActive += 1;
      }
    }, this);
    const uiAll = astrStati.length;
    let strSummary = 'all';
    if( uiActive===0 ) {
      strSummary = 'none';
    } else if( uiAll>uiActive ) {
      strSummary = String(uiActive) + ' / ' + String(uiAll);
    }
    return [uiActive, strSummary];
  }

  handleChange_NextSerial = () => event => {
    const val = parseInt(event.target.value);
    if( isNaN(val)==false && val>=this.serial_first && val<=this.serial_last )
    {
      this.setState({serial_current: val});
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

    const _atSummary = this.__getTestSelectionSummary(_astrStati);

    this.setState({
      strTestsSummary: _atSummary[1],
      astrStati: _astrStati,
      uiTestsSelected: _atSummary[0]
    });
  };

  handleStartButton = () => {
    console.log('Test next board.');

    let atActiveTests = [];
    this.state.astrStati.forEach(function(strState, uiIndex) {
      atActiveTests.push( (strState=='idle') );
    }, this);

    const tMsg = {
      serialNext: this.state.serial_current,
      activeTests: atActiveTests
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <Paper style={{padding: '1em'}}>
        <div style={{width: '100%'}}>
          <Typography align="center" variant="h1" gutterBottom>Wähle die nächste Seriennummer aus</Typography>
          <Typography align="center" variant="subtitle1" gutterBottom>Oder klicke auf "Start testing", um mit der Seriennummer {this.state.serial_current} weiterzumachen.</Typography>
        </div>

        <div style={{display: 'block', margin: '1em'}}>
          <TextField
            id="serial_current"
            label="Next Serial"
            value={this.state.serial_current}
            onChange={this.handleChange_NextSerial()}
            type="number"
            required={true}
            InputLabelProps={{
              shrink: true,
            }}
            margin="normal"
          />
        </div>

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

        <Button disabled={this.state.uiTestsSelected===0} variant="extendedFab" onClick={this.handleStartButton}>
          <SvgIcon>
            <path d="M0 0h24v24H0z" fill="none"/><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/>
          </SvgIcon>
          Start testing
        </Button>
      </Paper>
    );
  }
}
