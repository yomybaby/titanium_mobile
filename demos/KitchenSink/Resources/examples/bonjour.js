// Publish a local service on startup
var reqCount = 0;
var recvCount = 0;

var bonjourSocket = Titanium.Socket.createTCP({
	hostName:Titanium.Socket.INADDR_ANY,
	port:40401,
	mode:Titanium.Socket.READ_WRITE_MODE
});

bonjourSocket.addEventListener('newData', function(e) {
	while (bonjourSocket.dataAvailable()) {
		var data = bonjourSocket.read();
		var dataStr = data.toString();
		if (dataStr.substr(dataStr.length-3) == 'req') {
			bonjourSocket.write('Hello, from '+Titanium.Platform.id);
		}
		else {
			Titanium.UI.createAlertDialog({
				title:'Unknown listener message...',
				message:data.toString()
			}).show();
			// WARNING: There's some weird issue here where data events may or may
			// not interact with UI update events (including logging) and this
			// may result in some very ugly undefined behavior... that hasn't been
			// detected before because only UI elements have fired events in the
			// past.
			// Unfortunately, Bonjour is completely asynchronous and requires event
			// firing: Sockets require it as well to reliably deliver information
			// about when new data is available.
			// In particular if UI elements are updated 'out of order' with socket
			// data (especially modal elements, like dialogs, from inside the callback)
			// there may be some very bad results.  Like... crashes.
			Titanium.API.info('Unknown listener message: '+data.toString());
		}
	}
});
bonjourSocket.listen();

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
	reqCount++;
	Titanium.API.info('Req: '+reqCount);
	service.socket.write('req');
});

updateUI = function(e) {
	var data = [];
	var services = e['source'].services;
	
	for (var i=0; i < services.length; i++) {
		var service = services[i];
		var row = Titanium.UI.createTableViewRow({
			title:service.name,
			service:service
		});
		
		service.resolve();
		service.socket.addEventListener('newData', function(x) {
			var sock = x['source'];
			while (sock.dataAvailable()) {
				recvCount++;
				Titanium.API.info('Recv: '+recvCount);
				var data = sock.read();
				Titanium.UI.createAlertDialog({
					title:'Bonjour message!',
					message:data.toString()
				}).show();
			}
		});
		service.socket.connect();
		
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