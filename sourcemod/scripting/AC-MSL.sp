#include <sourcemod>
#include <AC-Main>

#pragma newdecls required
#pragma semicolon 1

#define DESC1 "Too many perfect angles"
#define DESC2 "Average angle inhuman"
//#define DESC3 ""

// ticks to sample 
// 98 is 1 jump with no binds/bugs
// 200 is ~2 jumps
#define SAMPLE_SIZE 200

char g_szLogPath[PLATFORM_MAX_PATH];

int g_iCurrentTick[MAXPLAYERS+1]
  , g_iPerfectAng[MAXPLAYERS+1];

ArrayList g_aEyeAngleHistory[MAXPLAYERS+1];

public Plugin myinfo = {
  name = "",
  author = "",
  description = "",
  version = "",
  url = ""
}

public void OnPluginStart() {
  RegConsoleCmd("sm_checkeyes", Client_PrintEyeAngles);

  for(int i = 1; i <= MaxClients; i++) {
    if(IsClientInGame(i))
      OnClientPutInServer(i);
  }
}

public void OnClientPutInServer(int client) {
  g_iCurrentTick[client] = 0;
  g_iPerfectAng[client] = 0;
  g_aEyeAngleHistory[client] = new ArrayList();
}

public void OnClientDisconnect(int client) {
  delete g_aEyeAngleHistory[client];
}

bool OnSurf(int client) {
	float fPosition[3];
	GetClientAbsOrigin(client, fPosition);

	float fEnd[3];
	fEnd = fPosition;
	fEnd[2] -= 64.0;

	float fMins[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", fMins);

	float fMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", fMaxs);

	Handle hTR = TR_TraceHullFilterEx(fPosition, fEnd, fMins, fMaxs, MASK_PLAYERSOLID, TRFilter_NoPlayers, client);

	if(TR_DidHit(hTR)) {
		float fNormal[3];
		TR_GetPlaneNormal(hTR, fNormal);

		delete hTR;

		// If the plane normal's Z axis is 0.7 or below (alternatively, -0.7 when upside-down) then it's a surf ramp.
		// https://mxr.alliedmods.net/hl2sdk-css/source/game/server/physics_main.cpp#1059

		return (-0.7 <= fNormal[2] <= 0.7);
	}

	delete hTR;

	return false;
}

public bool TRFilter_NoPlayers(int entity, int mask, any data) {
	return (entity != view_as<int>(data) || (entity < 1 || entity > MaxClients));
}

int GetEyeAngleSamples(int client) {
  if(g_aEyeAngleHistory[client] == null)
    return 0;

  int iSize = g_aEyeAngleHistory[client].Length;
  int iEnd = (iSize >= SAMPLE_SIZE) ? (iSize - SAMPLE_SIZE):0;

  return (iSize - iEnd);
}

public Action Client_PrintEyeAngles(int client, int args) {
  if(args < 1) {
    ReplyToCommand(client, "Proper Formatting: sm_checkeyes <target>");
    return Plugin_Handled;
  }

  char[] szArgs = new char[MAX_TARGET_LENGTH];
  GetCmdArgString(szArgs, MAX_TARGET_LENGTH);

  int target = FindTarget(client, szArgs);

  if(target == -1)
    return Plugin_Handled;

  if(GetEyeAngleSamples(target) == 0) {
    ReplyToCommand(client, "%N does not have any Eye Angle stats.", target);
    return Plugin_Handled;
  }

  char[] szEyeAngleStats = new char[512];
  FormatEyeAngles(target, szEyeAngleStats, 512);

  ReplyToCommand(client, "Airpath stats for %N: %s", target, szEyeAngleStats);

  return Plugin_Handled;
}

void FormatEyeAngles(int client, char[] buffer, int maxlength) {
  FormatEx(buffer, maxlength, "%i Ticks sampled: {", GetEyeAngleSamples(client));

  int iSize = g_aEyeAngleHistory[client].Length;
  int iEnd = (iSize >= SAMPLE_SIZE) ? (iSize - SAMPLE_SIZE):0;

  for(int i = iSize - 1; i >= iEnd; i--)
    Format(buffer, maxlength, "%s %i,", buffer, g_aEyeAngleHistory[client].Get(i));

  int iPos = strlen(buffer) - 1;

  if(buffer[iPos] == ',')
  	buffer[iPos] = ' ';

	StrCat(buffer, maxlength, "}");
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]) {
  if(!IsValidClient(client))
    return Plugin_Continue;
  return SetupMove(client, angles, vel);
}

Action SetupMove(int client, float eyeAngles[3], float vel[3]) {
  // eyeangles is main detection for MSL
  // if 2 eyeAngles are the same client is probably MSLing
  int iFlags = GetEntityFlags(client);

  // is the client in air?
  if((iFlags & (FL_ONGROUND | FL_INWATER)) == 0) {
    g_aEyeAngleHistory[client].Push(eyeAngles[1]);
    if(g_fPreviousAngle[client] == eyeAngles[1]) {
      AC_Trigger(client, T_MED, DESC1);
      g_iPerfectAng[client]++;
    }
    if(g_iPerfectAng[client] >= 10) {
      AC_Trigger(client, T_HIGH, DESC1);
    }
    else if(g_iPerfectAng[client] >= 25) {
      AC_Trigger(client, T_DEF, DESC1)
    }
  }
  else {
    g_iPerfectAng[client] = 0;
  }
  g_fPreviousAngle[client] = eyeAngles[1];
}
