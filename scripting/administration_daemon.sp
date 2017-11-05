#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>
#include <cstrike>
#include <adminmenu>
#include <scp>

#include <admindaemon>
#include <basecomm>
#include <regex>
public bool IsValidPlayer(int iClient){
	if(iClient > 0 && iClient < MAXPLAYERS + 1 && IsClientInGame(iClient) && IsClientAuthorized(iClient)){
		return true;
	}

	return false;
}

public Plugin:myinfo =
{
	name = "Administration Daemon",
	author = "th7nder",
	description = "Admins, Bans, Adverts, Clients",
	version = "1.001",
	url = "http://serwery-go.pl"
}



#define CHAT_PREFIX "  \x06[\x0BAdministration \x07Daemon\x06] "
#define CHAT_PREFIX_SG "  \x06[\x0BSerwery\x01-\x07GO\x06] "
#define STRING(%1) %1, 	sizeof(%1)

#define VIP_PREFIX "{GREEN}[VIP] {BLUE}"
#define VIP_COLOR "{GREEN}"

#define SUPERVIP_PREFIX "{GREEN}[SuperVIP] {PURPLE}"
#define SUPERVIP_COLOR "{GREEN}"

#define ADMIN_PREFIX "{BLUE}[ADMIN] {LIME}"
#define ADMIN_COLOR "{LIGHTBLUE}"

Handle g_hDatabase = INVALID_HANDLE;
AdminFlag g_iFlagLetters[26];

bool g_bCustomFlagsInUse = false;

int g_iServerID = -1;
char g_szIP[64];
int g_iHostPort;
bool g_bLateLoad = false;
Handle g_hReasons = INVALID_HANDLE;
TopMenu hTopMenu = null;

char g_szNickPrefix[MAXPLAYERS+1][64];
char g_szPrefix[MAXPLAYERS+1][64];
char g_szChatColor[MAXPLAYERS+1][64];

Handle g_hAdvertisements = INVALID_HANDLE;
Handle g_hAdvertsTimer = INVALID_HANDLE;

int g_iLoadingStatus[MAXPLAYERS+1] = {0};
char g_szAuthID[MAXPLAYERS+1][64];

Handle g_hUnmuteTimers[MAXPLAYERS+1] = {null};
Handle g_hUngagTimers[MAXPLAYERS+1] = {null};

#include "admin_daemon/bans.sp"
#include "admin_daemon/commands.sp"
#include "admin_daemon/adminmenu_bans.sp"
#include "admin_daemon/adminmenu_mutes.sp"
#include "admin_daemon/adminmenu_gags.sp"
#include "admin_daemon/clients.sp"
#include "admin_daemon/chat.sp"


bool g_bStartedDatabaseLoad[MAXPLAYERS+1]  = {false};


public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrorLength){
	g_bLateLoad = bLate;
	CreateNative("AdminDaemon_GetPrefix", Native_GetPrefix);
	CreateNative("AdminDaemon_SetNickPrefix", Native_SetNickPrefix);
	return APLRes_Success;
}

public int Native_GetPrefix(Handle hPlugin, int iNumParams){
	int iClient = GetNativeCell(1);
	int iMaxSize = GetNativeCell(3);
	if(strlen(g_szPrefix[iClient]) > 3){

		SetNativeString(1, g_szPrefix[iClient], iMaxSize, true);
		return 1;
	}

	return 0;
}

public int Native_SetNickPrefix(Handle hPlugin, int iNumParams){
	int iClient = GetNativeCell(1);
	GetNativeString(2, g_szNickPrefix[iClient], 64);
	return 0;
}

stock bool:File_Copy(const String:source[], const String:destination[])
{
	new Handle:file_source = OpenFile(source, "rb");

	if (file_source == INVALID_HANDLE) {
		return false;
	}

	new Handle:file_destination = OpenFile(destination, "wb");

	if (file_destination == INVALID_HANDLE) {
		CloseHandle(file_source);
		return false;
	}

	new buffer[32];
	new cache;

	while (!IsEndOfFile(file_source)) {
		cache = ReadFile(file_source, buffer, 32, 1);
		WriteFile(file_destination, buffer, cache, 1);
	}

	CloseHandle(file_source);
	CloseHandle(file_destination);

	return true;
}

