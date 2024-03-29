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



new TF2GameRulesEntity; //The entity that controls spawn wave times

new databaseClient = 0;

//Keeps track of who is the Juggernaut
new bool:g_bJuggernaut[MAXPLAYERS+1] = { false, ... };

new g_iJuggernautsKilled[MAXPLAYERS+1];
new g_iJuggernautKills[MAXPLAYERS+1];

new Handle:db = INVALID_HANDLE;

new String:g_sClientIDS[MAXPLAYERS+1][64];
new String:g_sClientNames[MAXPLAYERS+1][64];

new Float:g_fFreezeOrigin[MAXPLAYERS+1][3];
new Float:g_fFreezeAngle[MAXPLAYERS+1][3];

//Do we have a Juggernaut yet?
new bool:g_bJuggernautExists = false;
new bool:g_bOnRespawn[MAXPLAYERS + 1];

new g_iClientCount;

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
	HookEvent("player_hurt", 	    Event_PlayerHurt);
	HookEvent("player_disconnect", Event_ClientDisconnect);
	g_iClientCount = 0;
	db = INVALID_HANDLE;
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
	
	//Find the TF_GameRules Entity
	TF2GameRulesEntity = FindEntityByClassname(-1, "tf_gamerules");
	//SetRespawnTime();
}

public OnClientPutInServer(client)
{
	g_bJuggernaut[client] = false;
	g_iClientCount++;
	
		
	decl String:id[64];
	decl String:name[64];
	GetClientAuthString(client, id, 63);
	GetClientName(client, name, 63);
	
	g_sClientIDS[client] = id;
	g_sClientNames[client] = name;
	
	g_iJuggernautKills[client] = 0;
	g_iJuggernautsKilled[client] = 0;
}

public Event_ClientDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	PrintToServer("Client #%d disconnected.", client);
	g_iClientCount--;
	
	if(g_bJuggernaut[client] && g_iClientCount >= 1 )
	{
		decl randomClient;
		for(randomClient = 1; randomClient < MAXPLAYERS; randomClient++)
		{
			if((randomClient != client) && IsClientConnected(randomClient) && IsPlayerAlive(randomClient))
				break;
		}
		
		PrintToServer("Client #%d should be new Juggernaut.", randomClient);
		
		g_bJuggernaut[client] = false;
		g_bJuggernaut[randomClient] = true;
		
		
		GetClientEyePosition(randomClient, g_fFreezeOrigin[randomClient]);
		GetClientEyeAngles(randomClient, g_fFreezeAngle[randomClient]);
		
		SetRespawnTime(); //Have to do this since valve likes to reset the TF_GameRules during rounds and map changes
		CreateTimer(0.0, SpawnJuggernautTimer, randomClient, TIMER_FLAG_NO_MAPCHANGE); //Respawn the player at the specified time
			
	}
	else if(g_iClientCount == 0)
	{
		g_bJuggernaut[client] = false;
		g_bJuggernautExists = false;
	}
	
	databaseClient = client;
	SQL_TConnect(GetDatabase);
	
	//decl String:query[512];
	//Format(query, sizeof(query), "INSERT INTO usersrecord (userID) values ('Bob');");
	//Format(query, sizeof(query),"INSERT INTO usersrecord (userID, userName, gamesPlayed, Freezes, MedicKills, KillsAsJugger, JuggerKills) VALUES ( 'Joe', 'Henry',0,0,0,3,4);"
	//ON DUPLICATE KEY UPDATE gamesPlayed = gamesPlayed + 0, Freezes = Freezes + 0, MedicKills = MedicKills + 0, KillsAsJugger = KillsAsJugger + %d, JuggerKills = JuggerKills + %d;",
								//g_sClientIDS[client],
								//g_sClientName[client],
								//g_iJuggernautKills[client],
								//g_iJuggernautsKilled[client],
								//g_iJuggernautKills[client],
								//g_iJuggernautsKilled[client]
								//);
								
	//PrintToServer(query);
	//SQL_TQuery(db, UpdateDatabase, query, client);
	
}

public GetDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Database failure: %s", error);
	} 
	else 
	{
		db = hndl;
	
		decl String:query[512];
		//Format(query, sizeof(query), "INSERT INTO usersrecord (userID) values ('Bob');");
		Format(query, sizeof(query),"INSERT INTO usersrecord (userID, userName, Freezes, MedicKills, KillsAsJugger, JuggerKills) VALUES ( '%s','%s',0,0,%d,%d) ON DUPLICATE KEY UPDATE Freezes = Freezes + 0, MedicKills = MedicKills + 0, KillsAsJugger = KillsAsJugger + %d, JuggerKills = JuggerKills + %d;",
								g_sClientIDS[databaseClient],
								g_sClientNames[databaseClient],
								g_iJuggernautKills[databaseClient],
								g_iJuggernautsKilled[databaseClient],
								g_iJuggernautKills[databaseClient],
								g_iJuggernautsKilled[databaseClient]
								);
								
		PrintToServer(query);
		SQL_TQuery(db, UpdateDatabase, query, data);
	}
}

public UpdateDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	databaseClient = 0;
	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Query failed! %s", error);
	}

}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(attacker != 0) 
	{
		GetClientEyePosition(attacker, g_fFreezeOrigin[attacker]);
		GetClientEyeAngles(attacker, g_fFreezeAngle[attacker]);
	}
	if(g_bJuggernaut[iClient])
		g_bOnRespawn[iClient] = false;
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
		{
			ChangeClientTeam(iClient, TF_TEAM_RED);
		}
		TF2_SetPlayerClass(iClient, TFClass_Soldier);
		TF2_RegeneratePlayer(iClient);
		TF2_AddCondition(iClient, TFCond_Buffed, 60.0);
	}
	else
	{
		if(iTeam != TF_TEAM_BLU)
			ChangeClientTeam(iClient, TF_TEAM_BLU);
		TF2_SetPlayerClass(iClient, TFClass_Scout);
		TF2_RegeneratePlayer(iClient);
	}
	
	if(g_bOnRespawn[iClient])
		TeleportEntity(iClient, g_fFreezeOrigin[iClient], g_fFreezeAngle[iClient], NULL_VECTOR);
	
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

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new killerId = GetEventInt(event, "attacker");
	new killedId = GetEventInt(event, "userid");
	
	new killer = GetClientOfUserId(killerId);
	new killed = GetClientOfUserId(killedId);
	
	//new Float:RespawnTime = 0.0;
	PrintToServer("Entity #%d", killer);
	if(g_bJuggernaut[killed] && !g_bOnRespawn[killed])
	{
		if (IsClientInGame(killer) && IsPlayerAlive(killer))
		{
			g_iJuggernautsKilled[killer]++;
			g_bJuggernaut[killed] = false;
			g_bJuggernaut[killer] = true;
			
			//Respawn and teleport.
			SetRespawnTime(); //Have to do this since valve likes to reset the TF_GameRules during rounds and map changes
			CreateTimer(0.0, SpawnJuggernautTimer, killer, TIMER_FLAG_NO_MAPCHANGE); //Respawn the player at the specified time
			
			
			SetRespawnTime(); //Have to do this since valve likes to reset the TF_GameRules during rounds and map changes
			CreateTimer(0.0, SpawnPlayerTimer, killed, TIMER_FLAG_NO_MAPCHANGE); //Respawn the player at the specified time
			
			
			decl String:message[128];
			decl String:killerName[64];
			GetClientName(killer, killerName, sizeof(killerName));
			Format(message, sizeof(message), "%c[JG]%c %s is now the Juggernaut! KILL HIM!", cGreen, cDefault, killerName);
			PrintToChatAll(message);
		}
	}
	if(g_bJuggernaut[killer])
	{
		new juggernautHp = GetClientHealth(killer);
		new numScouts = GetTeamClientCount(TF_TEAM_BLU);
		
		SetEntProp(killer, Prop_Data, "m_iHealth", juggernautHp + (10 * numScouts));
		
		SetRespawnTime(); //Have to do this since valve likes to reset the TF_GameRules during rounds and map changes
		CreateTimer(0.0, SpawnPlayerTimer, killed, TIMER_FLAG_NO_MAPCHANGE); //Respawn the player at the specified time
			
		g_iJuggernautKills[killer]++;	
		//Rebuff the juggernaut
		TF2_AddCondition(killer, TFCond_Buffed, 60.0);
	}
	return Plugin_Continue;
}



public Action:SpawnJuggernautTimer(Handle:timer, any:client)
{
     //Respawn the player if he is in game and is dead.
     if(IsClientConnected(client) && IsClientInGame(client))
     {
		g_bOnRespawn[client] = true;
        new PlayerTeam = GetClientTeam(client);
        if( (PlayerTeam == TF_TEAM_BLU) || (PlayerTeam == TF_TEAM_RED) )
        {	
			TF2_RespawnPlayer(client);
        }
     }
     return Plugin_Continue;
} 

public Action:SpawnPlayerTimer(Handle:timer, any:client)
{
     //Respawn the player if he is in game and is dead.
     if(IsClientConnected(client) && IsClientInGame(client) && !IsPlayerAlive(client))
     {
          new PlayerTeam = GetClientTeam(client);
          if( (PlayerTeam == TF_TEAM_BLU) || (PlayerTeam == TF_TEAM_RED) )
          {
			 TF2_RespawnPlayer(client);
          }
     }
     return Plugin_Continue;
} 


public SetRespawnTime()
{
	if (TF2GameRulesEntity != -1)
	{
		new Float:RespawnTimeRedValue = 0.0;
		if (RespawnTimeRedValue >= 6.0) //Added this check for servers setting spawn time to 6 seconds. The -6.0 below would cause instant spawn.
		{
			SetVariantFloat(RespawnTimeRedValue - 6.0); //I subtract 6 to help with getting an exact spawn time since valve adds on time to the spawn wave
		}
		else
		{
			SetVariantFloat(RespawnTimeRedValue);
		}
		AcceptEntityInput(TF2GameRulesEntity, "SetRedTeamRespawnWaveTime", -1, -1, 0);
		
		new Float:RespawnTimeBlueValue = 0.0;
		if (RespawnTimeBlueValue >= 6.0)
		{
			SetVariantFloat(RespawnTimeBlueValue - 6.0); //I subtract 6 to help with getting an exact spawn time since valve adds on time to the spawn wave
		}
		else
		{
			SetVariantFloat(RespawnTimeBlueValue);
		}
		AcceptEntityInput(TF2GameRulesEntity, "SetBlueTeamRespawnWaveTime", -1, -1, 0);
	}
}