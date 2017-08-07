#include <sourcemod>
#include <colors_csgo>

public void OnPluginStart()
{
        RegConsoleCmd("vip", Command_VIP);
        RegConsoleCmd("Vip", Command_VIP);
        RegConsoleCmd("vIP", Command_VIP);
        RegConsoleCmd("VIP", Command_VIP);
}

public Action Command_VIP(int iClient, int iArgs)
{
        if(IsClientInGame(iClient))
        {
                CPrintToChat(iClient, "[VIP]{a} Aby kupić VIPa zajrzyj na stronę {red}sklep.serwery-go.pl{default}!");
        }
}