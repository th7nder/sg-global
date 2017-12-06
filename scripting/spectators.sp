#include <sourcemod>
#include <cstrike>
#include <adminstealth>


char g_szPlayerPanelText[MAXPLAYERS+1][256];
bool g_bSpectate[MAXPLAYERS+1];
UserMsg g_msgHudMsg;
bool g_bAdminStealth;


public void OnPluginStart() {
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Post);
	g_msgHudMsg = GetUserMessageId("HudMsg");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("AdminStealth_IsInvisible");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bAdminStealth = LibraryExists("AdminStealth");
}
 
public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "AdminStealth"))
	{
		g_bAdminStealth = false;
	}
}
 
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "AdminStealth"))
	{
		g_bAdminStealth = true;
	}
}

public void OnMapStart() {
	CreateTimer(1.0, Timer_sec, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void OnClientPutInServer(int iClient) {
	g_bSpectate[iClient] = true;
}

public Action Event_OnPlayerTeam(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;
	int iTeam = GetEventInt(hEvent, "team");
	if (iTeam == CS_TEAM_SPECTATOR)
	{
		g_bSpectate[iClient] = true;
	} else {
		g_bSpectate[iClient] = false
	}
	return Plugin_Continue;
}


public Action Timer_sec(Handle hTimer) {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;
		if (IsPlayerAlive(i)) {
			SpecListMenuAlive(i);
		}
	}
}

public void SpecListMenuAlive(int iClient) // What player sees
{

	if (IsFakeClient(iClient) || GetClientMenu(iClient) != MenuSource_None)
		return;

	//Spec list for players
	Format(g_szPlayerPanelText[iClient], 512, "");
	char sSpecs[512];
	int iSpecMode;
	Format(sSpecs, 512, "");
	int count;
	count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(iClient) && !IsPlayerAlive(i) && g_bSpectate[i] && !IsClientSourceTV(i))
		{
			if(g_bAdminStealth) {
				if(AdminStealth_IsInvisible(i)) {
					continue;
				}
			}
			iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			if (iSpecMode == 4 || iSpecMode == 5)
			{
				int Target;
				Target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				if (Target == iClient)
				{
					count++;
					if (count < 6)
						Format(sSpecs, 512, "%s%N\n", sSpecs, i);

				}
				if (count == 6)
					Format(sSpecs, 512, "%s...", sSpecs);
			}
		}
	}
	if (count > 0)
	{
		Format(g_szPlayerPanelText[iClient], 512, "Obserwujący (%i):\n%s ", count, sSpecs);

		SpecList(iClient);
	}
	else
		Format(g_szPlayerPanelText[iClient], 512, "");
}

public void SpecList(int iClient)
{
	if (!IsValidClient(iClient) || IsFakeClient(iClient) || GetClientMenu(iClient) != MenuSource_None)
		return;

	if (!StrEqual(g_szPlayerPanelText[iClient], ""))
	{
		HudMsg(iClient, 1, {0.01, 0.38}, {255, 171, 112,255}, {255, 171, 112,255}, 0, 0.1, 0.1, 1.1, 0.0, g_szPlayerPanelText[iClient])
	}
}

public int PanelHandler(Handle menu, MenuAction action, int param1, int param2)
{
}

stock bool IsValidClient(int client)
{
	if (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}

HudMsg(int iClient, int iChannel, const Float:fPosition[2], const int iColor1[4], const int iColor2[4], int iEffect, Float:fFadeInTime, Float:fFadeOutTime, Float:fHoldTime, Float:fEffectTime, const char[] szText, any:...)
{
	if(GetUserMessageType() != UM_Protobuf)
		return false;

	decl String:szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szText, 12);

	decl iClients[1];
	iClients[0] = iClient;

	new Handle:hMessage = StartMessageEx(g_msgHudMsg, iClients, 1);
	PbSetInt(hMessage, "channel", iChannel);
	PbSetVector2D(hMessage, "pos", fPosition);
	PbSetColor(hMessage, "clr1", iColor1);
	PbSetColor(hMessage, "clr2", iColor2);
	PbSetInt(hMessage, "effect", iEffect);
	PbSetFloat(hMessage, "fade_in_time", fFadeInTime);
	PbSetFloat(hMessage, "fade_out_time", fFadeOutTime);
	PbSetFloat(hMessage, "hold_time", fHoldTime);
	PbSetFloat(hMessage, "fx_time", fEffectTime);
	PbSetString(hMessage, "text", szBuffer);
	EndMessage();

	return true;
}