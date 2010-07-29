Ti.API.info("hello from a background service");


Ti.App.scheduleLocalNotification({
	alertBody:"Do you want to launch it?",
	alertAction:"Launch!",
	userInfo:{"hello":"world"},
	sound:"pop.caf",
	date:new Date(new Date().getTime() + 3000) // 3 seconds after backgrounding
});


//FIXME - should be Ti.App
Ti.UI.currentService.addEventListener('stop',function()
{
	Ti.API.info("background service is stopped");
});

Ti.UI.currentService.stop();
