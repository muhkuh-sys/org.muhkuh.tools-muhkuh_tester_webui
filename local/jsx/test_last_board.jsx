class Interaction extends React.Component {
  constructor(props) {
    super(props);
  }

  handleButtonQuit = () => {
    const tMsg = {
      button: 'quit'
    };
    fnSend(tMsg);
  };

  handleButtonBack = () => {
    const tMsg = {
      button: 'back'
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <div>
        <div style={{width: '100%'}}>
          <Typography align="center" variant="h1" gutterBottom>Fertig</Typography>
        </div>

        <div style={{display: 'table', width: '100%'}}>
          <div style={{display: 'table-cell', textAlign: 'right', verticalAlign: 'middle', paddingRight: '2em'}}>
            <SvgIcon color="primary" style={{fontSize: '8em'}}>
              <path fill="none" d="M0 0h24v24H0V0zm0 0h24v24H0V0z"/><path d="M16.59 7.58L10 14.17l-3.59-3.58L5 12l5 5 8-8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>
            </SvgIcon>
          </div>
          <div style={{display: 'table-cell', textAlign: 'left', verticalAlign: 'middle'}}>
            <Typography variant="subtitle1" gutterBottom>Das war das letzte Board.</Typography>
            <Typography variant="subtitle1" gutterBottom>Soll der Test beendet werden, oder möchtest Du zur Auswahl der Seriennummer?</Typography>
          </div>
        </div>
        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button color="primary" variant="contained" onClick={this.handleButtonQuit}>
              <SvgIcon>
                <path fill="none" d="M0 0h24v24H0z"/><path d="M13 3h-2v10h2V3zm4.83 2.17l-1.42 1.42C17.99 7.86 19 9.81 19 12c0 3.87-3.13 7-7 7s-7-3.13-7-7c0-2.19 1.01-4.14 2.58-5.42L6.17 5.17C4.23 6.82 3 9.26 3 12c0 4.97 4.03 9 9 9s9-4.03 9-9c0-2.74-1.23-5.18-3.17-6.83z"/>
              </SvgIcon>
              Beenden
            </Button>
          </div>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button variant="contained" onClick={this.handleButtonBack}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
              </SvgIcon>
              Zurück
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
