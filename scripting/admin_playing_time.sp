#include <sourcemod>
#include <cstrike>


public Plugin myinfo = {
    name = "Admin playing time",
    author = ".nbd",
    description = "Admin playing time",
    version = "1.0",
    url = "http://serwery-go.pl"
};

Database g_hDb;
int g_iJoinTime[MAXPLAYERS+1];
char g_szIP[64];
int g_iHostPort;

public void OnPluginStart() {
	Database.Connect(GotDatabase, "administration_daemon");
	int m_unIP = GetConVarInt(FindConVar("hostip"));
	Format(g_szIP, sizeof(g_szIP), "%d.%d.%d.%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF);
	g_iHostPort = GetConVarInt(FindConVar("hostport"));
}

public void GotDatabase(Database db, const char[] error, any data) {
	if(db == null)
		LogError("Database failure: %s", error);
	else
		g_hDb = db;

	char szQuery[256] = "CREATE TABLE `ad_admin_times` (`steamid` varchar(48) NOT NULL,`connect` int(11) NOT NULL,`disconnect` int(11) NOT NULL, `ip` varchar(16) NOT NULL, `port` varchar(5) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;";
	g_hDb.Query(T_nothing, szQuery);
}

public void OnClientPutInServer(int iClient) {
	g_iJoinTime[iClient] = GetTime();
}


public void OnClientDisconnect(int iClient) {
	if(Player_IsAdmin(iClient)) {
		char szQuery[256];
		char szAuthID[64];
		if(GetClientAuthId(iClient, AuthId_Steam2, szAuthID, 64))
		{
			Format(szQuery, 256, "INSERT INTO `ad_admin_times` (steamid, connect, disconnect, ip, port) VALUES ('%s', %i, %i, '%s', '%i')", szAuthID, g_iJoinTime[iClient], GetTime(), g_szIP, g_iHostPort);
			g_hDb.Query(T_nothing, szQuery);
		}
	}
}


stock bool Player_IsAdmin(int iClient){
	if (CheckCommandAccess(iClient, "th7_supervip", ADMFLAG_GENERIC, false)) {
		return true;
	} else {
		return false;
	}
}

public void T_nothing(Database db, DBResultSet results, const char[] error, any data) { return; }

stock bool IsValidPlayer(int iClient){
	if(iClient > 0 && iClient < MAXPLAYERS && IsClientInGame(iClient) && !IsFakeClient(iClient)){
		return true;
	}

	return false;
}
