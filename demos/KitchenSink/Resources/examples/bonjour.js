// Publish a local service on startup
var bonjourSocket = Titanium.Socket.createTCPSocket({
	host:'localhost',
	port:40401,
	mode:Titanium.Socket.READ_WRITE_MODE
});
bonjourSocket.open();

bonjourSocket.addEventListener('newData', function(e) {
	while (socket.dataAvailable()) {
		var data = socket.read();
		if (data.toString() == 'req') {
			socket.write('Hello, from '+Titanium.Platform.id);
		}
		else {
			Titanium.UI.createAlertDialog({
				title:'Bonjour message!',
				message:data.toString()
			}).show();
		}
	}
});

var localService = Titanium.Bonjour.createBonjourService({
	name:'Bonjour Test: '+Titanium.Platform.id,
	type:'_utest._tcp',
	domain:'local.',
	socket:bonjourSocket
});
localService.addEventListener('didNotPublish', function(e) {
	Titanium.UI.createAlertDialog({
		title:'Publishing failure!', 
		message:e['error']
	}).show();
});

// TODO: How do we unpublish a service?  Just close its socket and then it's no
// longer available elsewhere, and they're in charge of this?
Titanium.Bonjour.publish(localService);

// Searcher for finding other services
var serviceBrowser = Titanium.Bonjour.createBonjourBrowser({
	type:'_utest._tcp',
	domain:'local.'
});

serviceBrowser.addEventListener('didNotSearch', function(e) {
	Titanium.UI.createAlertDialog({
		title:'Searching failure!',
		message:e['error']
	}).show();
});

var searching = false;
var searchButton = Titanium.UI.createButton({
	title:'Search...',
	top:10,
	height:50,
	width:200
});

searchButton.addEventListener('click', function(e) {
	if (!searching) {
		serviceBrowser.search();
		searchButton.title = 'Cancel search...';
		searching = true;
	}
	else {
		serviceBrowser.stopSearch();
		searchButton.title = 'Search...';
	}
});

var tableView = Titanium.UI.createTableView({
	style:Titanium.UI.iPhone.TableViewStyle.GROUPED,
	top:70,
	data:[{title:'No services', hasChild:false}]
});

tableView.addEventListener('click', function(r) {
	var service = r.rowData.service;
	if (service.socket == null) {
		service.addEventListener('didNotResolve', function(err) {
			Titanium.UI.createAlertDialog({
				title:'Resolve failure!',
				message:e['error']
			}).show();
		});
		
		service.addEventListener('resolved', function(s) {
			service.socket.open();
			service.socket.write('req');
		});
		Titanium.Bonjour.resolve(service);
	}
	else {
		service.socket.write('req');
	}
});

updateUI = function(e) {
	var data = [];
	var services = e['services'];
	for (var i=0; i < services.length; i++) {
		if (!services[i].socket.isValid()) {
			services[i].socket.open();
		}
		
		var row = Titanium.UI.createTableRow({
			title:services[i].name,
			service:services[i]
		});
		data.push(row);
	}
	if (data.length == 0) {
		data.push(Titanium.UI.createTableRow({
			title:'No services'
		}));
	}
	
	tableView.setData(data);
}

serviceBrowser.addEventListener('foundServices', updateUI);
serviceBrowser.addEventListener('removedServices', updateUI);

// Cleanup
Titanium.UI.currentWindow.addEventListener('blur', function(e) {
	serviceBrowser.stopSearch();
	bonjourSocket.close();
	for (var i=0; i < serviceBrowser.services.length; i++) {
		service = serviceBrowser.services[i];
		if (service.socket.isValid()) {
			service.socket.close();
		}
	}
});

Titanium.UI.currentWindow.add(searchButton);
Titanium.UI.currentWindow.add(tableView);