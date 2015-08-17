#include <sourcemod>
#include <sdktools>
#include <shop>

#pragma semicolon 1
// Force 1.7 syntax
// #pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define CATEGORY "Laseraim"
#define OPTIMIZATION 0 // 0 - работа через OnGameFrame | 1 - работа через Таймер

new CategoryId:g_CategoryId;

new Handle:g_hKv;

new g_iLaser,
	g_iGlow;

#if OPTIMIZATION
new Handle:g_hTimer[MAXPLAYERS+1];
#endif
new g_iClientLaser[MAXPLAYERS+1],
	m_iFOV;

new Handle:WeaponList,
	String:g_cWeaponList[16][32],
	g_iNumWeapons;

public Plugin:myinfo =
{
	name = "[Shop] Laser Aim",
	description = "Creates a beam for every times when player holds in arms a Snipers Rifle",
	author = "Leonardo & White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public OnPluginStart()
{
	CreateConVar("shop_laser_aim_version", PLUGIN_VERSION, _, FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_DONTRECORD);
	WeaponList = CreateConVar("shop_laser_aim_weapons", "awp,sg550,scout,g3sg1", "List of weapon used by plugin", FCVAR_PLUGIN);
	HookConVarChange(WeaponList, OnCvarChange);
	
	AutoExecConfig(true, "laseraim", "shop");
	
	m_iFOV = FindSendPropOffs("CBasePlayer", "m_iFOV");
	if (m_iFOV == -1)
		SetFailState("Fatal Error: Unable to find offset: \"CBasePlayer::m_iFOV\"");
	
	if (Shop_IsStarted()) Shop_Started();
}

public OnConfigsExecuted()
{
	decl String:cBuffer[128];
	GetConVarString(WeaponList, cBuffer, sizeof(cBuffer));
	g_iNumWeapons = ExplodeString(cBuffer, ",", g_cWeaponList, sizeof(g_cWeaponList), sizeof(g_cWeaponList[]));
}

public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == WeaponList)
		g_iNumWeapons = ExplodeString(newValue, ",", g_cWeaponList, sizeof(g_cWeaponList), sizeof(g_cWeaponList[]));
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public OnMapStart()
{
	g_iLaser = PrecacheModel("materials/sprites/laser.vmt");
	g_iGlow = PrecacheModel("sprites/redglow1.vmt");
}

public Shop_Started()
{
	if (g_hKv != INVALID_HANDLE) CloseHandle(g_hKv);
	g_hKv = CreateKeyValues("Laser Aim");
	
	decl String:buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "laser_aim.txt");
	
	if (!FileToKeyValues(g_hKv, buffer)) SetFailState("Couldn't parse file %s", buffer);
	
	if (KvGotoFirstSubKey(g_hKv, true))
	{
		decl String:item[64];
		// Register category `Laseraim`
		g_CategoryId = Shop_RegisterCategory(CATEGORY, "Лазерный прицел", "");
		do
		{
			if (KvGetSectionName(g_hKv, item, sizeof(item)) && Shop_StartItem(g_CategoryId, item))
			{
				KvGetString(g_hKv, "name", buffer, sizeof(buffer), item);
				KvGetString(g_hKv, "desc", item, sizeof(item), "");
				Shop_SetInfo(buffer, item, KvGetNum(g_hKv, "price", 500), KvGetNum(g_hKv, "sell_price", 200), Item_Togglable, KvGetNum(g_hKv, "duration", 86400));
				Shop_SetCallbacks(_, OnEquipItem);
				Shop_EndItem();
			}
		} while (KvGotoNextKey(g_hKv, true));
		KvRewind(g_hKv);
	}
	KvRewind(g_hKv);
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_iClientLaser[client] = 0;
		return Shop_UseOff;
	}
	Shop_ToggleClientCategoryOff(client, category_id);
	g_iClientLaser[client] = _:item_id;
	
	#if OPTIMIZATION
	new Handle:LaserData;
	g_hTimer[client] = CreateDataTimer(0.1, SimpleTimer_Handler, LaserData, TIMER_REPEAT);
	WritePackCell(LaserData, client);
	WritePackString(LaserData, item);
	#endif
	return Shop_UseOn;
}

#if !OPTIMIZATION
public OnGameFrame()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_iClientLaser[i])
		{
			decl String:weaponname[32],
				String:item[64];
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				GetClientWeapon(i, weaponname, sizeof(weaponname));
				
				new i_PlFOV = GetEntData(i, m_iFOV);
				
				for (new w = 0; w < g_iNumWeapons; w++)
				{
					if (StrContains(weaponname, g_cWeaponList[w]) > -1)
					{
						Shop_GetItemById(ItemId:g_iClientLaser[i], item, sizeof(item));
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
public Action:SimpleTimer_Handler(Handle:timer, Handle:pack)
{
	decl String:item[64];
	ResetPack(pack);
	new client = ReadPackCell(pack);
	ReadPackString(pack, item, sizeof(item));
	
	if (!g_iClientLaser[client])
	{
		timer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	else
	{
		decl String:weaponname[32];
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			GetClientWeapon(client, weaponname, sizeof(weaponname));
			
			new i_PlFOV = GetEntData(client, m_iFOV);
			
			for (new w = 0; w < g_iNumWeapons; w++)
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

public CreateLaser(client, const String:item[])
{
	new iColor[4];
	new Float:fLife, Float:fWidth, Float:fDotWidth, Float:vieworigin[3], Float:pos[3], Float:clientpos[3];
	if (KvJumpToKey(g_hKv, item))
	{
		KvGetColor(g_hKv, "color", iColor[0], iColor[1], iColor[2], iColor[3]);
		if (!iColor[0] && !iColor[1] && !iColor[2] && !iColor[3])
			iColor = {255, 0, 0, 255};
		fLife = KvGetFloat(g_hKv, "life", 0.1);
		fWidth = KvGetFloat(g_hKv, "width", 0.12);
		fDotWidth = KvGetFloat(g_hKv, "dot_width", 0.25);
		
		GetClientAbsOrigin(client, vieworigin);
		if (GetClientButtons(client) & IN_DUCK)
			vieworigin[2] += 40;
		else
			vieworigin[2] += 60;
		
		GetLookPos(client, pos);
		
		new Float:distance = GetVectorDistance(vieworigin, pos);
		new Float:percentage = 0.4 / (distance / 100);
		
		new Float:newPlayerViewOrigin[3];
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
		
		KvRewind(g_hKv);
	}
}

GetLookPos(client, Float:pos[3])
{
	new Float:eyepos[3], Float:eyeang[3], Handle:h_trace;
	GetClientEyePosition(client, eyepos);
	GetClientEyeAngles(client, eyeang);
	h_trace = TR_TraceRayFilterEx(eyepos, eyeang, MASK_SOLID, RayType_Infinite, GetLookPos_Filter, client);
	TR_GetEndPosition(pos, h_trace);
	CloseHandle(h_trace);
}

public bool:GetLookPos_Filter(ent, mask, any:client)
{
	return client != ent; // Проверка, что игрок не смотрит на себя.
}