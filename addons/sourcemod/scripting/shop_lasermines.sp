#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>
#include <zr_lasermines>
#include <shop>

#define PLUGIN_VERSION "1.0.0"

#define CATEGORY 	"zr"
#define ITEM		"lasermine"

Handle:g_hPrice = INVALID_HANDLE;
new g_iPrice;

new ItemId:id;

public Plugin:myinfo =
{
	name = "[SHOP:ZR] Lasermine",
	author = "White Wolf",
	description = "Adds lasermines to the shop",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	CreateConVar("shop_zr_lasermines_version", PLUGIN_VERSION, "[Shop] Lasermines version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hPrice = CreateConVar("shop_zr_lasermines_price", "1000", "Price for the lasermines", FCVAR_PLUGIN, true, 1.0);
	g_iPrice = GetConVarInt(g_hPrice)
	HookConVarChange(g_hPrice, OnCvarChange);
	
	AutoExecConfig(true, "zombiereloaded/shop_zr_lasermines");
	
	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public OnCvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == g_hPrice)
	{
		g_iPrice = StringToInt(newValue);
		if (id != INVALID_ITEM)
			Shop_SetItemPrice(id, g_iPrice);
	}
}

public Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, "Zombie:Reloaded", "", OnCategoryDisplay);
	if (Shop_StartItem(category_id, ITEM))
	{
		Shop_SetInfo("zr_lasermines", "", g_iPrice, _, Item_BuyOnly);
		Shop_SetCallbacks(OnItemRegistered, _, ShouldDisplay, OnDisplay, _, _, OnBuy);
		Shop_EndItem();
	}
}

public OnItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id)
{
	id = item_id;
}

public bool:OnCategoryDisplay(client, CategoryId:category_id, const String:category[], const String:name[], String:buffer[], maxlen)
{
	FormatEx(buffer, maxlen, "Zombie:Reloaded", client);
	return true;
}

public bool:ShouldDisplay(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], ShopMenu:menu)
{
	if (!IsPlayerAlive(client))
		return true;
	if (ZR_IsClientHuman(client))
		return true;
	return false;
}

public bool:OnDisplay(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], ShopMenu:menu, &bool:disabled, const String:name[], String:buffer[], maxlen)
{
	FormatEx(buffer, maxlen, "Лазер-мины", client);
	return true;
}

public bool:OnBuy(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], ItemType:type, price, sell_price, value)
{
	if (!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
	{
		PrintToChat(client, "Вы должны быть человеком.")
		return false;
	}
	if (ZR_AddClientLasermines(client, 1, true))
	{
		//DEBUG
		PrintToChat(client, "Вы успешно купили себе мину.");
		return true;
	}
	return false;
}