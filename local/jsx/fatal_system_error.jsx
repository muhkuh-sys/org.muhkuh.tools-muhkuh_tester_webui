class Interaction extends React.Component {
  constructor(props) {
    super(props);

    this.initialFocus = null;

    this.strErrorMessage = '@ERROR_MESSAGE@';
  }

  componentDidMount() {
    if( this.initialFocus!==null ) {
      this.initialFocus.focusVisible();
    }
  }

  handleButtonOk = () => {
    const tMsg = {
      button: 'ok'
    };
    fnSend(tMsg);
  };

  render() {
    return (
      <div>
        <div style={{width: '100%'}}>
            <Typography align="center" variant="h3" gutterBottom>Fataler Fehler</Typography>
            <Typography align="center" variant="subtitle1" gutterBottom>{this.strErrorMessage}</Typography>
        </div>

        <div style={{width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em'}}>
          <div style={{display: 'inline', paddingLeft: '2em', paddingRight: '2em'}}>
            <Button color="primary" variant="contained" onClick={this.handleButtonOk} autoFocus action={actions => { this.initialFocus = actions; }}>
              <SvgIcon>
                <path fill="none" d="M0 0h24v24H0V0zm0 0h24v24H0V0z"/><path d="M16.59 7.58L10 14.17l-3.59-3.58L5 12l5 5 8-8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>
              </SvgIcon>
              OK
            </Button>
          </div>
        </div>
      </div>
    );
  }
}
