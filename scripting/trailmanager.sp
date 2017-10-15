#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "[CS:GO] Trail Manager",
    author = "th7nder & Nobody",
    description = "Trail Manager",
    version = "0.2.0",
    url = "http://serwery-go.pl"
}

#define STRING(%1) %1, sizeof(%1)
#define PREFIX "    \x06[\x0BSerwery\x01-\x07GO\x06] "

int g_iBeamSprite = -1;
int g_iSpriteModel[MAXPLAYERS+1] = {-1, ...};

int g_iRoundCounter = 0;

public int Native_StopTrail(Handle hPlugin, int iNumParams){
    int iClient = GetNativeCell(1);
    if(IsValidPlayer(iClient)){
    ClearTrail(iClient);
    }
}

public int Native_CreateTrail(Handle hPlugin, int iNumParams){
    int iClient = GetNativeCell(1);
    float fLifeTime = view_as<float>(GetNativeCell(2));
    float fStartWidth = view_as<float>(GetNativeCell(3));
    float fEndWidth = view_as<float>(GetNativeCell(4));
    int iDelay = view_as<int>(GetNativeCell(5));
    int iRenderColor[4] = {0, 0, 0, 0};
    GetNativeArray(6, iRenderColor, 4);

    if(IsValidPlayer(iClient))
    CreateTrail(iClient, fLifeTime, fStartWidth, fEndWidth, iDelay, iRenderColor);
    return 0;
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrorLength){
    CreateNative("TM_CreateTrail", Native_CreateTrail);
    CreateNative("TM_DestroyTrail", Native_StopTrail);
    return APLRes_Success;
}

public void OnPluginStart(){
    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_death", Event_OnPlayerDeath);
    HookEvent("round_start", Event_OnRoundStart);
}

public void OnMapStart(){
    g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iRoundCounter = 0;
}

public void OnClientPutInServer(int iClient){
    ClearTrail(iClient);
}

public void OnClientDisconnect(int iClient){
    ClearTrail(iClient);
}


public Action Event_OnRoundStart(Event hEvent, const char[] szEventName, bool bBroadcast){
    g_iRoundCounter++;
}

public Action Event_OnPlayerSpawn(Event hEvent, const char[] szEventName, bool bBroadcast){
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
    ClearTrail(iClient);
}

public Action Event_OnPlayerDeath(Event hEvent, const char[] szEventName, bool bBroadcast){
    int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
    ClearTrail(iVictim);
}

stock void CreateTrail(int iClient, float fLifeTime, float fStartWidth, float fEndWidth, int iFade, int iRenderColor[4]){
    ClearTrail(iClient);
    g_iSpriteModel[iClient] = CreateEntityByName("env_spritetrail");
    if(g_iBeamSprite != -1 && g_iSpriteModel[iClient] != -1 && IsValidEntity(g_iSpriteModel[iClient])){
        char szTargetName[MAX_NAME_LENGTH];
        GetClientName(iClient, STRING(szTargetName));
        DispatchKeyValue(iClient, "targetname", szTargetName);

        DispatchKeyValue(g_iSpriteModel[iClient], "parentname", szTargetName);

        DispatchSpawn(g_iSpriteModel[iClient]);

        float fOrigin[3];
        GetClientAbsOrigin(iClient, fOrigin);
        fOrigin[2] += 3.0;
        TeleportEntity(g_iSpriteModel[iClient], fOrigin, NULL_VECTOR, NULL_VECTOR);

        SetVariantString(szTargetName);
        AcceptEntityInput(g_iSpriteModel[iClient], "SetParent");

        TE_SetupBeamFollow(g_iSpriteModel[iClient], g_iBeamSprite, 0, fLifeTime, fStartWidth, fEndWidth, iFade, iRenderColor);
        TE_SendToAll();

        Handle hPack = CreateDataPack();
        WritePackCell(hPack, GetClientSerial(iClient));
        WritePackCell(hPack, g_iRoundCounter);
        CreateTimer(fLifeTime, Timer_ClearTrail, hPack);
    }
}

public Action Timer_ClearTrail(Handle hTimer, Handle hPack){
    ResetPack(hPack);
    int iClient = GetClientFromSerial(ReadPackCell(hPack));
    int iRoundCounter = ReadPackCell(hPack);
    delete hPack;

    if(iRoundCounter != g_iRoundCounter){
        return Plugin_Stop;
    }

    if(!IsValidPlayer(iClient)){
        return Plugin_Stop;
    }

    ClearTrail(iClient);

    return Plugin_Stop;
}


stock void ClearTrail(int iClient){
    if(g_iSpriteModel[iClient] != -1){
    RemoveEdict(g_iSpriteModel[iClient]);
    }
    g_iSpriteModel[iClient] = -1;
}

stock bool IsValidPlayer(int iClient){
    if(iClient > 0 && iClient < MAXPLAYERS + 1 && IsValidEdict(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient)){
        return true;
    }

    return false;
}
