#include <sourcemod>
#include <sdktools>
#include <shop>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1
// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.3"
#define CATEGORY "Laseraim"
#define OPTIMIZATION 0 // 0 - работа через OnGameFrame | 1 - работа через Таймер
#define UPDATE_URL "http://updater.tibari.ru/shop/laseraim/updatefile.txt"

CategoryId g_CategoryId;

KeyValues kv;

int g_iLaser;
int g_iGlow;

#if OPTIMIZATION
Handle g_hTimer[MAXPLAYERS+1];
#endif
int g_iClientLaser[MAXPLAYERS+1];
int m_iFOV;

ConVar WeaponList;
char g_cWeaponList[16][32];
int g_iNumWeapons;

public Plugin myinfo =
{
	name = "[Shop] Laser Aim",
	description = "Creates a beam for every times when player holds in arms a Snipers Rifle",
	author = "Leonardo & White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	CreateConVar("shop_laser_aim_version", PLUGIN_VERSION, _, FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_DONTRECORD);
	WeaponList = CreateConVar("shop_laser_aim_weapons", "awp,sg550,scout,g3sg1", "List of weapon used by plugin", FCVAR_PLUGIN);
	
	WeaponList.AddChangeHook(OnCvarChange);
	
	AutoExecConfig(true, "laseraim", "shop");
	
	m_iFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
	if (m_iFOV == -1)
		SetFailState("Fatal Error: Unable to find offset: \"CBasePlayer::m_iFOV\"");
	
	if (Shop_IsStarted()) Shop_Started();
	
	if (LibraryExists("updater")) Updater_AddPlugin(UPDATE_URL);
}

public void OnConfigsExecuted()
{
	char cBuffer[128];
	WeaponList.GetString(cBuffer, sizeof(cBuffer));
	g_iNumWeapons = ExplodeString(cBuffer, ",", g_cWeaponList, sizeof(g_cWeaponList), sizeof(g_cWeaponList[]));
}

public void OnCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char convarname[64];
	convar.GetName(convarname, sizeof(convarname));
	
	if (StrEqual("shop_laser_aim_weapons", convarname))
		g_iNumWeapons = ExplodeString(newValue, ",", g_cWeaponList, sizeof(g_cWeaponList), sizeof(g_cWeaponList[]));
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	g_iGlow = PrecacheModel("sprites/redglow1.vmt");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater")) Updater_AddPlugin(UPDATE_URL);
}

public int Updater_OnPluginUpdated()
{
	LogMessage("Plugin updated. Old version %s. Now reloading...", PLUGIN_VERSION);
	ReloadPlugin();
}

public int Shop_Started()
{
	if (kv != null) kv.Close();
	kv = new KeyValues("Laser Aim");
	
	char buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "laser_aim.txt");
	
	if (!kv.ImportFromFile(buffer)) SetFailState("Couldn't parse file %s", buffer);
	
	if (kv.GotoFirstSubKey(true))
	{
		char item[64];
		// Register category `Laseraim`
		g_CategoryId = Shop_RegisterCategory(CATEGORY, "Лазерный прицел", "");
		do
		{
			if (kv.GetSectionName(item, sizeof(item)) && Shop_StartItem(g_CategoryId, item))
			{
				kv.GetString("name", buffer, sizeof(buffer), item);
				kv.GetString("desc", item, sizeof(item), "");
				Shop_SetInfo(buffer, item, kv.GetNum("price", 500), kv.GetNum("sell_price", 200), Item_Togglable, kv.GetNum("duration", 86400));
				Shop_SetCallbacks(_, OnEquipItem, _, _, _, _, _, OnItemSell);
				Shop_EndItem();
			}
		} while (kv.GotoNextKey(true));
		kv.Rewind();
	}
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_iClientLaser[client] = 0;
		return Shop_UseOff;
	}
	Shop_ToggleClientCategoryOff(client, category_id);
	g_iClientLaser[client] = view_as<int>(item_id);
	
	#if OPTIMIZATION
	Handle LaserData;
	g_hTimer[client] = CreateDataTimer(0.1, SimpleTimer_Handler, LaserData, TIMER_REPEAT);
	WritePackCell(LaserData, client);
	WritePackString(LaserData, item);
	#endif
	return Shop_UseOn;
}

public bool OnItemSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int sell_price)
{
	if (Shop_IsClientItemToggled(client, item_id)) g_iClientLaser[client] = 0;
	return true;
}

