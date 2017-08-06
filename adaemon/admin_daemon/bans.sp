#define BAN_USAGE "Użycie: sm_ban <steamid|#userid|nick> <minuty|0> [powód]"
#define UNBAN_USAGE "Uzycie: sm_unban <steamid>"
#define KICK_USAGE "Użycie: sm_th7kick <steamid|#userid|nick> [powód]"

public void OnClientAuthorized(int iClient, const char[] szSteamID){
	if(IsFakeClient(iClient))
		return;

	ClearUngagTimer(iClient);
	ClearUnmuteTimer(iClient);

	Format(g_szPrefix[iClient], 64, "x");
	Format(g_szChatColor[iClient], 64, "x");
	char szAuthID[64];
	Format(STRING(szAuthID), szSteamID);
	ReplaceString(szAuthID, 64, "STEAM_0", "STEAM_1");

	Format(g_szAuthID[iClient], 64, szAuthID);

	char szQuery[256];
	Format(STRING(szQuery), "SELECT end,duration,blockade_type FROM ad_blockades WHERE removed=0 AND blockade_type='ban' AND authid='%s' AND (end > UNIX_TIMESTAMP() OR duration=0) ORDER BY id DESC LIMIT 1", szAuthID);
	SQL_TQuery(g_hDatabase, Callback_CheckIfBanned, szQuery, GetClientSerial(iClient));


	Format(STRING(szQuery), "SELECT admin_id, authid, flags, immunity, chat_prefix, chat_color FROM ad_admins WHERE authid='%s'", szAuthID);
	g_iLoadingStatus[iClient] = 1;

	SetUserAdmin(iClient, INVALID_ADMIN_ID);
	//PrintToServer( "OnClientAuthorized, starting to fetch: g_iLoadingStatus[iClient] = %d", g_iLoadingStatus[iClient]);
	SQL_TQuery(g_hDatabase, Callback_FetchGlobalAdmins, szQuery, GetClientSerial(iClient));




	/*szQuery[256];
	Format(STRING(szQuery), "SELECT end,duration FROM ad_blockades WHERE removed=0 AND authid='%s' AND blockade_type='mute' AND (end > UNIX_TIMESTAMP() OR duration=0) ORDER BY id DESC LIMIT 1", szAuthID);
	SQL_TQuery(g_hDatabase, Callback_CheckIfMuted, szQuery, GetClientSerial(iClient));*/

}

public void CreateUnmuteTimer(int iClient, float fTime){
	ClearUnmuteTimer(iClient);
	g_hUnmuteTimers[iClient] = CreateTimer(fTime, Timer_Unmute, GetClientSerial(iClient));
}

public void CreateUngagTimer(int iClient, float fTime){
	ClearUngagTimer(iClient);
	g_hUngagTimers[iClient] = CreateTimer(fTime, Timer_Ungag, GetClientSerial(iClient));
}

public Action Timer_Unmute(Handle hTimer, int iSerial){
	int iClient = GetClientFromSerial(iSerial);
	if(IsValidPlayer(iClient)){
		Unmute(iClient);
		g_hUnmuteTimers[iClient] = null;
	}
}

public void Unmute(int iClient){
	BaseComm_SetClientMute(iClient, false);
	char szAuthID[64];
	GetClientAuthId(iClient, AuthId_Steam2, STRING(szAuthID));
	UnblockClient(0, "mute", szAuthID);
	PrintToChatAll("%s %N został odmutowany!", CHAT_PREFIX, iClient);
}

public Action Timer_Ungag(Handle hTimer, int iSerial){
	int iClient = GetClientFromSerial(iSerial);
	if(IsValidPlayer(iClient)){
		Ungag(iClient);
		g_hUngagTimers[iClient] = null;
	}
}

public void Ungag(int iClient){
	BaseComm_SetClientGag(iClient, false);
	char szAuthID[64];
	GetClientAuthId(iClient, AuthId_Steam2, STRING(szAuthID));
	UnblockClient(0, "gag", szAuthID);
	PrintToChatAll("%s %N został odgaggowany!", CHAT_PREFIX, iClient);
}