public CreateNavFiles()
{
	decl String:DestFile[256];
	decl String:SourceFile[256];
	Format(SourceFile, sizeof(SourceFile), "maps/replay_bot.nav");
	if (!FileExists(SourceFile))
	{
		LogError("ADaemon Failed to create .nav files. Reason: %s doesn't exist!", SourceFile);
		return;
	}
	decl String:map[256];
	Handle mapList = CreateArray(64);
	new mapListSerial = -1;
	if (ReadMapList(mapList,	mapListSerial, "mapcyclefile", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT) == INVALID_HANDLE)
		if (mapListSerial == -1)
			return;
	for (new i = 0; i < GetArraySize(mapList); i++)
	{
		GetArrayString(mapList, i, map, sizeof(map));
		if (!StrEqual(map, "", false))
		{
			Format(DestFile, sizeof(DestFile), "maps/%s.nav", map);
			if (!FileExists(DestFile))
				File_Copy(SourceFile, DestFile);
		}
	}

	CloseHandle(mapList);
}

public void OnPluginStart(){
	//CreateNavFiles();
	g_iFlagLetters['a'-'a'] = Admin_Reservation;
	g_iFlagLetters['b'-'a'] = Admin_Generic;
	g_iFlagLetters['c'-'a'] = Admin_Kick;
	g_iFlagLetters['d'-'a'] = Admin_Ban;
	g_iFlagLetters['e'-'a'] = Admin_Unban;
	g_iFlagLetters['f'-'a'] = Admin_Slay;
	g_iFlagLetters['g'-'a'] = Admin_Changemap;
	g_iFlagLetters['h'-'a'] = Admin_Convars;
	g_iFlagLetters['i'-'a'] = Admin_Config;
	g_iFlagLetters['j'-'a'] = Admin_Chat;
	g_iFlagLetters['k'-'a'] = Admin_Vote;
	g_iFlagLetters['l'-'a'] = Admin_Password;
	g_iFlagLetters['m'-'a'] = Admin_RCON;
	g_iFlagLetters['n'-'a'] = Admin_Cheats;
	g_iFlagLetters['o'-'a'] = Admin_Custom1;
	g_iFlagLetters['p'-'a'] = Admin_Custom2;
	g_iFlagLetters['q'-'a'] = Admin_Custom3;
	g_iFlagLetters['r'-'a'] = Admin_Custom4;
	g_iFlagLetters['s'-'a'] = Admin_Custom5;
	g_iFlagLetters['t'-'a'] = Admin_Custom6;
	g_iFlagLetters['z'-'a'] = Admin_Root;

	RegServerCmd("sm_rehash", ServerCommand_Rehash);

	int m_unIP = GetConVarInt(FindConVar("hostip"));
	Format(STRING(g_szIP), "%d.%d.%d.%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF);
	g_iHostPort = GetConVarInt(FindConVar("hostport"));
	//g_iLoadingStatus = 0;
	SQL_TConnect(Callback_Connect, "administration_daemon");

	RegAdminCmd("sm_ban", Command_BanClient, ADMFLAG_GENERIC);
	RegAdminCmd("sm_unban", Command_UnbanClient, ADMFLAG_UNBAN);
	RegAdminCmd("sm_th7kick", Command_KickClient, ADMFLAG_GENERIC);

	AddCommandListener(CommandCallback, "sm_mute");
	AddCommandListener(CommandCallback, "sm_gag");
	AddCommandListener(CommandCallback, "sm_unmute");
	AddCommandListener(CommandCallback, "sm_ungag");

	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");
	LoadTranslations("core.phrases");

	if(g_hReasons == INVALID_HANDLE){
		g_hReasons = CreateArray(24);
		ClearArray(g_hReasons);
	}

	if(g_hAdvertisements == INVALID_HANDLE){
		g_hAdvertisements = CreateArray(24);
		ClearArray(g_hAdvertisements);
	}

	TopMenu iTopMenu;
	if (LibraryExists("adminmenu") && ((iTopMenu = GetAdminTopMenu()) != null)){
		OnAdminMenuReady(iTopMenu);
	}

	if(g_hAdvertsTimer == INVALID_HANDLE){
		CreateTimer(15.0, Timer_ShowAdverts, _, TIMER_REPEAT);
	}

	HookEvent("player_spawn", Event_Check);
	HookEvent("player_team", Event_Check);

	AddCommandListener(Command_Recheck, "jointeam");
	AddCommandListener(Command_Recheck, "joinclass");
	AddCommandListener(Command_Recheck, "spec_mode");
	AddCommandListener(Command_Recheck, "spec_next");
	AddCommandListener(Command_Recheck, "spec_player");
	AddCommandListener(Command_Recheck, "spec_prev");

	Chat_OnPluginStart();

}

public Action Command_Recheck(int iClient, char[] szCommand, int iArgs) 
{
	if(IsClientInGame(iClient) && !IsClientSourceTV(iClient))
	{
		SetTag(iClient);
	}


	return Plugin_Continue;
}
// .+?(?=Surf)
public Action Event_Check(Event hEvent, const char[] szBroadcast, bool bBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	SetTag(iClient);
}

public void OnClientSettingsChanged(int iClient)
{
	if(IsClientInGame(iClient))
	{
		SetTag(iClient);
	}
}

stock void SetTag(int iClient)
{
	char szTag[64];
	Format(szTag, sizeof(szTag), g_szPrefix[iClient]);
	PurgePlayerChat(szTag);
	if(strlen(szTag) > 3)
	{
		CS_SetClientClanTag(iClient, szTag);
	}
	else
	{
		CS_SetClientClanTag(iClient, "[Gracz]");
	}
}
public Action Timer_ShowAdverts(Handle hTimer){
	int iSize = GetArraySize(g_hAdvertisements);
	if(iSize){
		int iRandom = GetRandomInt(0, iSize - 1);
		char szAdvert[256];
		GetArrayString(g_hAdvertisements, iRandom, STRING(szAdvert));

		CReplace(szAdvert, 256);
		if(StrContains(szAdvert, "{CURRENT_MAP}", false) != -1)
		{
			char szMap[256];
			GetCurrentMap(szMap, 256);
			int iLastIndex = 0;
			for(int i = 255; i >= 0; i--)
			{
				if(szMap[i] == '/')
				{
					iLastIndex = i + 1;
					break;
				}
			}
			Format(szMap, 256, "%s", szMap[iLastIndex]);
			ReplaceString(szAdvert, 256, "{CURRENT_MAP}", szMap, false);
		}

		if(StrContains(szAdvert, "{TIMELEFT}", false) != -1)
		{
			int iTimeleft = 0;
			GetMapTimeLeft(iTimeleft);
			char szTimeleft[10];
			Format(szTimeleft, 10, "%02d:%02d", iTimeleft / 60, iTimeleft % 60);
			ReplaceString(szAdvert, 256, "{TIMELEFT}", szTimeleft);
		}

		PrintToChatAll("%s\x09 %s", CHAT_PREFIX_SG, szAdvert);
	}

	return Plugin_Continue;
}

public OnPluginEnd(){
	ClearArray(g_hReasons);
	ClearArray(g_hAdvertisements);
	delete g_hAdvertisements;
	delete g_hReasons;

	delete g_hDatabase;
	delete g_hAdvertsTimer;
}

public OnMapStart(){
	if(g_hDatabase != INVALID_HANDLE && g_iServerID != -1){
		char szQuery[128];

		//g_iLoadingStatus++;
		Format(STRING(szQuery), "SELECT reason,server FROM ad_banreasons WHERE server IN (0, %d) ORDER BY reason ASC", g_iServerID);
		SQL_TQuery(g_hDatabase, Callback_FetchReasons, szQuery);


		//g_iLoadingStatus++;
		Format(STRING(szQuery), "SELECT text FROM ad_advertisements WHERE server IN (0, %d) ORDER BY text ASC", g_iServerID); 
		SQL_TQuery(g_hDatabase, Callback_FetchAdverts, szQuery);
	}
}

public void OnClientPutInServer(int iClient){
	g_bStartedDatabaseLoad[iClient] = false;
	if(g_hDatabase != null)
	{
		g_bStartedDatabaseLoad[iClient] = true;
		Format(g_szNickPrefix[iClient], 64, "");
		char szAuthID[64];
		GetClientAuthId(iClient, AuthId_Steam2, STRING(szAuthID));
		char szQuery[256];
		Format(STRING(szQuery), "SELECT end,duration,blockade_type FROM ad_blockades WHERE removed=0 AND (blockade_type='mute' OR blockade_type='gag') AND authid='%s' AND (end > UNIX_TIMESTAMP() OR duration=0) ORDER BY id DESC LIMIT 1", szAuthID);
		SQL_TQuery(g_hDatabase, Callback_CheckIfBanned, szQuery, GetClientSerial(iClient));
	}
}

public Callback_FetchReasons(Handle hOwner, Handle hResult, const char[] szError, any aData){
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;

	}

	if(g_hReasons != INVALID_HANDLE){
		ClearArray(g_hReasons);
	}

	char szReason[128];
	while(SQL_FetchRow(hResult)){
		SQL_FetchString(hResult, 0, STRING(szReason));
		PushArrayString(g_hReasons, szReason);
	}

	//g_iLoadingStatus--;
	delete hResult;
}

