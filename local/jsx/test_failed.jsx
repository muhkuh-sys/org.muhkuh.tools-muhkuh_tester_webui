class Interaction extends React.Component {
  constructor(props) {
    super(props);

    this.strTestName = '@FAILED_TEST_NAME@';
    this.strMessage = '@FAILED_TEST_MESSAGE@';
  }

  handleButtonAgain = () => {
    const tMsg = {
      button: 'again'
    };
    fnSend(tMsg);
  };

  handleButtonError = () => {
    const tMsg = {
      button: 'error'
    };
    fnSend(tMsg);
  };

  handleButtonIgnore = () => {
    const tMsg = {
      button: 'ignore'
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <div>
        <div style={{width: '100%'}}>
          <Typography align="center" variant="h1" gutterBottom>Fehler</Typography>
        </div>

        <div style={{display: 'table', width: '100%'}}>
          <div style={{display: 'table-cell', textAlign: 'right', verticalAlign: 'middle', paddingRight: '2em'}}>
            <SvgIcon color="error" style={{fontSize: '8em'}}>
              <path d="M0 0h24v24H0z" fill="none"/><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
            </SvgIcon>
          </div>
          <div style={{display: 'table-cell', textAlign: 'left', verticalAlign: 'middle'}}>
            <Typography variant="subtitle1" gutterBottom>Test @FAILED_TEST_IDX@ ist fehlgeschlagen ({this.strTestName}).</Typography>
            <Typography variant="subtitle1" gutterBottom>Die Fehlermeldung ist: <br/><tt>{this.strMessage}</tt></Typography>
            <Typography variant="subtitle1" gutterBottom>Möchtest Du den letzten Test nochmal ausführen? Vielleicht fehlte ja nur ein Kabel.</Typography>
            <Typography variant="subtitle1" gutterBottom>Oder ist das wirklich ein Fehler?</Typography>
          </div>
        </div>
        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '1em', paddingRight: '1em'}}>
            <Button color="primary" variant="contained" onClick={this.handleButtonAgain}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/>
              </SvgIcon>
              Nochmal
            </Button>
          </div>
          <div style={{display: 'inline', paddingLeft: '1em', paddingRight: '1em'}}>
            <Button color="secondary" variant="contained" onClick={this.handleButtonError}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
              </SvgIcon>
              Fehler
            </Button>
          </div>
          <div style={{display: 'inline', paddingLeft: '1em', paddingRight: '1em'}}>
            <Button variant="contained" onClick={this.handleButtonIgnore}>
              <SvgIcon>
                <path d="M20 8h-2.81c-.45-.78-1.07-1.45-1.82-1.96L17 4.41 15.59 3l-2.17 2.17C12.96 5.06 12.49 5 12 5c-.49 0-.96.06-1.41.17L8.41 3 7 4.41l1.62 1.63C7.88 6.55 7.26 7.22 6.81 8H4v2h2.09c-.05.33-.09.66-.09 1v1H4v2h2v1c0 .34.04.67.09 1H4v2h2.81c1.04 1.79 2.97 3 5.19 3s4.15-1.21 5.19-3H20v-2h-2.09c.05-.33.09-.66.09-1v-1h2v-2h-2v-1c0-.34-.04-.67-.09-1H20V8zm-6 8h-4v-2h4v2zm0-4h-4v-2h4v2z"/>
              </SvgIcon>
              Ignorieren
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
