#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <entcontrol>

#include <codmod301>

#define GIFT_PREFIX "[Prezenty]"
const int g_iMaxGifts = 2;
const float g_fTimeStart = 20.0;
const float g_fTimeEnd = 200.0;

char g_szGiftModel[] = "models/items/cs_gift.mdl"

int g_iSpotCount = -1;

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;
int g_iBeamColor[] = {255, 255, 0, 255};


bool g_bRoundEnd = false;

public OnPluginStart() {
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

public OnMapStart() {

	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    	g_iHaloSprite = PrecacheModel("materials/sprites/halo.vmt");


	AddFileToDownloadsTable("models/items/cs_gift.dx80.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.dx90.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.mdl");
	AddFileToDownloadsTable("models/items/cs_gift.phy");
	AddFileToDownloadsTable("models/items/cs_gift.sw.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.vvd");
	AddFileToDownloadsTable("materials/models/items/cs_gift.vmt");
	AddFileToDownloadsTable("materials/models/items/cs_gift.vtf");

	PrecacheModel(g_szGiftModel);

        if (EC_Nav_Load())
        {
                if (EC_Nav_CachePositions())
                {
                        PrintToServer("cached positions");
                        g_iSpotCount = EC_Nav_GetHidingSpotsCount();
                }
                else
                {
                        PrintToServer("Unable to cache positions!");
                }
        }
        else
        {
                PrintToServer("No Navigation loaded! Make sure the .nav is not packed in one of the .vpk-files.");
        }


	float fRandom = GetRandomFloat(g_fTimeStart, g_fTimeEnd);
        CreateTimer(fRandom, Timer_SpawnGifts, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_RoundEnd(Event hEvent, const char[] szEvent, bool bBroadcast)
{
	g_bRoundEnd = true;
	return Plugin_Continue;
}

public Action Event_RoundStart(Event hEvent, const char[] szEvent, bool bBroadcast) 
{
	g_bRoundEnd = false;
 
	return Plugin_Continue;
}

public Action Timer_SpawnGifts(Handle hTimer)
{
	if(!g_bRoundEnd && g_iSpotCount >= g_iMaxGifts && GetClientCount(true) >= 8)
	{
		int iAmount = GetRandomInt(1, g_iMaxGifts);
		for(int i = 0; i < iAmount; i++)
		{
			SpawnRandomGift();
		}
		PrintCenterTextAll("Na mapie pojawiły się prezenty!");	
	}

	float fRandom = GetRandomFloat(g_fTimeStart, g_fTimeEnd);
	CreateTimer(fRandom, Timer_SpawnGifts, _, TIMER_FLAG_NO_MAPCHANGE);
}



int SpawnRandomGift()
{
	if(g_iSpotCount <= 0) return -1;

	int iEntity = CreateEntityByName("prop_physics_override");
	SetEntityModel(iEntity, g_szGiftModel)

	if(DispatchSpawn(iEntity)) {
		SetEntProp(iEntity, Prop_Send, "m_usSolidFlags",  152);
		SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 11);
	}

	int iRandom = GetRandomInt(0, g_iSpotCount - 1);
	float fPos[3];
	if(EC_Nav_GetHidingSpot(iRandom, fPos))
	{
		TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);
		float fPosTop[3];
		fPosTop[0] = fPos[0];
		fPosTop[1] = fPos[1];
		fPosTop[2] = fPos[2] + 2000.0;
		TE_SetupBeamPoints(fPos, fPosTop, g_iBeamSprite, g_iHaloSprite, 0, 66, 15.0, 10.0, 10.0, 1, 0.0, g_iBeamColor, 5);
   		TE_SendToAll();
		SDKHook(iEntity, SDKHook_Touch, OnGiftTouch)
	}
	else
	{
		RemoveEdict(iEntity);
		iEntity = -1;
	}


	return iEntity;
}


public Action:OnGiftTouch(int iGift, int iClient) {
	if(!IsValidPlayer(iClient)) {
		return Plugin_Continue;
	}

	int iRandom = GetRandomInt(1, 100);
	if(iRandom <= 40)
	{
		int iExp = GetRandomInt(1000, 2000);
		CodMod_GiveExp(iClient, iExp);
		PrintToChatAll("%s %N dostał %d expa z prezentu!", GIFT_PREFIX, iClient, iExp);

	}
	else if(iRandom > 40 && iRandom <= 80)
	{
		PrintToChatAll("%s %N znalazł pusty prezent!", GIFT_PREFIX, iClient);
	}
	else
	{
		int iDogtags = GetRandomInt(5, 10);
		CodMod_SetDogtagCount(iClient, CodMod_GetDogtagCount(iClient) + iDogtags);
		PrintToChatAll("%s %N dostał %d nieśmiertelników z prezentu!", GIFT_PREFIX, iClient, iDogtags);
	}

	RemoveEdict(iGift);

	return Plugin_Handled
}