public int Shop_OnAuthorized(int client)
{
	if (client && IsClientInGame(client))
	{
		ItemId item_id = view_as<ItemId>(g_iClientLaser[client]);
		if (!Shop_IsClientItemToggled(client, item_id))
			g_iClientLaser[client] = 0;
	}
}

#if !OPTIMIZATION
public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iClientLaser[i])
		{
			char weaponname[32];
			char item[64];
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				GetClientWeapon(i, weaponname, sizeof(weaponname));
				
				int i_PlFOV = GetEntData(i, m_iFOV);
				
				for (int w = 0; w < g_iNumWeapons; w++)
				{
					if (StrContains(weaponname, g_cWeaponList[w]) > -1)
					{
						Shop_GetItemById((view_as<ItemId>(g_iClientLaser[i])), item, sizeof(item));
						switch(i_PlFOV)
						{
							case 10: CreateLaser(i, item);
							case 15: CreateLaser(i, item);
							case 40: CreateLaser(i, item);
						}
					}
				}
			}
		}
	}
}
#endif

#if OPTIMIZATION
public Action SimpleTimer_Handler(Handle timer, Handle pack)
{
	char item[64];
	ResetPack(pack);
	int client = ReadPackCell(pack);
	ReadPackString(pack, item, sizeof(item));
	
	if (!g_iClientLaser[client])
	{
		timer = null;
		return Plugin_Stop;
	}
	else
	{
		char weaponname[32];
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			GetClientWeapon(client, weaponname, sizeof(weaponname));
			
			int i_PlFOV = GetEntData(client, m_iFOV);
			
			for (int w = 0; w < g_iNumWeapons; w++)
			{
				if (StrContains(weaponname, g_cWeaponList[w]) > -1)
				{
					switch(i_PlFOV)
					{
						case 10: CreateLaser(client, item);
						case 15: CreateLaser(client, item);
						case 40: CreateLaser(client, item);
					}
				}
			}
		}
		return Plugin_Continue;
	}
}
#endif

public void CreateLaser(int client, const char[] item)
{
	int iColor[4];
	float fLife, fWidth, fDotWidth, vieworigin[3], pos[3], clientpos[3];
	if (kv.JumpToKey(item))
	{
		kv.GetColor4("color", iColor);
		if (!iColor[0] && !iColor[1] && !iColor[2] && !iColor[3])
			iColor = {255, 0, 0, 255};
		fLife = kv.GetFloat("life", 0.1);
		fWidth = kv.GetFloat("width", 0.12);
		fDotWidth = kv.GetFloat("dot_width", 0.25);
		
		GetClientAbsOrigin(client, vieworigin);
		if (GetClientButtons(client) & IN_DUCK)
			vieworigin[2] += 40;
		else
			vieworigin[2] += 60;
		
		GetLookPos(client, pos);
		
		float distance = GetVectorDistance(vieworigin, pos);
		float percentage = 0.4 / (distance / 100);
		
		float newPlayerViewOrigin[3];
		newPlayerViewOrigin[0] = vieworigin[0] + ((pos[0] - vieworigin[0]) * percentage);
		newPlayerViewOrigin[1] = vieworigin[1] + ((pos[1] - vieworigin[1]) * percentage) - 0.08;
		newPlayerViewOrigin[2] = vieworigin[2] + ((pos[2] - vieworigin[2]) * percentage);
		
		GetClientEyePosition(client, clientpos); // Получаем позицию головы
		
		// Создаем луч
		TE_SetupBeamPoints(newPlayerViewOrigin, pos, g_iLaser, 0, 0, 0, fLife, fWidth, 0.0, 1, 0.0, iColor, 0);
		TE_SendToAll();
		
		// Создаем точку
		TE_SetupGlowSprite(pos, g_iGlow, fLife, fDotWidth, iColor[3]);
		TE_SendToAll();
		
		kv.Rewind();
	}
}

void GetLookPos(int client, float pos[3])
{
	float eyepos[3], eyeang[3]; Handle h_trace;
	GetClientEyePosition(client, eyepos);
	GetClientEyeAngles(client, eyeang);
	h_trace = TR_TraceRayFilterEx(eyepos, eyeang, MASK_SOLID, RayType_Infinite, GetLookPos_Filter, client);
	TR_GetEndPosition(pos, h_trace);
	h_trace.Close();
}

public bool GetLookPos_Filter(int ent, int mask, any client)
{
	return client != ent; // Проверка, что игрок не смотрит на себя.
}