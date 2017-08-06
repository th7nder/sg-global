public Callback_FetchGlobalClients(Handle hOwner, Handle hResult, const char[] szError, int iClient){
	iClient = GetClientFromSerial(iClient);
	if(iClient == 0 || !IsClientConnected(iClient)){
		return;
	}
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;

	}

	if(strlen(szError) > 2){
		LogMessage(szError);
		return;
	}

	////PrintToServer( "GlobalClients g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])

	int iID;
	char szAuthID[64], szFlags[64];
	if(SQL_FetchRow(hResult)){
		iID = SQL_FetchInt(hResult, 0);
		SQL_FetchString(hResult, 1, STRING(szAuthID));
		SQL_FetchString(hResult, 2, STRING(szFlags));


		AssignAdmin(szAuthID, szFlags, -1, iClient);
		//PrintToServer( "GlobalClientsRow g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
		if(g_iServerID != -1){
			char szQuery[256];
			//PrintToServer( "GlobalClientsServerId g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
			Format(STRING(szQuery), "SELECT flags FROM ad_clients_specific WHERE server=%d AND client_id=%d", g_iServerID, iID);
			Handle hPack = CreateDataPack();
			WritePackString(hPack, szAuthID);
			WritePackCell(hPack, GetClientSerial(iClient));
			g_iLoadingStatus[iClient]++;

			//PrintToServer( "GlobalClientsSpecifiRow g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
			SQL_TQuery(g_hDatabase, Callback_FetchSpecificClient, szQuery, hPack)
		}
	}



	g_iLoadingStatus[iClient]--;
	//PrintToServer( "GlobalClientsAfter g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])

	delete hResult;
}


public Callback_FetchSpecificClient(Handle hOwner, Handle hResult, const char[] szError, Handle hPack){
	char szAuthID[64];
	ResetPack(hPack);
	ReadPackString(hPack, STRING(szAuthID));
	int iClient = GetClientFromSerial(ReadPackCell(hPack));
	if(iClient == 0 || !IsClientConnected(iClient)){
		return;
	}

	delete hPack;
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	}

	if(strlen(szError) > 2){
		LogMessage(szError);
		return;
	}

	if(SQL_FetchRow(hResult)){
		char szFlags[64];
		SQL_FetchString(hResult, 0, STRING(szFlags));
		AssignAdmin(szAuthID, szFlags, -1, iClient);
	}


	g_iLoadingStatus[iClient]--;

	//PrintToServer( "Clients: g_iLoadingStatus[iClient] = %d", g_iLoadingStatus[iClient]);
	if(IsClientInGame(iClient)){
		RunAdminCacheChecks(iClient);
		NotifyPostAdminCheck(iClient);
	}

	if(strlen(g_szPrefix[iClient]) < 3){
		if(!g_bCustomFlagsInUse){
			if(Player_IsSuperVIP(iClient)){
				Format(g_szPrefix[iClient], 64, SUPERVIP_PREFIX);
				Format(g_szChatColor[iClient], 64, SUPERVIP_COLOR);
			} else if(Player_IsVIP(iClient)){
				Format(g_szPrefix[iClient], 64, VIP_PREFIX);
				Format(g_szChatColor[iClient], 64, VIP_COLOR);
			}
		} else {
			if(Player_IsVIP(iClient)){
				Format(g_szPrefix[iClient], 64, VIP_PREFIX);
				Format(g_szChatColor[iClient], 64, VIP_COLOR);
			}
		}

		if(strlen(g_szPrefix[iClient]) > 3){
			CReplace(g_szPrefix[iClient], 64);
			CReplace(g_szChatColor[iClient], 64);
		}
	}






	delete hResult;
}

stock bool Player_IsAdmin(int iClient){
	if (CheckCommandAccess(iClient, "global_admin", ADMFLAG_GENERIC, false)) {
	  return true;
	} else {
	  return false;
	}
}

stock bool Player_IsVIP(int iClient){
  if (CheckCommandAccess(iClient, "global_vip", ADMFLAG_CUSTOM1, false)) {
    return true;
  } else {
    return false;
  }
}


stock bool Player_IsSuperVIP(int iClient){
  if (CheckCommandAccess(iClient, "global_supervip", ADMFLAG_CUSTOM2, false)) {
    return true;
  } else {
    return false;
  }
}
