int g_MuteTime[MAXPLAYERS+1] = {0};
int g_MuteTarget[MAXPLAYERS+1] = {0};
int g_MuteTargetUserId[MAXPLAYERS+1] = {0};


public AdminMenu_Mute(Handle:topmenu,
							  TopMenuAction:action,
							  TopMenuObject:object_id,
							  param,
							  String:buffer[],
							  maxlength){
	if (action == TopMenuAction_DisplayOption){
		Format(buffer, maxlength, "Zmutuj gracza");
	} else if (action == TopMenuAction_SelectOption) {
		DisplayMuteTargetMenu(param);
	}
}

DisplayMuteTargetMenu(client){
	Menu menu = CreateMenu(MenuHandler_MutePlayerList);

	decl String:title[100];
	Format(title, sizeof(title), "Zmutuj gracza");
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

	menu.Display(client, MENU_TIME_FOREVER);
}

DisplayMuteTimeMenu(client){
	Menu menu = CreateMenu(MenuHandler_MuteTimeList);

	decl String:title[100];
	Format(title, sizeof(title), "Mutowanie gracza %N", g_MuteTarget[client]);
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

DisplayMuteReasonMenu(client){
	Menu menu = CreateMenu(MenuHandler_MuteReasonList);

	decl String:title[100];
	Format(title, sizeof(title), "Mutowanie gracza %N", g_MuteTarget[client]);
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



public MenuHandler_MuteReasonList(Menu menu, MenuAction action, int iClient, int param2) {
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
		if(GetClientAuthId(g_MuteTarget[iClient], AuthId_Steam2, STRING(szAuthID))){
			BlockClient(iClient, g_MuteTarget[iClient], szAuthID, "mute", g_MuteTime[iClient], szInfo);
		}
		
	}
}

public MenuHandler_MutePlayerList(Menu menu, MenuAction action, int param1, int param2) {
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
			g_MuteTarget[param1] = target;
			g_MuteTargetUserId[param1] = userid;
			DisplayMuteTimeMenu(param1);
		}
	}
}

public MenuHandler_MuteTimeList(Menu menu, MenuAction action, int param1, int param2){
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Cancel) {
		if (param2 == MenuCancel_ExitBack && hTopMenu) {
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	} else if (action == MenuAction_Select) {
		decl String:info[32];

		menu.GetItem(param2, info, sizeof(info));
		g_MuteTime[param1] = StringToInt(info);

		DisplayMuteReasonMenu(param1);
	}
}
