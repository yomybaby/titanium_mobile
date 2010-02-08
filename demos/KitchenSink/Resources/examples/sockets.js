var win = Titanium.UI.currentWindow;
var socket = Titanium.Socket.createTCPSocket({host:'localhost', 
					      port:40404, 
					      mode:Titanium.Socket.READ_WRITE_MODE});


var messageLabel = Titanium.UI.createLabel({
	text:'Socket messages',
	font:{fontSize:14},
	color:'#777',
	top:260,
	left:10
    });
win.add(messageLabel);

var readLabel = Titanium.UI.createLabel({
	text:'Read data',
	font:{fontSize:14},
	color:'#777',
	top:280,
	left:10,
	width:200
    });
win.add(readLabel);

var connectButton = Titanium.UI.createButton({
	title:'Open localhost:40404',
	width:200,
	height:40,
	top:10
    });
win.add(connectButton);
connectButton.addEventListener('click', function() {
	try {
	    socket.open();
	    messageLabel.text = 'Opened!';
	} catch (e) {
	    Titanium.API.info('Exception: '+e);
	}
    });

var closeButton = Titanium.UI.createButton({
	title:'Close',
	width:200,
	height:40,
	top:60
    });
win.add(closeButton);
closeButton.addEventListener('click', function() {
	socket.close();
	messageLabel.text = 'Closed!';
    });

var validButton = Titanium.UI.createButton({
	title:'Valid?',
	width:200,
	height:40,
	top:110
    });
win.add(validButton);
validButton.addEventListener('click', function() {
	// Display this value somewhere
	var valid = socket.isValid();
	messageLabel.text = 'Valid? '+valid;
    });

var writeButton = Titanium.UI.createButton({
	title:"Write 'Paradise Lost'",
	width:200,
	height:40,
	top:160
    });
win.add(writeButton);
writeButton.addEventListener('click', function() {
	var plFile = Titanium.Filesystem.getFile(Titanium.Filesystem.resourcesDirectory, 'paradise_lost.txt');
	var plData = plFile.read();
	
	socket.write(plData);
	messageLabel.text = "I'm a writer!";
    });

var readButton = Titanium.UI.createButton({
	title:'Read data',
	width:200,
	height:40,
	top:210
    });
win.add(readButton);
readButton.addEventListener('click', function() {
	var blob = socket.read();
	messageLabel.text = "I'm a reader!";
	readLabel.text = blob;
    });