#define MUTE_USAGE "Użycie: sm_mute <steamid|#userid|nick> <minuty|0> [powód]"
#define GAG_USAGE "Użycie: sm_gag <steamid|#userid|nick> <minuty|0> [powód]"
#define UNMUTE_USAGE "Użycie: sm_unmute <steamid|#userid|nick>"
#define UNGAG_USAGE "Użycie: sm_ungag <steamid|#userid|nick>"

public int FindPlayerByAuthID(const char[] szTarget){
	char szTempAuth[64];
	for(int i = 1; i <= MaxClients; i++){
		if(IsClientInGame(i) && GetClientAuthId(i, AuthId_Steam2, STRING(szTempAuth)) && StrEqual(szTarget, szTempAuth)){
			return i;
		}
	}
	return -1;
}

public Action CommandCallback(int iClient, const char[] szCommand, int iArgs){
	if(CheckCommandAccess(iClient, "th7_mutes", ADMFLAG_GENERIC, true) && (StrEqual(szCommand, "sm_gag") || StrEqual(szCommand, "sm_mute") || StrEqual(szCommand, "sm_ungag") || StrEqual(szCommand, "sm_unmute"))){
		char szReply[128];
		bool bDelete = false;
		if(StrEqual(szCommand, "sm_gag")){
			Format(STRING(szReply), GAG_USAGE);
		} else if(StrEqual(szCommand, "sm_mute")){
			Format(STRING(szReply), MUTE_USAGE);
		} else if(StrEqual(szCommand, "sm_ungag")){
			Format(STRING(szReply), UNGAG_USAGE);
			bDelete = true;
		} else if(StrEqual(szCommand, "sm_unmute")){
			Format(STRING(szReply), UNMUTE_USAGE);
			bDelete = true;
		}

		if(iArgs < 2 && !bDelete){
			ReplyToCommand(iClient, szReply);
			return Plugin_Stop;
		} else if(bDelete && iArgs < 1){
			ReplyToCommand(iClient, szReply);
			return Plugin_Stop;
		}

		char szTarget[128], szAuthID[64];
		int iTarget = -1;
		GetCmdArg(1, STRING(szTarget));
		if(StrContains(szTarget, "STEAM_") == -1){
			iTarget = FindTarget(iClient, szTarget, true);
			if(iTarget == -1){
				return Plugin_Stop;
			} else {
				GetClientAuthId(iTarget, AuthId_Steam2, STRING(szAuthID));
			}
		} else {
			Format(STRING(szAuthID), szTarget);
			ReplaceString(szAuthID, 64, "STEAM_0", "STEAM_1");
			iTarget = FindPlayerByAuthID(szTarget);
		}

		
		int iTime = -1;
		char szReason[128];
		if(!bDelete){
			char szBuffer[64];
			GetCmdArg(2, STRING(szBuffer));
			iTime = StringToInt(szBuffer);
			if(iTime < 0){
				ReplyToCommand(iClient, szReply);
				return Plugin_Stop;
			}

			
			if(iArgs >= 3){
				for(int i = 3; i <= iArgs; i++){
					GetCmdArg(i, STRING(szBuffer));
					Format(STRING(szReason), "%s %s", szReason, szBuffer);
				}
			}
		}
		


		char szEscaped[256];
		SQL_EscapeString(g_hDatabase, szAuthID, STRING(szEscaped));

		char szType[32];
		if(StrEqual(szCommand, "sm_gag")){
			Format(STRING(szType), "gag");
		} else if(StrEqual(szCommand, "sm_mute")){
			Format(STRING(szType), "mute");
		}

		if(!bDelete){
			if(!BlockClient(iClient, iTarget, szEscaped, szType, iTime, szReason)){
				ReplyToCommand(iClient, szReply);
			}
		} else {
			if(StrEqual(szCommand, "sm_unmute")){
				Unmute(iTarget);
			} else if(StrEqual(szCommand, "sm_ungag")){
				Ungag(iTarget);
			}
		}
		

	}

	return Plugin_Stop;
}