public Callback_FetchAdverts(Handle hOwner, Handle hResult, const char[] szError, any aData){
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	}

	if(g_hAdvertisements != INVALID_HANDLE){
		ClearArray(g_hAdvertisements);
	}

	char szText[256];
	while(SQL_FetchRow(hResult)){
		SQL_FetchString(hResult, 0, STRING(szText));
		PushArrayString(g_hAdvertisements, szText);
	}

	//g_iLoadingStatus--;
	delete hResult;
}


public void ClearUnmuteTimer(int iClient){
	if(g_hUnmuteTimers[iClient] != null){
		delete g_hUnmuteTimers[iClient];
		g_hUnmuteTimers[iClient] = null;
	}
}

public void ClearUngagTimer(int iClient){
	if(g_hUngagTimers[iClient] != null){
		delete g_hUngagTimers[iClient];
		g_hUngagTimers[iClient] = null;
	}
}

public void OnClientDisconnect(int iClient){
	g_iLoadingStatus[iClient] = -1;

	ClearUngagTimer(iClient);
	ClearUnmuteTimer(iClient)
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu iTopMenu = TopMenu.FromHandle(aTopMenu);
	if (iTopMenu == hTopMenu)
		return;

	hTopMenu = iTopMenu;
	TopMenuObject iPlayerCommands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (iPlayerCommands != INVALID_TOPMENUOBJECT){
		hTopMenu.AddItem("sm_ban", AdminMenu_Ban, iPlayerCommands, "sm_ban", ADMFLAG_GENERIC);
		hTopMenu.AddItem("sm_mute", AdminMenu_Mute, iPlayerCommands, "sm_mute", ADMFLAG_GENERIC);
		hTopMenu.AddItem("sm_gag", AdminMenu_Gag, iPlayerCommands, "sm_gag", ADMFLAG_GENERIC);
	}
}




