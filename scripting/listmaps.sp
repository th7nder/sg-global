#include <sourcemod>
#include <map_workshop_functions>

Handle g_hMapArray = null;
int g_iMapSerial = -1;


public void OnPluginStart()
{
        AddCommandListener(Listener_ListMaps, "listmaps");
}

public Action Listener_ListMaps(int iClient, const char[] szCommand, int iArgc)
{
        int iMapCount = GetArraySize(g_hMapArray);
        char szMap[256];
        PrintToConsole(iClient, "------------ Serwery-GO.pl MAPY ------------")
        for(int i = 0; i < iMapCount; i++)
        {
                GetArrayString(g_hMapArray, i, szMap, sizeof(szMap));
                PrintToConsole(iClient, "%s", szMap);
        }
        PrintToConsole(iClient, "--------------------------------------------");

        return Plugin_Stop;
}
public void OnConfigsExecuted()
{
        LoadMapList();
}


int LoadMapList()
{
        Handle hMapArray;
        
        if ((hMapArray = ReadMapList(g_hMapArray,
                        g_iMapSerial,
                        "sm_map menu",
                        MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT|MAPLIST_FLAG_MAPSFOLDER))
                != null)
        {
                g_hMapArray = hMapArray
        }
        
        if (g_hMapArray == null)
        {
                return 0;
        }
        
        
        char szMapName[512];
        char szDisplay[256];
        int iMapCount = GetArraySize(g_hMapArray);
  
        for (int i = 0; i < iMapCount; i++)
        {
                GetArrayString(g_hMapArray, i, szMapName, sizeof(szMapName));
                RemoveMapPath(szMapName, szDisplay, sizeof(szDisplay));
                SetArrayString(g_hMapArray, i, szDisplay);
        }

        return iMapCount;
}