class Interaction extends React.Component {
  constructor(props) {
    super(props);

    const uiLastRunningTest = fnGetLastRunningTest();
    const astrTestNames = fnGetTestNames();

    let strMessage = '';
    if( uiLastRunningTest!==null ) {
      const strTestName = astrTestNames[uiLastRunningTest];
      strMessage = `Test ${uiLastRunningTest+1} ist fehlgeschlagen (${strTestName}).`;
    } else {
      strMessage = 'Der letzte Test ist fehlgeschlagen.\n';
    }
    this.strMessage = strMessage;
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
            <Typography variant="subtitle1" gutterBottom>{this.strMessage}</Typography>
            <Typography variant="subtitle1" gutterBottom>Möchtest Du den letzten Test nochmal ausführen? Vielleicht fehlte ja nur ein Kabel.</Typography>
            <Typography variant="subtitle1" gutterBottom>Oder ist das wirklich ein Fehler?</Typography>
          </div>
        </div>
        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '1em', paddingRight: '1em'}}>
            <Button variant="extendedFab" onClick={this.handleButtonAgain}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/>
              </SvgIcon>
              Nochmal
            </Button>
          </div>
          <div style={{display: 'inline', paddingLeft: '1em', paddingRight: '1em'}}>
            <Button variant="extendedFab" onClick={this.handleButtonError}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
              </SvgIcon>
              Fehler
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
