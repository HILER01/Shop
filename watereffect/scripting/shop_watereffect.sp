#include <sourcemod>
#include <sdktools>
#include <shop>

#pragma semicolon 1
// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.0.2"
#define CATEGORY "ability"
#define ITEM "watereffect"

ConVar	Price,
		SellPrice,
		Duration;
ItemId id;

public Plugin myinfo =
{
	name = "[Shop] Water Effect",
	description = "Water effect on shoot",
	author = "White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	CreateConVar("shop_we_version", PLUGIN_VERSION, _, FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	Price = CreateConVar("sm_shop_we_price", "1000", "Цена покупки предмета. 0 бесплатно", FCVAR_PLUGIN, true, 0.0);
	SellPrice = CreateConVar("sm_shop_we_sellprice", "500", "Цена продажи предмета. -1 не продается", FCVAR_PLUGIN, true, -1.0);
	Duration = CreateConVar("sm_shop_we_duration", "86400", "Время действия предмета в минутах. 0 вечно", FCVAR_PLUGIN, true, 0.0);
	
	Price.AddChangeHook(OnCvarChange);
	SellPrice.AddChangeHook(OnCvarChange);
	Duration.AddChangeHook(OnCvarChange);
	
	HookEvent("player_hurt", Event_OnPlayerHurt);
	
	if (Shop_IsStarted()) Shop_Started();
	AutoExecConfig(true, "shop_watereffect", "shop");
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnCvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	char cvarname[64];
	cvar.GetName(cvarname, sizeof(cvarname));
	if (StrEqual("sm_shop_we_price", cvarname))
	{
		if (id != INVALID_ITEM)
			Shop_SetItemPrice(id, StringToInt(newValue));
	}
	else if (StrEqual("sm_shop_we_sellprice", cvarname))
	{
		if (id != INVALID_ITEM)
			Shop_SetItemSellPrice(id, StringToInt(newValue));
	}
	else if (StrEqual("sm_shop_we_duration", cvarname))
	{
		if (id != INVALID_ITEM)
			Shop_SetItemValue(id, StringToInt(newValue));
	}
}

public void Event_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if (client && Shop_IsClientHasItem(client, id) && Shop_IsClientItemToggled(client, id))
	{
		SetVariantString("WaterSurfaceExplosion");
		AcceptEntityInput(GetClientOfUserId(event.GetInt("userid")), "DispatchEffect");
	}
}

public int Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, "Способности", "");
	if (Shop_StartItem(category_id, ITEM))
	{
		Shop_SetInfo("Брызги воды", "", Price.IntValue, SellPrice.IntValue, Item_Togglable, Duration.IntValue);
		Shop_SetCallbacks(OnItemRegistered, OnItemEquip, _, _, _, _, OnBuy, OnSell);
		Shop_EndItem();
	}
}

public int OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	id = item_id;
}

public ShopAction OnItemEquip(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] cItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
		return Shop_UseOff;
	else
		return Shop_UseOn;
}

public bool OnBuy(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int price, int sell_price, int value)
{
	PrintToChat(client, "\x04[Shop] \x01Вы успешно купили \"Брызги воды\"!");
	return true;
}

public bool OnSell(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int sell_price)
{
	PrintToChat(client, "\x04[Shop] \x01Вы успешно продали \"Брызги воды\"!");
	return true;
}