#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors_csgo>

char szSounds[4][128] =
{
        {"serwery-go/johncena.mp3"},
        {"serwery-go/leeroy.mp3"},
        {"serwery-go/smokeweed.mp3"},
        {"serwery-go/xfiles.mp3"}
}

int g_iLastSound = -1;


public void OnMapStart()
{
        char szBuffer[256];
        int iSize = sizeof(szSounds);
        for(int i = 0; i < iSize; i++)
        {
                Format(szBuffer, sizeof(szBuffer), "sound/%s", szSounds[i]);
                AddFileToDownloadsTable(szBuffer);
                Format(szBuffer, sizeof(szBuffer), "*/%s", szSounds[i]);
                FakePrecacheSound(szBuffer);

        }

}

public void OnClientPutInServer(int iClient)
{
        CreateTimer(3.0, Timer_Connect, GetClientSerial(iClient));
}



public Action Timer_Connect(Handle hTimer, int iSerial)
{
        int iClient = GetClientFromSerial(iSerial);
        if(iClient == 0 || iClient > MAXPLAYERS)
        {
                return Plugin_Stop;
        }

        if(!Player_IsVIP(iClient))
        {
            return Plugin_Stop;
        }

        int iRandom = -1;
        do
        {
                iRandom = GetRandomInt(0, sizeof(szSounds) - 1);
        } while(iRandom == g_iLastSound);

        g_iLastSound = iRandom;
        char szSound[PLATFORM_MAX_PATH];
        Format(szSound, sizeof(szSound), "*/%s", szSounds[iRandom]);
        for(int i = 1; i <= MaxClients; i++)
        {
                if(IsClientInGame(i))
                {
                    EmitSoundToClient(i, szSound, i, SNDCHAN_STATIC, _, SND_CHANGEVOL, 0.2);
                }
  
        }

        CPrintToChatAll("{olive}[VIP] {red}%N{lime} wszedł na serwer!", iClient);

        return Plugin_Stop;
}


stock bool Player_IsVIP(int iClient)
{
    if (CheckCommandAccess(iClient, "codmod_vip", ADMFLAG_CUSTOM1, false)) 
    {
        return true;
    } 
    else 
    {
        return false;
    }
}

stock void FakePrecacheSound(const char[] szPath)
{
    AddToStringTable( FindStringTable( "soundprecache" ), szPath );
}