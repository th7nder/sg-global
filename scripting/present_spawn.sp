#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAXSPAWNS 100
#define MAXDISTANCE 2000.0
#define SAFEDISTANCE 1000.0
#define GIFTCOUNT 2

char g_szGiftModel[] = "models/items/cs_gift.mdl"
float g_fSpawnVec[MAXSPAWNS][3];
int g_iSpawnCount = 0;
int g_iGift[GIFTCOUNT];
int g_iGiftSpawn;


public OnPluginStart() {
	HookEvent("round_start", Event_RoundStart);
}

public OnMapStart() {
	AddFileToDownloadsTable("models/items/cs_gift.dx80.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.dx90.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.mdl");
	AddFileToDownloadsTable("models/items/cs_gift.phy");
	AddFileToDownloadsTable("models/items/cs_gift.sw.vtx");
	AddFileToDownloadsTable("models/items/cs_gift.vvd");
	AddFileToDownloadsTable("materials/models/items/cs_gift.vmt");
	AddFileToDownloadsTable("materials/models/items/cs_gift.vtf");
	PrecacheModel(g_szGiftModel);
	CreateTimer(20.0, RandomSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_RoundStart(Event hEvent, const char[] szEvent, bool bBroadcast) {
	if(GetClientCount(true) < 8) {
		//return;
	}

	if(g_iSpawnCount < 1) {
		LogError("Brak punktów spawn")
		return;
	}

	g_iGiftSpawn = 0;
	for(int i = 0; i < sizeof(g_iGift); i++) {
		g_iGift[i] = CreateEntityByName("prop_physics_override");
		SetEntityModel(g_iGift[i], g_szGiftModel)

		if(DispatchSpawn(g_iGift[i])) {
			SetEntProp(g_iGift[i], Prop_Send, "m_usSolidFlags",  152);
			SetEntProp(g_iGift[i], Prop_Send, "m_CollisionGroup", 11);
		}

		int iSpawn = GetRandomInt(0, g_iSpawnCount);
		while(iSpawn == g_iGiftSpawn) {
			iSpawn = GetRandomInt(0, g_iSpawnCount);
		}

		if (g_fSpawnVec[iSpawn][0] != -1.0 && iSpawn < MAXSPAWNS) {
			TeleportEntity(g_iGift[i], g_fSpawnVec[iSpawn], NULL_VECTOR, NULL_VECTOR);
			SDKHook(g_iGift[i], SDKHook_Touch, OnGiftTouch)
			g_iGiftSpawn = iSpawn;
		}
	}
}

public Action:OnGiftTouch(int iGift, int iClient) {
	if(!IsValidPlayer(iClient)) {
		return Plugin_Continue;
	}

	float fSpeed = GetEntPropFloat(iClient, Prop_Data, "m_flLaggedMovementValue");
	RemoveEdict(iGift);
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fSpeed);
	PrintToChat(iClient, "Podniosłeś prezent")
	return Plugin_Handled
}

public Action:RandomSpawn(Handle:timer) {
	CreateTimer(10.0, FindSpawns, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:FindSpawns(Handle:timer) {
	if (g_iSpawnCount != MAXSPAWNS) {
		for (new x = 1; x < GetMaxClients(); x++) {
			if (!IsValidEdict(x))
				continue;

			if (GetClientTeam(x) == 3 && IsPlayerAlive(x) && g_iSpawnCount != MAXSPAWNS) {
				GetClientAbsOrigin(x, g_fSpawnVec[g_iSpawnCount]);
				g_iSpawnCount++;
			}
		}
	}
	if (g_iSpawnCount == MAXSPAWNS) {
		for (new spawnIndex = 0; spawnIndex < MAXSPAWNS; spawnIndex++) {
			for (new iClient = 1; iClient <= GetMaxClients(); iClient++) {
				if (!IsClientConnected(iClient))
					continue;

				if (!IsClientInGame(iClient))
					continue;

				if (GetClientTeam(iClient) == 1)
					continue;

				new Float:playerVec[3];

				GetClientAbsOrigin(iClient, playerVec);
				if (GetVectorDistance(playerVec, g_fSpawnVec[spawnIndex]) > MAXDISTANCE) {
					//Assign the far player to the list, so he gets some trouble ;)
					g_fSpawnVec[spawnIndex][0] = playerVec[0];
					g_fSpawnVec[spawnIndex][1] = playerVec[1];
					g_fSpawnVec[spawnIndex][2] = playerVec[2];
				}
			}
		}
	}
}

stock bool IsValidPlayer(int iClient){
	if(iClient > 0 && iClient < MAXPLAYERS && IsClientInGame(iClient) && !IsFakeClient(iClient)){
		return true;
	}

	return false;
}