public Callback_Connect(Handle hOwner, Handle hResult, const char[] szError, any aData){
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: Connect Error %s", szError);
		return;
	}

	g_hDatabase = CloneHandle(hResult);
	SQL_SetCharset(g_hDatabase, "utf8mb4");
	StartFetching();
}

stock void StartFetching(){
	//g_iLoadingStatus = 0;



//	g_iLoadingStatus++;
	char szQuery[512];
	Format(STRING(szQuery), "SELECT server_id, custom_flags_in_use FROM ad_servers WHERE ip='%s' AND hostport=%d", g_szIP, g_iHostPort);
	SQL_TQuery(g_hDatabase, Callback_FetchServerID, szQuery);


//	g_iLoadingStatus++;

}

public Callback_FetchServerID(Handle hOwner, Handle hResult, const char[] szError, any aData){
  if (hResult == INVALID_HANDLE) {
  	LogError("ADaemon: DirectQuery ERROR, %s", szError);
  	return;

  }


  g_bCustomFlagsInUse = false;
  if(SQL_FetchRow(hResult)){
	g_iServerID = SQL_FetchInt(hResult, 0);
	g_bCustomFlagsInUse = view_as<bool>(SQL_FetchInt(hResult, 1));
	char szAuthID[64];
	for(int i = 1; i <= MaxClients; i++){
		if(IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i) && !g_bStartedDatabaseLoad[i] && GetClientAuthId(i, AuthId_Steam2, STRING(szAuthID))){
			OnClientAuthorized(i, szAuthID);
			OnClientPutInServer(i);
		}
	}
  	g_bLateLoad = false;


  	char szQuery[256];
  	Format(STRING(szQuery), "SELECT text FROM ad_advertisements WHERE server IN (0, %d) ORDER BY text ASC", g_iServerID);
	SQL_TQuery(g_hDatabase, Callback_FetchAdverts, szQuery);
  } else {
  	LogError("Server %s:%d is not present in ad_servers!", g_szIP, g_iHostPort);
  }

  delete hResult;
  char szQuery[128];
  Format(STRING(szQuery), "SELECT reason,server FROM ad_banreasons WHERE server IN (0, %d) ORDER BY reason ASC", g_iServerID);
  SQL_TQuery(g_hDatabase, Callback_FetchReasons, szQuery);

}
public Callback_FetchGlobalAdmins(Handle hOwner, Handle hResult, const char[] szError, int iClient){
	iClient = GetClientFromSerial(iClient);
	if(iClient == 0 || !IsClientConnected(iClient)){
		return;
	}
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	}


	int iID, iImmunity;
	char szAuthID[64], szFlags[64];
	GetClientAuthId(iClient, AuthId_Steam2, STRING(szAuthID));
	if(SQL_FetchRow(hResult)){
		iID = SQL_FetchInt(hResult, 0);
		SQL_FetchString(hResult, 1, STRING(szAuthID));
		SQL_FetchString(hResult, 2, STRING(szFlags));
		iImmunity = SQL_FetchInt(hResult, 3);
		SQL_FetchString(hResult, 4, g_szPrefix[iClient], 64);
		SQL_FetchString(hResult, 5, g_szChatColor[iClient], 64);
		CReplace(g_szPrefix[iClient], 64);
		CReplace(g_szChatColor[iClient], 64);
		//PrintToServer( "Fetchif Row")

		AssignAdmin(szAuthID, szFlags, iImmunity, iClient);

		if(g_iServerID != -1){
			//PrintToServer( "ServerID Fetching Row")
			char szQuery[256];
			Format(STRING(szQuery), "SELECT flags FROM ad_admins_specific WHERE server=%d AND admin_id=%d", g_iServerID, iID);
			Handle hPack = CreateDataPack();
			WritePackString(hPack, szAuthID);
			WritePackCell(hPack, GetClientSerial(iClient));
			WritePackCell(hPack, iImmunity);
			g_iLoadingStatus[iClient]++;
			//PrintToServer( "ServerID Fetching Row g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
			SQL_TQuery(g_hDatabase, Callback_FetchSpecificAdmin, szQuery, hPack)
		}
	} else {
		if(g_iServerID != -1){
			//PrintToServer( "ServerID Fetching Row")
			char szQuery[256];
			Format(STRING(szQuery), "SELECT flags FROM ad_admins_specific WHERE server=%d AND admin_id=-1", g_iServerID);
			Handle hPack = CreateDataPack();
			WritePackString(hPack, szAuthID);
			WritePackCell(hPack, GetClientSerial(iClient));
			WritePackCell(hPack, iImmunity);
			g_iLoadingStatus[iClient]++;
			//PrintToServer( "ServerID Fetching Row g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
			SQL_TQuery(g_hDatabase, Callback_FetchSpecificAdmin, szQuery, hPack)
		}
	}

	g_iLoadingStatus[iClient]--;
	//PrintToServer( "GlobalAdmins After g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])

	delete hResult;
}


