/* Plugin Template generated by Pawn Studio */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define PL_VERSION "1.0"

#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_HEAVY			6
#define TF_CLASS_MEDIC			5
#define TF_CLASS_PYRO		    7
#define TF_CLASS_SCOUT			1
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_SPY			8
#define TF_CLASS_UNKNOWN		0

#define TF_TEAM_BLU					3
#define TF_TEAM_RED					2

new g_iClass[MAXPLAYERS + 1];
//Keeps track of frozen status of all players
new bool:g_bFrozen[MAXPLAYERS+1] = { false, ... };

//Timers to handle auto unfreeze for each player
new Handle:g_hUnfreezeTimer[MAXPLAYERS+1] = { INVALID_HANDLE, ... }; 

//Losers stay frozen, winners get to do what they want
new bool:g_bIsHumiliationRound = false;

//The team that won the humiliation round. (RED_TEAM || BLU_TEAM)
new g_iHumiliationRoundWinners = 0;

//Stores the actual enabled state of freeze tag. Turned off after rounds and back on in the next round. 
//Using this instead of the cvar so I can install ftmode voting soon.
new bool:g_bFreezeTagEnabled = false;

//Will medics be allowed to heal themselves? TODO: convar this
//new bool:g_bRemoveMedicAutoheal = true;

//Seconds to automatically unfreeze a frozen player. Value of 0 will disable auto-unfreeze
new Handle:g_cvAutoUnfreeze = INVALID_HANDLE;

//Should freeze tag be enabled on the server or not
new Handle:g_cvFreezeTagEnabled = INVALID_HANDLE;

new Handle:g_hEnabled;

