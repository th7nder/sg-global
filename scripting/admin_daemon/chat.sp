public Action OnChatMessage(int &iClient, Handle hRecipients, char[] szName, char[] szMessage){
	/*int iClientTeam = GetClientTeam(iClient);
	if(iClientTeam <= 1){
		for(int i = 1; i <= MaxClients; i++){
			if(IsClientInGame(i) && i != iClient && IsPlayerAlive(i) && GetClientTeam(i) > 1 && FindValueInArray(hRecipients, i) == -1){
				PushArrayCell(hRecipients, i);
			}
		}
	}*/ 
	PurgePlayerChat(szMessage);
	if(strlen(g_szPrefix[iClient]) > 1){
	  	Format(szName, 128, "  %s%s%s", g_szNickPrefix[iClient], g_szPrefix[iClient], szName);
	  	Format(szMessage, (MAXLENGTH_MESSAGE - strlen(szName) - 5), "%s%s", g_szChatColor[iClient], szMessage);
	} else {
		Format(szName, 128, "  %s\x03%s", g_szNickPrefix[iClient], szName);
	}

	return Plugin_Changed;
}

char szCodes[][] = {
  "\x01",
  "\x02",
  "\x03",
  "\x04",
  "\x05",
  "\x06",
  "\x07",
  "\x08",
  "\x09",
  "\x10",
  "\x0E",
  "\x0A",
  "\x0B",
  "\x0C",
  "\x0F",
};

stock PurgePlayerChat(char[] szMessage)
{
	int iSize = sizeof(szCodes);
	for(int i = 0; i < iSize; i++)
	{
		ReplaceString(szMessage, 128, szCodes[i], "", false);
	}
}

Handle g_hColorsArray = INVALID_HANDLE;

stock CReplace(char[] sText, int maxlength)
{
	char sColor[64], sBuffer[16];
	int iStart = StrContains(sText, "{");
	while(iStart != -1)
	{
		int iEnd = StrContains(sText[iStart + 1], "}");
		if(iEnd != -1)
		{
			strcopy(sColor, iEnd + 1, sText[iStart + 1]);
			Format(sColor, sizeof(sColor), "{%s}", sColor);

			if(GetTrieString(g_hColorsArray, sColor, sBuffer, sizeof(sBuffer))) ReplaceString(sText, maxlength, sColor, sBuffer);
		}

		int iStart2 = StrContains(sText[iStart + 1], "{") + iStart + 1;
		if (iStart == iStart2) break;
		else iStart = iStart2;
	}
}



stock void Chat_OnPluginStart(){
  g_hColorsArray = CreateTrie();
  SetTrieString(g_hColorsArray, "{DEFAULT}", "\x01");
  SetTrieString(g_hColorsArray, "{RED}", "\x02");
  SetTrieString(g_hColorsArray, "{TEAM}", "\x03");
  SetTrieString(g_hColorsArray, "{GREEN}", "\x04");
  SetTrieString(g_hColorsArray, "{LIME}", "\x05");
  SetTrieString(g_hColorsArray, "{LIGHTGREEN}", "\x06");
  SetTrieString(g_hColorsArray, "{LIGHTRED}", "\x07");
  SetTrieString(g_hColorsArray, "{GRAY}", "\x08");
  SetTrieString(g_hColorsArray, "{LIGHTOLIVE}", "\x09");
  SetTrieString(g_hColorsArray, "{OLIVE}", "\x10");
  SetTrieString(g_hColorsArray, "{PURPLE}", "\x0E");
  SetTrieString(g_hColorsArray, "{LIGHTGRAY}", "\x0A");
  SetTrieString(g_hColorsArray, "{LIGHTBLUE}", "\x0B");
  SetTrieString(g_hColorsArray, "{BLUE}", "\x0C");
  SetTrieString(g_hColorsArray, "{PINK}", "\x0F");
}

stock void Chat_OnPluginEnd(){
  delete g_hColorsArray;
}