public Callback_FetchSpecificAdmin(Handle hOwner, Handle hResult, const char[] szError, Handle hPack){
	char szAuthID[64];
	ResetPack(hPack);
	ReadPackString(hPack, STRING(szAuthID));
	int iClient = GetClientFromSerial(ReadPackCell(hPack));
	int iImmunity = ReadPackCell(hPack);
	if(iClient == 0 || !IsClientConnected(iClient)){
		return;
	}
	delete hPack;
	if (hResult == INVALID_HANDLE) {
		LogError("ADaemon: DirectQuery ERROR, %s", szError);
		return;
	}

	//PrintToServer( "SpecificAdmin g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
	if(SQL_FetchRow(hResult)){
		char szFlags[64];
		SQL_FetchString(hResult, 0, STRING(szFlags));
		AssignAdmin(szAuthID, szFlags, iImmunity, iClient);
		//PrintToServer( "SpecificAdmin FetchRowg_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
	}

	char szQuery[512];
	Format(STRING(szQuery), "SELECT client_id, authid, flags FROM ad_clients WHERE authid='%s'", szAuthID);
	g_iLoadingStatus[iClient]++;

	//PrintToServer( "SpecificAdmin GLobalClients g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])


	SQL_TQuery(g_hDatabase, Callback_FetchGlobalClients, szQuery, GetClientSerial(iClient));

	//if(IsClientInGame(iClient) && IsClientAuthorized(iClient)){
	//	RunAdminCacheChecks(iClient);
	//	NotifyPostAdminCheck(iClient);
	//}

	g_iLoadingStatus[iClient]--;


	//PrintToServer( "SpecificAdminAfter g_iLoadingStatus[iClient] %d", g_iLoadingStatus[iClient])
	delete hResult;

	if(strlen(g_szPrefix[iClient]) < 3 && Player_IsAdmin(iClient)){
		Format(g_szPrefix[iClient], 64, ADMIN_PREFIX);
		Format(g_szChatColor[iClient], 64, ADMIN_COLOR);
		CReplace(g_szPrefix[iClient], 64);
		CReplace(g_szChatColor[iClient], 64);
	}
}



