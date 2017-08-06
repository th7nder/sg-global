int g_GagTime[MAXPLAYERS+1] = {0};
int g_GagTarget[MAXPLAYERS+1] = {0};
int g_GagTargetUserId[MAXPLAYERS+1] = {0};


public AdminMenu_Gag(Handle:topmenu,
							  TopMenuAction:action,
							  TopMenuObject:object_id,
							  param,
							  String:buffer[],
							  maxlength){
	if (action == TopMenuAction_DisplayOption){
		Format(buffer, maxlength, "Zgagguj gracza");
	} else if (action == TopMenuAction_SelectOption) {
		DisplayGagTargetMenu(param);
	}
}

DisplayGagTargetMenu(client){
	Menu menu = CreateMenu(MenuHandler_GagPlayerList);

	decl String:title[100];
	Format(title, sizeof(title), "Zgagguj gracza");
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

	menu.Display(client, MENU_TIME_FOREVER);
}

DisplayGagTimeMenu(client){
	Menu menu = CreateMenu(MenuHandler_GagTimeList);

	decl String:title[100];
	Format(title, sizeof(title), "Gaggowanie gracza %N", g_GagTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	menu.AddItem("0", "Permanent");
	menu.AddItem("5", "5 Minutes");
	menu.AddItem("10", "10 Minutes");
	menu.AddItem("30", "30 Minutes");
	menu.AddItem("60", "1 Hour");
	menu.AddItem("120", "2 Hours");
	menu.AddItem("240", "4 Hours");
	menu.AddItem("1440", "1 Day");
	menu.AddItem("10080", "1 Week");

	menu.Display(client, MENU_TIME_FOREVER);
}

DisplayGagReasonMenu(client){
	Menu menu = CreateMenu(MenuHandler_GagReasonList);

	decl String:title[100];
	Format(title, sizeof(title), "Gaggowanie gracza %N", g_GagTarget[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	char szReasonFull[128];
	int iSize = GetArraySize(g_hReasons);
	for(int i = 0; i < iSize; i++){
		GetArrayString(g_hReasons, i, STRING(szReasonFull));
		menu.AddItem(szReasonFull, szReasonFull);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}



public MenuHandler_GagReasonList(Menu menu, MenuAction action, int iClient, int param2) {
	if (action == MenuAction_End){
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && hTopMenu) {
			hTopMenu.Display(iClient, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		char szInfo[128];
		menu.GetItem(param2, STRING(szInfo));
		
		char szAuthID[64];
		if(GetClientAuthId(g_GagTarget[iClient], AuthId_Steam2, STRING(szAuthID))){
			BlockClient(iClient, g_GagTarget[iClient], szAuthID, "gag", g_GagTime[iClient], szInfo);
		}
		
	}
}

public MenuHandler_GagPlayerList(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && hTopMenu) {
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		decl String:info[32], String:name[32];
		new userid, target;

		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0){
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target)) {
			PrintToChat(param1, "[SM] %t", "Unable to target");
		} else {
			g_GagTarget[param1] = target;
			g_GagTargetUserId[param1] = userid;
			DisplayGagTimeMenu(param1);
		}
	}
}

public MenuHandler_GagTimeList(Menu menu, MenuAction action, int param1, int param2){
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && hTopMenu) {
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		decl String:info[32];

		menu.GetItem(param2, info, sizeof(info));
		g_GagTime[param1] = StringToInt(info);

		DisplayGagReasonMenu(param1);
	}
}