public Plugin:myinfo = 
{
	name = "Fight Club Freeze Tag Combat",
	author = "Andre Daenitz and Jason Kanagaratnam",
	description = "Sets combat rules for Freeze Tag",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	CreateConVar("sm_freezetag_combat", PL_VERSION, "Enforce Freezetag Combat rules.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hEnabled                                = CreateConVar("sm_freezetag_combat_enabled",       "1",  "Enable/disable Freeze Tag combat rules in TF2.");
	
	HookEvent("player_changeclass", Event_PlayerClass);
	HookEvent("player_spawn",       Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_BlockWeaponRespawn);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_healed", Event_MedicUnfreeze);
	HookEvent("teamplay_capture_blocked", Event_AllowFrozenPointCapture, EventHookMode_Pre);
}

public Action:Event_AllowFrozenPointCapture(Handle:event, const String:name[], bool:dontBroadcast)
{
	new blockerId = GetEventInt(event, "blocker");
	new blocker = GetClientOfUserId(blockerId);
	
	if(g_bFrozen[blocker])
		return Plugin_Handled;
	else
		return Plugin_Continue;
	
}
public Event_MedicUnfreeze(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("Medic Unfreeze");
	new patientId = GetEventInt(event, "patient");
	new patient = GetClientOfUserId(patientId);
	MedicUnfreezePlayer(patient, g_hUnfreezeTimer[patient]);
}

public MedicUnfreezePlayer(client, timer)
{
	if (g_hUnfreezeTimer[client] == timer) //if this timer wasn't killed/updated, let it do it's thing.
	{
		//Small hack to make sure Unfreeze doesn't closehandle this timer while it's active
		
		
		UnfreezePlayer(client);
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("Player hurt");

	new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);
	if(g_bFrozen[attacker])
	{		
		//if(TF2_GetPlayerClass(victim) == TF_CLASS_SCOUT)
		//	SetEntProp(victim, Prop_Data, "m_iHealth", 125);
		//else
		//{
		//	new victimHp = GetClientHealth(victim);
		//	SetEntProp(victim, Prop_Data, "m_iHealth", victimHp);
		//}
		return Plugin_Handled;
	}
	if(TF2_GetPlayerClass(victim) == TF_CLASS_SCOUT && (TF2_GetPlayerClass(attacker) == TF_CLASS_MEDIC || TF2_GetPlayerClass(attacker) == TF_CLASS_SCOUT))
		FreezePlayer(victim);
	
	return Plugin_Continue;
}

public FreezePlayer(client)
{
	if(g_hUnfreezeTimer[client] == INVALID_HANDLE)
	{
		SetEntProp(client, Prop_Data, "m_iHealth", 65);
		TF2_AddCondition(client, TFCond_Ubercharged, 15.0);
		SetEntityMoveType(client, MOVETYPE_NONE);
	
		g_bFrozen[client] = true;
		g_hUnfreezeTimer[client] = CreateTimer(15.0, AutoUnfreezePlayer, client);
	}
}

public Action:AutoUnfreezePlayer(Handle:timer, any:client)
{	
	if (g_hUnfreezeTimer[client] == timer) //if this timer wasn't killed/updated, let it do it's thing.
	{
		//Small hack to make sure Unfreeze doesn't closehandle this timer while it's active
		
		
		UnfreezePlayer(client);
	}
}

public UnfreezePlayer(client)
{
	g_bFrozen[client] = false;
	
		//If we still have a linked timer, kill it
	if (g_hUnfreezeTimer[client] != INVALID_HANDLE)
	{
			
		KillTimer(g_hUnfreezeTimer[client]);
		g_hUnfreezeTimer[client] = INVALID_HANDLE;
	}
	
	TF2_RemoveCondition(client, TFCond_Ubercharged);
	SetEntityMoveType(client, MOVETYPE_WALK);
		//new Handle:event = CreateEvent("post_inventory_application");
		//SetEventInt(event, "userid", client);
		//FireEvent(event);
}
public Action:Event_BlockWeaponRespawn(Handle:event, const String:name[], bool:dontBroadcast)
{
		//new iClient = GetClientOfUserId(GetEventInt(event, "userid");
		//PrintToServer("Event fired, yo");
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iClass  = TF2_GetPlayerClass(iClient);

	if(iClass == TF_CLASS_SCOUT)
	{
			//TF2_AddCondition(iClient, 41, 30);	// if scout restrict to melee
			ScoutWeapons(iClient);
	}
	else if(iClass == TF_CLASS_MEDIC)// otherwise they are a medic so we take away their primary gun
	{
		//if(TF2_IsPlayerInCondition(iClient, 41))	// remove condition if player changes to medic from scout
			//TF2_RemoveCondition(iClient, 41);
		
		//TF2_RemoveWeaponSlot(iClient, 0);
		MedicWeapons(iClient);
	}
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iClass  = GetEventInt(event, "class");

	if(iClass == TF_CLASS_SCOUT)
	{
			//TF2_AddCondition(iClient, 41, 30);	// if scout restrict to melee
			ScoutWeapons(iClient);
	}
	else if(iClass == TF_CLASS_MEDIC)// otherwise they are a medic so we take away their primary gun
	{
		//if(TF2_IsPlayerInCondition(iClient, 41))	// remove condition if player changes to medic from scout
			//TF2_RemoveCondition(iClient, 41);
		
		//TF2_RemoveWeaponSlot(iClient, 0);
		MedicWeapons(iClient);
	}

}


public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iClass  = GetEventInt(event, "class");

	if(iClass == TF_CLASS_SCOUT)
	{
			//TF2_AddCondition(iClient, 41, 30);	// if scout restrict to melee
			ScoutWeapons(iClient);
	}
	else if(iClass == TF_CLASS_MEDIC)// otherwise they are a medic so we take away their primary gun
	{
		//if(TF2_IsPlayerInCondition(iClient, 41))	// remove condition if player changes to medic from scout
			//TF2_RemoveCondition(iClient, 41);
		
		//TF2_RemoveWeaponSlot(iClient, 0);
		MedicWeapons(iClient);
	}
}


/*	Deletes all weapon slots except for melee for the specified client */
stock ScoutWeapons(client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		for (new i = 0; i <= 5; i++)
		{
			if (i != 2)
				TF2_RemoveWeaponSlot(client, i);
		}
		
		new weapon = GetPlayerWeaponSlot(client, 2);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}

/*	Deletes all weapon slots except for melee and healer gun for the specified client */
stock MedicWeapons(client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client)) 
	{
		
				TF2_RemoveWeaponSlot(client, 0);
		
		
		new weapon = GetPlayerWeaponSlot(client, 1);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}