public Callback_CheckIfBanned(Handle hOwner, Handle hResult, const char[] szError, int iClient){
	iClient = GetClientFromSerial(iClient);
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	}


	if(iClient < 1 || !IsClientConnected(iClient)){
		delete hResult;
		return;
	}



	if(SQL_FetchRow(hResult)){
		char szBlockadeType[32];
		int iEnds = SQL_FetchInt(hResult, 0);
		int iDuration = SQL_FetchInt(hResult, 1);
		SQL_FetchString(hResult, 2, STRING(szBlockadeType));
		if(iDuration == 0 && StrEqual(szBlockadeType, "ban")){
			KickClient(iClient, "Zostałeś zbanowany permanentnie na całej sieci. http://serwery-go.pl");
		} else if(iDuration >= 0){
			int iCurrentTime = GetTime();
			int iLeft = ((iEnds - iCurrentTime) / 60);

			if(StrEqual(szBlockadeType, "ban")){
				KickClient(iClient, "Zostałeś zbanowany na %d minut. Zostało %d min bana. http://serwery-go.pl", iDuration, iLeft);
			} else if(StrEqual(szBlockadeType, "mute")) {
				BaseComm_SetClientMute(iClient, true);
				if(iLeft > 0 && iLeft < 15){
					CreateUnmuteTimer(iClient, float(iLeft * 60));
				}

			} else if(StrEqual(szBlockadeType, "gag")) {
				BaseComm_SetClientGag(iClient, true);
				if(iLeft > 0 && iLeft < 15){
					CreateUngagTimer(iClient, float(iLeft * 60));
				}
			}
			
		}


	}

	char szAuthID[64];
	GetClientAuthId(iClient, AuthId_Steam2, STRING(szAuthID));
	char szQuery[256];
	Format(STRING(szQuery), "UPDATE ad_blockades SET removed=1 WHERE (UNIX_TIMESTAMP() > end) AND duration > 0", szAuthID);
	SQL_TQuery(g_hDatabase, Callback_Empty, szQuery);
	delete hResult;
}




public Action Command_BanClient(int iClient, int iArgs){
	if(iClient > 0 && !IsClientInGame(iClient))
		return Plugin_Handled;


	if(iArgs < 2){
		ReplyToCommand(iClient, BAN_USAGE);
		return Plugin_Handled;
	}

	char szTarget[128], szAuthID[64];
	int iTarget = -1;
	GetCmdArg(1, STRING(szTarget));
	if(StrContains(szTarget, "STEAM_") == -1){
		iTarget = FindTarget(iClient, szTarget, true);
		if(iTarget == -1){
			return Plugin_Handled;
		} else {
			GetClientAuthId(iTarget, AuthId_Steam2, STRING(szAuthID));
		}
	} else {
		Format(STRING(szAuthID), szTarget);
		ReplaceString(szAuthID, 64, "STEAM_0", "STEAM_1");

		char szTempAuth[64];
		for(int i = 1; i <= MaxClients; i++){
			if(i != iClient && IsClientInGame(i) && GetClientAuthId(i, AuthId_Steam2, STRING(szTempAuth)) && StrEqual(szTarget, szTempAuth)){
				iTarget = i;
				break;
			}
		}
	}

	

	char szBuffer[64];
	GetCmdArg(2, STRING(szBuffer));
	int iTime = StringToInt(szBuffer);
	if(iTime < 0){
		ReplyToCommand(iClient, BAN_USAGE);
		return Plugin_Handled;
	}

	char szReason[128];
	if(iArgs >= 3){
		for(int i = 3; i <= iArgs; i++){
			GetCmdArg(i, STRING(szBuffer));
			Format(STRING(szReason), "%s %s", szReason, szBuffer);
		}
	}


	char szEscaped[256];
	SQL_EscapeString(g_hDatabase, szAuthID, STRING(szEscaped));

	if(!BlockClient(iClient, iTarget, szEscaped, "ban", iTime, szReason)){
		ReplyToCommand(iClient, BAN_USAGE);
	}
	return Plugin_Handled;
}

public Action Command_KickClient(int iClient, int iArgs){
	if(iClient > 0 && !IsClientInGame(iClient))
		return Plugin_Handled;


	if(iArgs < 1){
		ReplyToCommand(iClient, KICK_USAGE);
		return Plugin_Handled;
	}

	char szTarget[128];
	int iTarget = -1;
	GetCmdArg(1, STRING(szTarget));
	if(StrContains(szTarget, "STEAM_") == -1){
		iTarget = FindTarget(iClient, szTarget, true);
		if(iTarget == -1){
			ReplyToCommand(iClient, KICK_USAGE);
			return Plugin_Handled;
		}
	} else {
		char szAuth[64];
		for(int i = 1; i <= MaxClients; i++){
			if(IsClientInGame(i) && GetClientAuthId(i, AuthId_Steam2, STRING(szAuth)) && StrEqual(szTarget, szAuth)){
				iTarget = i;
				break;
			}
		}
	}

	if(iTarget == -1){
		ReplyToCommand(iClient, KICK_USAGE);
		return Plugin_Handled;
	}

	char szBuffer[64];
	char szReason[128];
	if(iArgs >= 2){
		for(int i = 2; i <= iArgs; i++){
			GetCmdArg(i, STRING(szBuffer));
			Format(STRING(szReason), "%s %s", szReason, szBuffer);
		}
	}

	if(iArgs >= 2){
		KickClient(iTarget, "Zostałeś wyrzucony z powodem: %s http://serwery-go.pl", szReason);
	} else {
		KickClient(iTarget, "Zostałeś wyrzucony z serwera. http://serwery-go.pl");
	}

	return Plugin_Handled;
}


