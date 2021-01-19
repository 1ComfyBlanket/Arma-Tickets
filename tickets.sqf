/////////////////////////////////////////////////////
////Group Ticket Respawning v1.2 by comfy blanket////
/////////////////////////////////////////////////////
/*
1) Download and place "a3g-spectatorcam" into your mission folder.

2) Place the following in your description.ext:
respawn = 3;
respawnDelay = 10;

class RscTitles {
	#include "a3g-spectatorcam\dialog.hpp"
};

class CfgFunctions {
	#include "a3g-spectatorcam\CfgFunctions.hpp"
};

2a) DO NOT ADD THE RESPAWN TEMPLATE FROM a3g-spectatorcam OTHERWISE PLAYERS 
	WILL BE STUCK SPECTATING EVEN IF THEY STILL HAVE LIVES REMAINING
	It should also be noted that you should remove any other custom spectating
	scripts.


3) Place the following in your init: [3,600,50] execVM "scripts\tickets.sqf";
The first value (3) is the amount of lives each player has.
The second value (600) is the group respawn timer in seconds.
The third value (50) is how far they can go from where they respawn while waiting
for the respawn timer to finish.

4) Place a "respawn_west" marker or any other faction respawn marker into your mission.
   There isn't much for TvT compatability right now. Everyone is put in the same timer
   pool regardless as side and the reinforcements counter just includes both sides.
   This does not determine their respawn area, they respawn where they first started
   in the mission.
 
Note: You can technically use another spectating script or the vanilla one. Change the
	  installation steps accordingly.

The group respawn means every dead player will respawn at the same time.
The first person to die will start the timer, i.e. 600 seconds. Anyone
who dies after will have their spawn timer synced with the server. When players
are respawned it resets back to whatever your timer is set to, i.e. 600 seconds.
Players cannot spectate until they lose all their lives and are permanently dead.

If a player crashes or rejoins their lives counter won't change. If they crash
or leave while they were already dead, they'll spawn back in dead. There's no
way around it. Lives and the respawn timer are synced to the server.
*/

if (!isDedicated && !hasInterface) exitWith {};

// Put commands that need to be executed on respawn inside this function.
GTR_onRespawn_fnc = {
	// Load inventory on respawn, remove this if you want them with their default gear.
	[player, [missionNamespace, "inv"]] call BIS_fnc_loadInventory;
	
	//player addAction ["<t color='#00CD66'>Open Arsenal</t>", {["Open",false] spawn custom_fnc_arsenal}, nil, 10, false, true, "", "_this distance arsenal_zone < 150 && vehicle player == player"];
};











//////////////////////////////////////////////////////////////////////////
// Don't touch anything below this line unless you know what you're doing.
//////////////////////////////////////////////////////////////////////////

GTR_tickets = _this select 0;
GTR_respawnDelay = _this select 1;
GTR_maxDistance = _this select 2;

// Timer function for group wave respawning
GTR_AkpTime_fnc = {      
	_timer = _this select 0;
	private ["_color","_min","_sec","_sleep","_layer","_lives"];
	_layer = "TicketTimer" call bis_fnc_rscLayer;
	GTR_AkpTime = _timer;
	if !(isServer) then {
		"AkpServerTime" addPublicVariableEventHandler {GTR_AkpTime = AkpServerTime};
	};
	_color = "#FFFFFF";
	_lives = "";
	if (!isDedicated) then {
		if (missionNamespace getVariable [GTR_player_tickets, 0] == 1) then {_lives = "LIFE"} else {_lives = "LIVES"};
	};
	while {GTR_AkpTime >= 0} do {
		_min = floor (GTR_AkpTime / 60);
		_sec = floor (GTR_AkpTime % 60);
		if (_sec < 10) then {_sec = "0" + str _sec};
		if (GTR_AkpTime <= 10) then {
			_sleep = 0.2;
			_color = if (_color=="#FFFFFF") then {"#FF0000"} else {"#FFFFFF"};
		} else {
			_sleep = 1;
		};
		[
			format ["<t size='0.9' shadow='1' color='%1'>%4 %5 REMAINING<br/>Respawn in: %2:%3",_color,_min,_sec, missionNamespace getVariable [GTR_player_tickets, 3], _lives],
			0,
			safezoneY + 0.9 * safezoneH,
			2,
			0,
			0,
			_layer
		] spawn bis_fnc_dynamicText;
		if (isServer) then {
			{
				_x setMarkerText (format [" Reinforcements in: %1:%2", _min, _sec]);
			} forEach ["respawn_west","respawn_east","respawn_guerrila","respawn_civilian"];
		};
		GTR_AkpTime = GTR_AkpTime - _sleep;
		uiSleep _sleep;
	};
};

