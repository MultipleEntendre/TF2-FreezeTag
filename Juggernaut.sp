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

//Color codes. (Light blue would be lovely for the [FT] prefix, but alas, we lack proper coloring)
#define cDefault				0x01
#define cLightGreen 			0x03
#define cGreen					0x04
#define cDarkGreen  			0x05

//Database Handle
new Handle:db = INVALID_HANDLE;

//Keeps track of who is the Juggernaut
new bool:g_bJuggernaut[MAXPLAYERS+1] = { false, ... };

//First dimension is Juggernauts killed, second is kills as Juggernaut
new g_iJuggernautsKilled[MAXPLAYERS+1] = { 0, ... };
new g_iJuggernautKills[MAXPLAYERS+1] = { 0, ... };
new String:g_sPlayerIDS[MAXPLAYERS+1];

//Do we have a Juggernaut yet?
new bool:g_bJuggernautExists = false;

//Sounds
new String:g_sSounds[10][24] = {"", "vo/scout_no03.wav",   "vo/sniper_no04.wav", "vo/soldier_no01.wav",
																		"vo/demoman_no03.wav", "vo/medic_no03.wav",  "vo/heavy_no02.wav",
																		"vo/pyro_no01.wav",    "vo/spy_no02.wav",    "vo/engineer_no03.wav"};

//How many juggernauts will there be?
//new Handle:g_hJuggernauts = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "Juggernaut",
	author = "Andre Daenitz",
	description = "A Halo-style Juggernaut mode for TF2",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{

	CreateConVar("sm_juggernaut", PL_VERSION, "Juggernaut Mode", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	//HookEvent("player_team",        Event_PlayerTeam);
	//HookEvent("player_changeclass", Event_PlayerClass);
	HookEvent("player_spawn",       Event_PlayerSpawn);
	HookEvent("player_death",       Event_PlayerDeath);
	
	if(db == INVALID_HANDLE)
	{
		decl String:error[512];
		db = SQL_TConnect(GetDatabase);
	}
	
	
}

public GetDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Database failure: %s", error);
	} else {
		db = hndl;
	}
}

public OnMapStart()
{
	decl i, String:sSound[32];
	for(i = 1; i < sizeof(g_sSounds); i++)
	{
		Format(sSound, sizeof(sSound), "sound/%s", g_sSounds[i]);
		PrecacheSound(g_sSounds[i]);
		AddFileToDownloadsTable(sSound);
	}
}

public OnClientPutInServer(client)
{
	g_bJuggernaut[client] = false;
	
	decl String:authid[64];
	GetClientAuthString(client, authid, 63);
	g_sPlayerIDS[client] = authid;
	
	g_iJuggernautKills[client] = 0;
	g_iJuggernautsKilled[client] = 0;
	
}

public OnClientDisconnect(client)
{
	if(g_bJuggernaut[client] && MaxClients >= 1)
	{
		g_bJuggernaut[client] = false;
		g_bJuggernaut[MaxClients] = true;
		TF2_RespawnPlayer(MaxClients);
	}
	else
	{
		g_bJuggernaut[client] = false;
		g_bJuggernautExists = false;
	}
	
	g_iJuggernautKills[client] = 0;
	g_iJuggernautsKilled[client] = 0;
	
}

public Event_PlayerClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iClass  = GetEventInt(event, "class"),
			iTeam   = GetClientTeam(iClient);
	
	if(!g_bJuggernautExists)
	{
		g_bJuggernaut[iClient] = true;
		g_bJuggernautExists = true;
	}
	
	if(g_bJuggernaut[iClient])
	{
		if(iTeam != TF_TEAM_RED)
			ChangeClientTeam(iClient, TF_TEAM_RED);
		if(iClass != TF_CLASS_SOLDIER)
		{
			EmitSoundToClient(iClient, g_sSounds[iClass]);
			TF2_SetPlayerClass(iClient, TFClass_Soldier);
		}
		TF2_AddCondition(iClient, TFCond_Buffed, 60.0);
	}
	else
	{
		if(iTeam != TF_TEAM_BLU)
			ChangeClientTeam(iClient, TF_TEAM_BLU);
		if(iClass != TF_CLASS_SCOUT)
		{
			EmitSoundToClient(iClient, g_sSounds[iClass]);
			TF2_SetPlayerClass(iClient, TFClass_Scout);
		}
	}
}