public Action Command_UnbanClient(int iClient, int iArgs){
	if(iClient > 0 && !IsClientInGame(iClient))
		return Plugin_Handled;


	if(iArgs < 1){
		ReplyToCommand(iClient, UNBAN_USAGE);
		return Plugin_Handled;
	}

	char szTarget[128];
	GetCmdArgString(STRING(szTarget));
	if(StrContains(szTarget, "STEAM_") == -1){
		ReplyToCommand(iClient, UNBAN_USAGE);
		return Plugin_Handled;
	}


	char szEscaped[256];
	SQL_EscapeString(g_hDatabase, szTarget, STRING(szEscaped));

	if(!UnblockClient(iClient, "ban", szEscaped)){
		ReplyToCommand(iClient, UNBAN_USAGE);
	}

	return Plugin_Handled;
}

stock bool BlockClient(int iAdmin, int iClient, char[] szAuthID, char[] szBlockadeType, int iTime=-1, char[] szReason=""){
	char szAdminName[MAX_NAME_LENGTH+1], szEscapedAdminName[MAX_NAME_LENGTH*2+1], szAdminIP[64], szAdminAuthID[64];
	if(iAdmin < 1 || iAdmin > MAXPLAYERS || !IsClientInGame(iAdmin)){
		Format(STRING(szEscapedAdminName), "Console");
		Format(STRING(szAdminIP), "Console");
		Format(STRING(szAdminAuthID), "Console");
	} else {
		GetClientName(iAdmin, STRING(szAdminName));
		SQL_EscapeString(g_hDatabase, szAdminName, STRING(szEscapedAdminName));
		GetClientIP(iAdmin, STRING(szAdminIP));
		GetClientAuthId(iAdmin, AuthId_Steam2, STRING(szAdminAuthID));
	}

	bool bKick = false;
	char szName[MAX_NAME_LENGTH+1], szEscapedName[MAX_NAME_LENGTH*2+1], szIP[64];
	if(iClient < 1 || iClient > MAXPLAYERS || !IsClientInGame(iClient)){
		Format(STRING(szEscapedName), "Not in game.");
		Format(STRING(szIP), "Not in game.");
	} else {
		AdminId iTargetAdminId = GetUserAdmin(iClient);
		if(iTargetAdminId != INVALID_ADMIN_ID){
			if(iAdmin != 0 && CheckCommandAccess(iAdmin, "th7_mutes", ADMFLAG_GENERIC, true) && CheckCommandAccess(iClient, "th7_mutes", ADMFLAG_GENERIC, true) && GetAdminImmunityLevel(GetUserAdmin(iAdmin)) < GetAdminImmunityLevel(iTargetAdminId)){
				return false;
			}
		}
		bKick = true;
		GetClientName(iClient, STRING(szName));
		SQL_EscapeString(g_hDatabase, szName, STRING(szEscapedName));
		GetClientIP(iClient, STRING(szIP));
	}

	if(szAuthID[7] != ':' || strlen(szAuthID) < 5 || iTime == -1){
		return false;
	}

	ReplaceString(szAuthID, 64, "STEAM_0", "STEAM_1");

	char szEscapedReason[256];
	SQL_EscapeString(g_hDatabase, szReason, STRING(szEscapedReason));

	char szQuery[1024];
	Format(STRING(szQuery), "INSERT INTO ad_blockades VALUES (NULL, '%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', '%s', '%s', '%s', %d, 0, '%s', '')", szEscapedName, szAuthID, szIP, iTime * 60, iTime, szEscapedReason, szEscapedAdminName, szAdminAuthID, szAdminIP, g_iServerID, szBlockadeType);
	SQL_TQuery(g_hDatabase, Callback_Empty, szQuery);


	if(StrEqual(szBlockadeType, "ban")){
		if(bKick){
			if(iTime > 0){
				if(strlen(szReason) > 2){
					KickClient(iClient, "Zostałeś zbanowany na %d minut z powodem: %s. http://serwery-go.pl", iTime, szReason);
					PrintToChatAll("%s Gracz %s został zbanowany na %d minut z powodem: %s.", CHAT_PREFIX, szName, iTime, szReason);
				} else {
					KickClient(iClient, "Zostałeś zbanowany na %d minut. http://serwery-go.pl", iTime);
					PrintToChatAll("%s Gracz %s został zbanowany na %d minut.", CHAT_PREFIX, szName, iTime);
				}
			} else {
				if(strlen(szReason) > 2){
					KickClient(iClient, "Zostałeś zbanowany na permanentnie z powodem: %s. http://serwery-go.pl", szReason);
					PrintToChatAll("%s Gracz %s został permanentnie zbanowany z powodem: %s", CHAT_PREFIX, szName, szReason);
				} else {
					KickClient(iClient, "Zostałeś zbanowany na permanentnie. http://serwery-go.pl");
					PrintToChatAll("%s Gracz %s został permanentnie zbanowany.", CHAT_PREFIX, szName);
				}

			}

		} else {
			if(strlen(szReason) > 2){
				PrintToChatAll("%s Pomyślnie zbanowano gracza o SteamID: %s na %d minut z powodem: %s", CHAT_PREFIX, szAuthID, iTime, szEscapedReason);
			} else {
				PrintToChatAll("%s Pomyślnie zbanowano gracza o SteamID: %s na %d minut.", CHAT_PREFIX, szAuthID, iTime);
			}
			
		}
	} else if(StrEqual(szBlockadeType, "mute")){
    	BaseComm_SetClientMute(iClient, true);
    	if(iTime > 0){
			if(iTime < 15){
				CreateUnmuteTimer(iClient, float(iTime * 60));
			}

			if(strlen(szReason) > 2){
				PrintToChatAll("%s Gracz %s został zmutowany na %d minut z powodem: %s.", CHAT_PREFIX, szName, iTime, szReason);
			} else {
				PrintToChatAll("%s Gracz %s został zmutowany na %d minut.", CHAT_PREFIX, szName, iTime);
			}
		} else {
			if(strlen(szReason) > 2){
				PrintToChatAll("%s Gracz %s został permanentnie zmutowany z powodem: %s", CHAT_PREFIX, szName, szReason);
			} else {
				PrintToChatAll("%s Gracz %s został permanentnie zmutowany.", CHAT_PREFIX, szName);
			}

		}
	} else if(StrEqual(szBlockadeType, "gag")){
    	BaseComm_SetClientGag(iClient, true);
    	if(iTime > 0){
			if(iTime < 15){
				CreateUngagTimer(iClient, float(iTime * 60));
			}

			if(strlen(szReason) > 2){
				PrintToChatAll("%s Gracz %s został zgaggowany na %d minut z powodem: %s.", CHAT_PREFIX, szName, iTime, szReason);
			} else {
				PrintToChatAll("%s Gracz %s został zgaggowany na %d minut.", CHAT_PREFIX, szName, iTime);
			}
		} else {
			if(strlen(szReason) > 2){
				PrintToChatAll("%s Gracz %s został permanentnie zgaggowany z powodem: %s", CHAT_PREFIX, szName, szReason);
			} else {
				PrintToChatAll("%s Gracz %s został permanentnie zgaggowany.", CHAT_PREFIX, szName);
			}

		}
	}

	return true;
}

