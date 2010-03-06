// Publish a local service on startup
var bonjourSocket = Titanium.Socket.createTCP({
	hostName:Titanium.Socket.INADDR_ANY,
	port:40401,
	mode:Titanium.Socket.READ_WRITE_MODE
});
bonjourSocket.listen();

bonjourSocket.addEventListener('newData', function(e) {
	while (bonjourSocket.dataAvailable()) {
		var data = bonjourSocket.read();
		var dataStr = data.toString();
		if (dataStr.substr(dataStr.length-3) == 'req') {
			bonjourSocket.write('Hello, from '+Titanium.Platform.id);
		}
		else {
			Titanium.UI.createAlertDialog({
				title:'Bonjour message!',
				message:data.toString()
			}).show();
		}
	}
});

var localService = Titanium.Bonjour.createService({
	service:{name:'Bonjour Test: '+Titanium.Platform.id,
			type:'_utest._tcp',
			domain:'local.',
			socket:bonjourSocket}
});

// TODO: How do we unpublish a service?  Just close its socket and then it's no
// longer available elsewhere, and they're in charge of this?
try {
	localService.publish();
}
catch (e) {
	Titanium.UI.createAlertDialog({
		title:'Error!',
		message:e
	}).show();
}

// Searcher for finding other services
var serviceBrowser = Titanium.Bonjour.createBrowser({
	serviceType:'_utest._tcp',
	domain:'local.'
});

var searchButton = Titanium.UI.createButton({
	title:'Search...',
	top:10,
	height:50,
	width:200
});

searchButton.addEventListener('click', function(e) {
	if (!serviceBrowser.isSearching()) {
		serviceBrowser.purgeServices();
		try {
			serviceBrowser.search();
			searchButton.title = 'Cancel search...';
		}
		catch (ex) {
			Titanium.UI.createAlertDialog({
				title:'Error!',
				message:ex
			}).show();
		}
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
	var service = r['rowData'].service;
	if (service.socket == null) {
		try {
			service.resolve();
			service.socket.addEventListener('newData', function(x) {
				var data = x['source'].read();
				Titanium.UI.createAlertDialog({
					title:'Bonjour message!',
					message:data.toString()
				}).show();
			});
			service.socket.connect();
			service.socket.write('req');
		}
		catch (ex) {
			Titanium.UI.createAlertDialog({
				title:'Error!',
				message:ex
			}).show();
		}
	}
	else {
		if (!service.socket.isValid()) {
			service.socket.connect();
		}
		service.socket.write('req');
	}
});

updateUI = function(e) {
	var data = [];
	var services = e['source'].services;
	
	for (var i=0; i < services.length; i++) {
		var row = Titanium.UI.createTableViewRow({
			title:services[i].name,
			service:services[i]
		});
		
		data.push(row);
	}
	if (data.length == 0) {
		data.push(Titanium.UI.createTableViewRow({
			title:'No services'
		}));
	}
	
	tableView.setData(data);
}

serviceBrowser.addEventListener('updatedServices', updateUI);

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