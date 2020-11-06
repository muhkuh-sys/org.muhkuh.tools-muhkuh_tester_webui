class Interaction extends React.Component {
  constructor(props) {
    super(props);

    this.initialFocus = null;

    this.fAgain = @AGAIN@;
    this.strIp = "@IP@";

    let strHeader = 'Connect to the debugger server';
    if( this.fAgain==true ) {
      strHeader = 'Failed to connect';
    }
    this.strHeader = strHeader;
  }

  componentDidMount() {
    if( this.initialFocus!==null ) {
      this.initialFocus.focusVisible();
    }
  }

  handleButtonConnect = () => {
    const tMsg = {
      button: 'connect'
    };
    fnSend(tMsg);
  };

  handleButtonCancel = () => {
    const tMsg = {
      button: 'cancel'
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <div>
        <div>
          <Typography align="center" variant="h2" gutterBottom>
            {this.strHeader}
          </Typography>
          <Typography variant="subtitle1" gutterBottom>
            Start the debugger server on the host {this.strIp} and open the file "debug_hooks.lua". Then press "Connect".
          </Typography>
          <Typography variant="subtitle1" gutterBottom>
            Press "cancel" to continue without debugging.
          </Typography>
        </div>

        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button variant="extendedFab" onClick={this.handleButtonConnect} autoFocus action={actions => { this.initialFocus = actions; }}>
              <SvgIcon>
                <path fill="none" d="M0 0h24v24H0V0zm0 0h24v24H0V0z"/><path d="M16.59 7.58L10 14.17l-3.59-3.58L5 12l5 5 8-8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>
              </SvgIcon>
              Connect
            </Button>
          </div>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button variant="extendedFab" onClick={this.handleButtonCancel}>
              <SvgIcon>
                <path d="M0 0h24v24H0z" fill="none"/><path d="M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/>
              </SvgIcon>
              Abbrechen
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
