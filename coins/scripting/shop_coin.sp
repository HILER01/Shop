#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <shop>

// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define CATEGORY "Coins"

CategoryId g_CategoryId;

KeyValues kv;

int m_nActiveCoinRank;

int g_iClientCoin[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[Shop] Coins",
	description = "Adds coins to shop",
	author = "White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	CreateConVar("sm_shop_coins_version", PLUGIN_VERSION, _, FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	m_nActiveCoinRank = FindSendPropInfo("CCSPlayerResource", "m_nActiveCoinRank");
	if (m_nActiveCoinRank == -1)
		SetFailState("Fatal Error: Unable to find offset: \"CCSPlayerResource::m_nActiveCoinRank\"");
	
	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	
}

public int Shop_Started()
{
	if (kv != null) kv.Close();
	kv = new KeyValues("Coins");
	
	char buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "coins.txt");
	
	if (!kv.ImportFromFile(buffer)) SetFailState("Couldn't parse file %s", buffer);
	
	if (kv.GotoFirstSubKey(true))
	{
		char item[64];
		// Register category `coins`
		g_CategoryId = Shop_RegisterCategory(CATEGORY, "Монеты", "");
		do
		{
			if (kv.GetSectionName(item, sizeof(item)) && Shop_StartItem(g_CategoryId, item))
			{
				kv.GetString("name", buffer, sizeof(buffer), item);
				kv.GetString("desc", item, sizeof(item), "");
				Shop_SetInfo(buffer, item, kv.GetNum("price", 1000), kv.GetNum("sell_price", 500), Item_Togglable, kv.GetNum("duration", 86400));
				Shop_SetCallbacks(_, OnEquipItem);
				Shop_EndItem();
			}
		} while (kv.GotoNextKey(true));
		kv.Rewind();
	}
	kv.Rewind();
}

public void OnMapStart()
{
	SDKHook(FindEntityByClassname(MaxClients+1, "cs_player_manager"), SDKHook_ThinkPost, Hook_OnThinkPost);
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_iClientCoin[client] = 0;
		return Shop_UseOff;
	}
	Shop_ToggleClientCategoryOff(client, category_id);
	// if (!SetCoin(client, true)) return Shop_UseOff;
	g_iClientCoin[client] = StringToInt(item);
	return Shop_UseOn;
}

public void Hook_OnThinkPost(int entity)
{
	for (int i = 1; i <= MaxClients; ++i)
		if (g_iClientCoin[i])
			SetEntData(entity, m_nActiveCoinRank + i*4, g_iClientCoin[i], 4, true);
}