// Server loop for handling dead players
if (isServer) then {
	[] spawn {
		while {true} do {
			GTR_dead_players = [];
			
			waitUntil {sleep 1; count GTR_dead_players > 0};
			
			// Respawn length in seconds
			[GTR_respawnDelay] spawn GTR_AkpTime_fnc;
			
			waitUntil {!isNil "GTR_AkpTime" && {GTR_AkpTime > 0}};
			
			waitUntil {
				{
					[[GTR_AkpTime], "GTR_AkpTime_fnc", _x] call BIS_fnc_MP;
					GTR_dead_players = GTR_dead_players - [_x];
				} forEach GTR_dead_players;
				sleep 1;
				GTR_AkpTime <= 0
			};
		};
	};
};

// Players need to exist before it can check for their UID
if (isDedicated) exitWith {};
waitUntil {!isNull player};
sleep 1;

spawning_pos = getPosATL player;

// Don't allow the "dead" to leave their spawn area.
GTR_SpawnZone_fnc = {
	if (player distance _pos > GTR_maxDistance) then {
		player setPosATL _pos;
		hint "You're still respawning.";
	};
	if (vehicle player != player) then {
		player action ["GetOut", vehicle player];
		hint "You're still respawning.";
	};
};

// Handles players as they're in the respawning state
GTR_PlayerRespawning_fnc = {
	waitUntil {alive player};
	
	if !(player getVariable ["JustJoined",false]) then {
		[] spawn GTR_onRespawn_fnc;
	};
	player setVariable ["JustJoined",false];
	
	while {(getPosATL player) distance spawning_pos > 10} do {
		player setPosATL spawning_pos;
		sleep 0.1;
	};
	
	player allowDamage false;
	
	if (missionNamespace getVariable [GTR_player_status, 1] == 1) then {
		waitUntil {!isNil "GTR_AkpTime"};
		
		sleep 5;
		
		_pos = getPosATL player;
		waitUntil {
			call GTR_SpawnZone_fnc;
			sleep 1;
			GTR_AkpTime <= 0
		};
	} else {
		// Player is permanently dead. Put them into spectator mode.
		sleep 2;
		_layer = "GTR_AkpTimer" call bis_fnc_rscLayer;
		[
			format ["<t size='0.9' shadow='1' color='#FFFFFF'>0 LIVES REMAINING<br/>YOU ARE PERMANENTLY DEAD"],
			0,
			safezoneY + 0.9 * safezoneH,
			10,
			0,
			0,
			_layer
		] spawn bis_fnc_dynamicText;
		[player] execVM "a3g-spectatorcam\initCam.sqf";
		
		player playMove "AinjPpneMstpSnonWrflDnon_rolltoback";
		
		// Don't allow them to leave their spawn area.
		_pos = getPosATL player;
		while {missionNamespace getVariable [GTR_player_status, 1] == 2} do {
			call GTR_SpawnZone_fnc;
			sleep 1;
		};
	};
	
	// Reset state back to alive.
	missionNamespace setVariable [GTR_player_status, 0, true];
	player allowDamage true;
};

GTR_player_tickets = format ["GTR_tickets_%1", getPlayerUID player];
GTR_player_status = format ["GTR_alive_%1", getPlayerUID player];	// GTR_player_status: 0 = alive, 1 = respawning, 2 = no lives permanently dead

// If the player reslotted and they were dead beforehand they are put back into respawning. Should not affect players who crashed.
if (missionNamespace getVariable [GTR_player_status, 0] > 0) then {
	player setVariable ["JustJoined",true];
	[] spawn GTR_PlayerRespawning_fnc;
};

player addEventHandler ["Killed", {

	// Prevent this event handler from running twice when killed by another unit.
	if (missionNamespace getVariable [GTR_player_status, 0] == 0) then {
		// Amount of lives per player
		_lives = missionNamespace getVariable [GTR_player_tickets, GTR_tickets];
		_lives = _lives - 1;
		missionNamespace setVariable [GTR_player_tickets, _lives, true];
			
		missionNamespace setVariable [GTR_player_tickets, _lives, true];
		
		if (missionNamespace getVariable [GTR_player_tickets, 3] <= 0) then {
			missionNamespace setVariable [GTR_player_status, 2, true];
		} else {
			missionNamespace setVariable [GTR_player_status, 1, true];
			if (!isServer) then {
				[[[player], {GTR_dead_players pushBack (_this select 0)}], "BIS_fnc_spawn", false] call BIS_fnc_MP;
			};
		};
	};
	
	[player, [missionNamespace, "inv"]] call BIS_fnc_saveInventory;
	
	[] spawn GTR_PlayerRespawning_fnc;
}];