stock bool AssignAdmin(char[] szAuthID, char[] szFlags, int iImmunity = -1, int iClient = -1){
	TrimString(szAuthID);
	TrimString(szFlags);
	int iLength = strlen(szFlags);
	if(iLength > 0){
		AdminId iAdminID = INVALID_ADMIN_ID;
		if((iAdminID = FindAdminByIdentity("steam", szAuthID)) == INVALID_ADMIN_ID){
			iAdminID = CreateAdmin(szAuthID);
			if(!BindAdminIdentity(iAdminID, "steam", szAuthID)){
				LogError("ADaemon: Unable to bind admin %s", szAuthID, szAuthID);
				RemoveAdmin(iAdminID);
				return false;
			}

			if(iClient != -1){
				SetUserAdmin(iClient, iAdminID, true);
			}
		}



		for(int i = 0; i < iLength; i++){
			if (szFlags[i] < 'a' || szFlags[i] > 'z' || g_iFlagLetters[szFlags[i] - 'a'] < Admin_Reservation)
				continue;

			SetAdminFlag(iAdminID, g_iFlagLetters[szFlags[i] - 'a'], true);
		}

		if(iImmunity != -1 && GetAdminImmunityLevel(iAdminID) < iImmunity){
			SetAdminImmunityLevel(iAdminID, iImmunity);
		}

	}

	return true;
}


public void OnRebuildAdminCache(AdminCachePart iPart){
	if(iPart == AdminCache_Groups){
		if(g_hDatabase != INVALID_HANDLE)
			StartFetching();
		else
			SQL_TConnect(Callback_Connect, "administration_daemon");
	}
}

public Action ServerCommand_Rehash(int iArgs){
	DumpAdminCache(AdminCache_Groups, true);
	return Plugin_Handled;
}


public Action OnClientPreAdminCheck(int iClient)
{
	if(g_hDatabase == INVALID_HANDLE)
		return Plugin_Handled;

	if(GetUserAdmin(iClient) != INVALID_ADMIN_ID)
		return Plugin_Continue;

	if (g_iLoadingStatus[iClient] > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}