public bool UnblockClient(int iAdmin, char[] szBlockadeType, char[] szAuthID){
	if(strlen(szAuthID) < 4){
		return false;
	}

	ReplaceString(szAuthID, 64, "STEAM_0", "STEAM_1");

	char szAdminAuthID[64];
	if(iAdmin > 0 && IsClientInGame(iAdmin)){
		GetClientAuthId(iAdmin, AuthId_Steam2, STRING(szAdminAuthID));
	} else {
		Format(STRING(szAdminAuthID), "Console");
	}

	char szQuery[256];
	Format(STRING(szQuery), "UPDATE ad_blockades SET removed=1,removed_by='%s' WHERE authid='%s' AND blockade_type='%s'", szAdminAuthID, szAuthID, szBlockadeType);
	if(iAdmin != 0)
		SQL_TQuery(g_hDatabase, Callback_Unblock, szQuery, GetClientSerial(iAdmin));
	else
		SQL_TQuery(g_hDatabase, Callback_Unblock, szQuery, 0);

	return true;
}

public Callback_Unblock(Handle hOwner, Handle hResult, const char[] szError, int iAdmin){
	if(strlen(szError) > 4){
		LogError("[Unban Error] %s", szError);
	}
	if(iAdmin != 0)
		iAdmin = GetClientFromSerial(iAdmin);
	if (hResult == INVALID_HANDLE) {
		ReplyToCommand(iAdmin, "%s Nie ma takiego gracza w bazie banów!", CHAT_PREFIX);
	} else {
		delete hResult;
	}

	if(iAdmin != 0){
		PrintToChat(iAdmin, "%s Pomyślnie odblokowano gracza.", CHAT_PREFIX);
	} else {
		ReplyToCommand(iAdmin, "%s Pomyślnie odblokowano gracza.", CHAT_PREFIX);
	}

}


public Callback_Empty(Handle hOwner, Handle hResult, const char[] szError, any aData){
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	} else {
		if(strlen(szError) > 5){
			LogError(szError);
		}
		delete hResult;
	}
}
