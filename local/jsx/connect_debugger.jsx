class Interaction extends React.Component {
	constructor(props) {
		super(props);

		this.initialFocus = null;

		this.inputRefs = [];

		this.fAgain = @AGAIN@;
		this.strIp = "@IP@";

		// https://github.com/sindresorhus/ip-regex/blob/main/index.js
		const v4 = '(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]\\d|\\d)){3}';
		this.IP_reg = new RegExp(`^${v4}$`);

		let strHeader = 'Connect to the debugger server';
		if (this.fAgain == true) {
			strHeader = 'Failed to connect';
		}
		this.strHeader = strHeader;

		this.state = {
			IP: this.strIp,
			IP_error: false,
			IP_helper: '',
			Port: 8818,
		};
	}

handleChange_IP = () => event => {
	const val = event.target.value;
	let err = false;
	let msg = '';

	if (val == '') {
		err = true;
		msg = 'Missing IP Adress';
	} else {
		if (this.IP_reg.test(val) == true) {
			err = false;
		} else {
			err = true;
			msg = 'IP Adress not valid';
		}
	}
	this.setState({
		IP: val,
		IP_error: err,
		IP_helper: msg
	});
};

handleChange_Port = () => event => {
	const val = parseInt(event.target.value);
	if (isNaN(val) == false && val >= 0 && val <= 65535) {
		this.setState({ Port: val });
	}
};

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

componentDidMount() {
	if (this.initialFocus !== null) {
		this.initialFocus.focusVisible();
	}
}

handleButtonConnect = () => {
	const tMsg = {
		button: 'connect',
		IP: this.state.IP,
		Port: this.state.Port
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
				To start debugging, the following steps are necessary: 
				<ul>
  					<li>The dependency of LuaPanda must be included to the test procedure.</li>
 					<li>Open the workspace of the test procedure in VSCode.</li>
					<li>Make sure that the extension "LuaPanda" is installed in VScode.</li>
					<li>Go to the option "Run and Debug" and create a launch.json file by choosing of LuaPanda.</li>
					<li>Change the option "stopOnEntry" to false in the launch.json file. </li>
					<li>Start Debugging ("name": "LuaPanda") in VSCode.</li>
					<li>Set the IP address (host address: {this.strIp}) and port number in the text fields. The port number must be the same as in the launch.json file.</li>
  					<li>Then press "Connect".</li>
				</ul>
				</Typography>
				<Typography variant="subtitle1" gutterBottom>
					Press "cancel" to continue without debugging.
				</Typography>
			</div>

			<div style={{ display: 'block', margin: '1em' }}>
				<TextField
					id="IP Adress"
					label="IP Adress"
					value={this.state.IP}
					onChange={this.handleChange_IP()}
					error={this.state.IP_error}
					helperText={this.state.IP_helper}
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
			<div style={{ display: 'block', margin: '1em' }}>
				<TextField
					id="Port Number"
					label="Port Number"
					value={this.state.Port}
					onChange={this.handleChange_Port()}
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

			<div style={{ width: '100%', textAlign: 'center', verticalAlign: 'middle', padding: '2em' }}>
				<div style={{ display: 'inline', paddingLeft: '2em', paddingRight: '2em' }}>
					<Button
						disabled={this.state.IP_error === true}
						color="primary"
						variant="contained"
						onClick={this.handleButtonConnect}
						autoFocus action={actions => { this.initialFocus = actions; }}>
						<SvgIcon>
							<path fill="none" d="M0 0h24v24H0V0zm0 0h24v24H0V0z" /><path d="M16.59 7.58L10 14.17l-3.59-3.58L5 12l5 5 8-8zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z" />
						</SvgIcon>
						Connect
					</Button>
				</div>
				<div style={{ display: 'inline', paddingLeft: '2em', paddingRight: '2em' }}>
					<Button variant="contained" onClick={this.handleButtonCancel}>
						<SvgIcon>
							<path d="M0 0h24v24H0z" fill="none" /><path d="M14.59 8L12 10.59 9.41 8 8 9.41 10.59 12 8 14.59 9.41 16 12 13.41 14.59 16 16 14.59 13.41 12 16 9.41 14.59 8zM12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" />
						</SvgIcon>
						Abbrechen
					</Button>
				</div>
			</div>
		</div>
	);
}
}
