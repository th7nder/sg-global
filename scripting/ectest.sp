#include <entcontrol>
#include <sourcemod>
#include <sdktools>


bool navMeshLoaded = false;
float g_fLastPosition[3];
int g_iSpotCount = -1;
public void OnPluginStart()
{
        RegConsoleCmd("get_pos", Command_Test);
        RegConsoleCmd("get_pos2", Command_Test2);
}

public Action Command_Test(int iClient, int iArgs)
{
        float position[3];
        if (navMeshLoaded && EC_Nav_GetNextHidingSpot(position))
        {
                PrintToServer("%.2f %.2f %.2f", position[0], position[1], position[2]);
                if(iClient > 0)
                {
                        TeleportEntity(iClient, position, NULL_VECTOR, NULL_VECTOR);
                }


        }
}

public Action Command_Test2(int iClient, int iArgs)
{
        if (navMeshLoaded)
        {
                PrintToServer("count %d", g_iSpotCount);
                float fPos[3];
                int iRandom = GetRandomInt(0, g_iSpotCount - 1);
                PrintToServer("Randed: %d", iRandom);
                EC_Nav_GetHidingSpot(iRandom, fPos);
                PrintToServer("%.2f %.2f, %.2f", fPos[0], fPos[1], fPos[2]);
                if(iClient > 0)
                {
                        TeleportEntity(iClient, fPos, NULL_VECTOR, NULL_VECTOR);
                }

        }
}


public OnMapStart()
{
        navMeshLoaded = false;
        // Load the nav-mesh of the current map
        if (EC_Nav_Load())
        {
                // Cache positions
                if (EC_Nav_CachePositions())
                {
                        // Positions stored
                        navMeshLoaded = true;
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
}