public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iTeam   = GetClientTeam(iClient);
			
	if(!g_bJuggernautExists)
	{
		g_bJuggernaut[iClient] = true;
		g_bJuggernautExists = true;
	}
	
	if(g_bJuggernaut[iClient])
	{
		if(iTeam != TF_TEAM_RED)
			ChangeClientTeam(iClient, TF_TEAM_RED);
		TF2_SetPlayerClass(iClient, TFClass_Soldier);
		TF2_AddCondition(iClient, TFCond_Buffed, 60.0);
		TF2_RegeneratePlayer(iClient);
	}
	else
	{
		if(iTeam != TF_TEAM_BLU)
			ChangeClientTeam(iClient, TF_TEAM_BLU);
		TF2_SetPlayerClass(iClient, TFClass_Scout);
		TF2_RegeneratePlayer(iClient);
	}
}

public Event_PlayerTeam(Handle:event,  const String:name[], bool:dontBroadcast)
{	
	new iClient = GetClientOfUserId(GetEventInt(event, "userid")),
			iTeam   = GetClientTeam(iClient);
	
	if(!g_bJuggernautExists)
	{
		g_bJuggernaut[iClient] = true;
		g_bJuggernautExists = true;
	}
	
	if(g_bJuggernaut[iClient])
	{
		if(iTeam != TF_TEAM_RED)
		{
			ChangeClientTeam(iClient, TF_TEAM_RED);
			EmitSoundToClient(iClient, g_sSounds[TF_CLASS_SOLDIER]);
			TF2_AddCondition(iClient, TFCond_Buffed, 60.0);
		}
		TF2_SetPlayerClass(iClient, TFClass_Soldier);
	}
	else
	{
		if(iTeam != TF_TEAM_BLU)
		{
			ChangeClientTeam(iClient, TF_TEAM_RED);
			EmitSoundToClient(iClient, g_sSounds[TF_CLASS_SCOUT]);
		}
		TF2_SetPlayerClass(iClient, TFClass_Scout);
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new killerId = GetEventInt(event, "attacker");
	new killedId = GetEventInt(event, "userid");
	
	new killer = GetClientOfUserId(killerId);
	new killed = GetClientOfUserId(killedId);
	
	if(g_bJuggernaut[killed])
	{
		if (IsClientInGame(killer) && IsPlayerAlive(killer))
		{
			g_iJuggernautsKilled[killer]++;
			
			g_bJuggernaut[killed] = false;
			g_bJuggernaut[killer] = true;
			
			//Respawn and teleport.
			new Float:origin[3];
			GetClientAbsOrigin(killer, origin);
			new Float:angles[3];
			GetClientAbsAngles(killer, angles);			
			TF2_RespawnPlayer(killer);
			TeleportEntity(killer, origin, angles, NULL_VECTOR);
			
			//Respawn the old Juggernaut.
			TF2_RespawnPlayer(killed);
			
			decl String:message[128];
			decl String:killerName[64];
			GetClientName(killer, killerName, sizeof(killerName));
			Format(message, sizeof(message), "%c[JG]%c %s is now the Juggernaut! KILL HIM!", cGreen, cDefault, killerName);
			PrintToChatAll(message);
		}
	}
	if(g_bJuggernaut[killer])
	{
		g_iJuggernautKills[killer]++;
		
		new juggernautHp = GetClientHealth(killer);
		SetEntProp(killer, Prop_Data, "m_iHealth", juggernautHp + 25);
		
		//Respawn the dead scout.
		TF2_RespawnPlayer(killed);
		
		//Rebuff the juggernaut
		TF2_AddCondition(killer, TFCond_Buffed, 60.0);
	}
}