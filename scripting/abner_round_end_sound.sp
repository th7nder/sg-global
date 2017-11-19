#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <emitsoundany>

#define ABNER_ADMINFLAG ADMFLAG_SLAY
#define PLUGIN_VERSION "1.3fi123x"


new Handle:g_hTRPath;
new Handle:g_AbNeRCookie;

new bool:g_bClientPreference[MAXPLAYERS+1];
new bool:SoundsTRSucess;

new g_SoundsTR = 0;

new String:soundtr[64][64];

new String:sCookieValue[11];

public Plugin:myinfo =
{
	name = "[CS:GO/CSS] RoundSound Sounds",
	author = "AbNeR_CSS",
	description = "Round End Sounds",
	version = PLUGIN_VERSION,
	url = "www.tecnohardclan.com/forum"
}



char g_szSoundNames[][] = {
	"Listopad01.mp3",
	"Listopad02.mp3",
	"Listopad03.mp3",
	"Listopad04.mp3",
	"Listopad05.mp3",
	"Listopad06.mp3",
	"Listopad07.mp3",
	"Listopad08.mp3",
	"Listopad09.mp3",
	"Listopad10.mp3",
	"Listopad11.mp3",
	"Listopad12.mp3",
	"Listopad13.mp3",
	"Listopad14.mp3",
	"Listopad15.mp3",
	"Listopad16.mp3",
	"Listopad17.mp3",
};

char g_szSoundTracks[][] = {
"21 Savage - Gucci On My ft. YG & Migos",
"joji - Medicine",
"joji - Will he",
"Miami Nights 1984 - Running In The 80's",
"Taco Hemingway - WIATR",
"Travis Scott - goosebumps ft. Kendrick Lamar",
"KEEMSTAR -Dollar In The Woods!",
"Jon Bellion - All Time Low",
"BIG SHAQ - MANS NOT HOT",
"Two Feet - Go Fck Yourself",
"Trap Sylvan Esso - Hey Mami (Big Wild Remix)",
"MYRNE - Confessions (feat. Cozi Zuehlsdorff)",
"Robotaki - Monkey Bars (feat. Claire Ridgely)",
"MACKLEMORE FEAT SKYLAR GREY - GLORIOUS",
"Headphone Activist - Haiku",
"Extra Terra & Urbanstep - Lost In Time",
"iDubbbz - Asian Jake Paul (XXXTentacion MashUp)",
"Imagine Dragons - Rise Up",
"Post Malone feat. 21 Savage - rockstar",
};




public OnPluginStart()
{
	//Cvars
	CreateConVar("abner_round_end_version", PLUGIN_VERSION, "Version of the plugin", FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hTRPath = CreateConVar("tr_music_path_november17", "serwery-go/november17", "Path of TT sounds in /cstrike/sound", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

	//ClientPrefs
	g_AbNeRCookie = RegClientCookie("RoundSound Sounds", "", CookieAccess_Private);
	new info;
	SetCookieMenuItem(SoundCookieHandler, any:info, "RoundSound Sounds");
	RegConsoleCmd("sound", abnermenu);
	RegConsoleCmd("abnersound", abnermenu);
	RegConsoleCmd("rs", abnermenu);
	for (new i = MaxClients; i > 0; --i)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        OnClientCookiesCached(i);
    }

	//Arquivo de configuraçăo
	AutoExecConfig(true, "abner_november17");

	RegAdminCmd("sound_load", CommandLoad, ABNER_ADMINFLAG);

	SoundsTRSucess = false;

	//Events
	HookEvent("round_end", RoundEnd);
}

public SoundCookieHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	OnClientCookiesCached(client);
	abnermenu(client, 0);
}

public Action:abnermenu(client, args)
{
	GetClientCookie(client, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
	new cookievalue = StringToInt(sCookieValue);
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_AbNeRMenu, "RoundSound Sound");
	if(cookievalue == 0)
	{
		AddMenuItem(g_AbNeRMenu, "ON", "Muzyka  ON <-");
		AddMenuItem(g_AbNeRMenu, "OFF", "Muzyka OFF");
	}
	else
	{
		AddMenuItem(g_AbNeRMenu, "ON", "Muzyka ON");
		AddMenuItem(g_AbNeRMenu, "OFF", "Muzyka OFF <-");
	}
	SetMenuExitBackButton(g_AbNeRMenu, true);
	SetMenuExitButton(g_AbNeRMenu, true);
	DisplayMenu(g_AbNeRMenu, client, 30);
}

public AbNeRMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(param1);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(param1, g_AbNeRCookie, "0");
				abnermenu(param1, 0);
			}
			case 1:
			{
				SetClientCookie(param1, g_AbNeRCookie, "1");
				abnermenu(param1, 0);
			}
		}
		CloseHandle(g_AbNeRMenu);
	}
	return 0;
}



public OnClientCookiesCached(client)
{
    decl String:sValue[8];
    GetClientCookie(client, g_AbNeRCookie, sValue, sizeof(sValue));

    g_bClientPreference[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public OnConfigsExecuted()
{
	LoadSoundsTR();
}

public PathChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	LoadSoundsTR();
}

public OnMapStart()
{
	LoadSoundsTR();
}


int GetSoundID(char[] szName){
	int iSize = sizeof(g_szSoundNames);
	char szTemp[128];
	for(int i = 0; i < iSize; i++){
		Format(szTemp, 128, "serwery-go/november17/%s", g_szSoundNames[i]);
		if(StrEqual(szName, szTemp)){
			return i;
		}
	}
	return 0;
}
PlaySoundTR()
{
	new rnd_sound = GetRandomInt(1, sizeof(g_szSoundNames));
	if(SoundsTRSucess)
	{
		PrintToChatAll("  \x0A Teraz gramy: \x0B %s", g_szSoundTracks[GetSoundID(soundtr[rnd_sound])] );
		for (new i = 1; i <= MaxClients; i++)
		{
			GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
			new cookievalue = StringToInt(sCookieValue);
			if(IsClientInGame(i) && cookievalue == 0)
			{
				AddSoundToCache(soundtr[rnd_sound],PLATFORM_MAX_PATH);
				ClientCommand(i, "play *%s", soundtr[rnd_sound]);
			}
		}
	}
	else
	{
		PrintToChatAll("\x04[RoundSound]\x01 Błąd RoundSoundów - Terroryści.");
	}
}


LoadSoundsTR()
{
	new namelen;
	new FileType:type;
	new String:name[64];
	new String:soundname[64];
	new String:soundname2[64];
	decl String:soundpath[128];
	decl String:soundpath2[128];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	PrintToChatAll(soundpath2);
	new Handle:pluginsdir = OpenDirectory(soundpath2);
	g_SoundsTR = 0;
	if(pluginsdir != INVALID_HANDLE)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name),type))
		{
			namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				g_SoundsTR++;
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname2, sizeof(soundname2), "%s/%s", soundpath, name);
				PrintToChatAll("\x04[RoundSound]\x01 %s - Loaded", soundname2);
				soundtr[g_SoundsTR] = soundname2;
			}
		}
		SoundsTRSucess = true;
	}
	else
	{
		PrintToChatAll("\x04[RoundSound]\x01 Nie można załadować muzyki TT - zła ścieżka.");
		SoundsTRSucess = false;
	}
}

stock AddSoundToCache(String:soundFile[],maxLength)
{
	PrecacheSoundAny(soundFile,true);
}

public Action:RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
		PlaySoundTR();
 }



public Action:CommandLoad(client, args)
{
	LoadSoundsTR();
	return Plugin_Handled;
}
