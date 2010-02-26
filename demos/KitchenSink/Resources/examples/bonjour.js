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

var tableView = null;
updateUI = function(e) {
	if (tableView == null) {
		tableView = Titanium.UI.createTableView({
			style:Titanium.UI.iPhone.TableViewStyle.GROUPED
		});
		
		tableView.addEventListener('click', function(r) {
			var service = r.rowData.service;
			if (service.socket == null) {
				var resolved = false;
				service.addEventListener('didNotResolve', function(err) {
					Titanium.UI.createAlertDialog({
						title:'Resolve failure!',
						message:e['error']
					}).show();
					resolved = true;
				});
				service.addEventListener('resolved', function(s) {
					resolved = true;
				});
				Titanium.Bonjour.resolve(service);
				while (!resolved) {
					setTimeout(function() {}, 1000);
				}
			}
			
			service.socket.write('req');
		});
		
		Titanium.UI.currentWindow.add(tableView);
	}
	
	var data = [];
	var services = e['services'];
	for (var i=0; i < services.length; i++) {
		var row = Titanium.UI.createTableRow({
			title:services[i].name,
			service:services[i]
		});
		data.push(row);
	}
	
	tableView.setData(data);
}

serviceBrowser.addEventListener('foundServices', updateUI);
serviceBrowser.addEventListener('removedServices', updateUI);

// TODO: Do we need to call 'search' multiple times, as more services
// join the network?
serviceBrowser.search();