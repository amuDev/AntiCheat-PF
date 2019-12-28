#include <sourcemod>
#include <AC-Main>

#pragma newdecls required
#pragma semicolon 1

#define DESC1 "Too many perfect strafe"
#define DESC2 "Average strafe too close to 0"
#define DESC3 "Perfect Turn Rate"
//#define DESC4 ""

#define SAMPLE_SIZE 35

char g_szLogPath[PLATFORM_MAX_PATH];

int g_iAbsTicks[MAXPLAYERS+1]
  , g_iCurrentStrafe[MAXPLAYERS+1]
  , g_iPerfAngleStreak[MAXPLAYERS+1]
  , g_iPreviousButtons[MAXPLAYERS+1]
  , g_iKeyTransitionTick[MAXPLAYERS+1]
  , g_iAngleTransitionTick[MAXPLAYERS+1]
  , g_iBashTriggerCountdown[MAXPLAYERS+1];

float g_fPreviousAngle[MAXPLAYERS+1]
    , g_fPreviousDeltaAngle[MAXPLAYERS+1]
    , g_fPreviousDeltaAngleAbs[MAXPLAYERS+1]
    , g_fPreviousOptimizedAngle[MAXPLAYERS+1];

bool g_bKeyChanged[MAXPLAYERS+1]
   , g_bLeftThisJump[MAXPLAYERS+1]
   , g_bRightThisJump[MAXPLAYERS+1]
   , g_bDirectionChanged[MAXPLAYERS+1];

ArrayList g_aStrafeHistory[MAXPLAYERS+1]

public Plugin myinfo = {
  name = "AC Strafe module",
  author = "hiiamu",
  description = "strafe mwoduel for AC",
  version = "0.1.0",
  url = "/id/hiiamu"
}

public void OnPluginStart() {
  RegConsoleCmd("sm_strafes", Client_PrintStrafeStats);

  BuildPath(Path_SM, g_szLogPath, PLATFORM_MAX_PATH, "logs/AC-Strafe.log");

  for(int i = 1; i <= MaxClients; i++) {
    if(IsClientInGame(i))
      OnClientPutInServer(i);
  }
}

public void OnClientPutInServer(int client) {
  g_iAbsTicks[client] = 0;
  g_iCurrentStrafe[client] = 0;
  g_iPerfAngleStreak[client] = 0;
  g_iPreviousButtons[client] = 0;
  g_iKeyTransitionTick[client] = 0;
  g_iAngleTransitionTick[client] = 0;
  g_iBashTriggerCountdown[client] = 0;

  g_bKeyChanged[client] = false;
  g_bDirectionChanged[client] = false;

  g_aStrafeHistory[client] = new ArrayList();
}

public void OnClientDisconnect(int client) {
  delete g_aStrafeHistory[client];
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

int GetSamples(int client) {
  if(g_aStrafeHistory[client] == null)
    return 0;

  int iSize = g_aStrafeHistory[client].Length;
  int iEnd = (iSize >= SAMPLE_SIZE) ? (iSize - SAMPLE_SIZE):0;

  return (iSize - iEnd);
}

public Action Client_PrintStrafeStats(int client, int args) {
  if(args < 1) {
    ReplyToCommand(client, "Proper Formatting: sm_strafes <target>");
    return Plugin_Handled;
  }

  char[] szArgs = new char[MAX_TARGET_LENGTH];
  GetCmdArgString(szArgs, MAX_TARGET_LENGTH);

  int target = FindTarget(client, szArgs);

  if(target == -1)
    return Plugin_Handled;

  if(GetSamples(target) == 0) {
    ReplyToCommand(client, "%N does not have any scroll stats.", target);
    return Plugin_Handled;
  }

  char[] szStrafeStats = new char[256];
  FormatStrafes(target, szStrafeStats, 256);

  ReplyToCommand(client, "Strafes for %N: %s", target, szStrafeStats);

  return Plugin_Handled;
}

void FormatStrafes(int client, char[] buffer, int maxlength) {
  FormatEx(buffer, maxlength, "%i samples: {", GetSamples(client));

  int iSize = g_aStrafeHistory[client].Length;
  int iEnd = (iSize >= SAMPLE_SIZE) ? (iSize - SAMPLE_SIZE):0;

  for(int i = iSize - 1; i >= iEnd; i--)
    Format(buffer, maxlength, "%s %d,", buffer, g_aStrafeHistory[client].Get(i));

  int iPos = strlen(buffer) - 1;

  if(buffer[iPos] == ',')
    buffer[iPos] = ' ';

  StrCat(buffer, maxlength, "}");
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]) {
  if(!IsValidClient(client))
    return Plugin_Continue;
  return SetupMove(client, buttons, angles, vel);
}

Action SetupMove(int client, int &buttons, float angles[3], float vel[3]) {
  float fDeltaAngle = angles[1] - g_fPreviousAngle[client];
	g_fPreviousAngle[client] = angles[1];

  if(!IsMoveTypeLeagl(client))
    return Plugin_Continue;

  if(fDeltaAngle > 180.0)
    fDeltaAngle -= 360.0;

  else if(fDeltaAngle < -180.0)
    fDeltaAngle += 360.0;

  float fDeltaAngleAbs = FloatAbs(fDeltaAngle);

  if(fDeltaAngleAbs < 0.015375)
    return Plugin_Continue;

  int iFlags = GetEntityFlags(client);

  // Are they in air?
  if((iFlags & (FL_ONGROUND | FL_INWATER)) == 0) {
    if((buttons & (IN_MOVELEFT | IN_MOVERIGHT)) != (IN_MOVELEFT | IN_MOVERIGHT) &&
       (buttons & (IN_FORWARD | IN_BACK)) != (IN_FORWARD | IN_BACK)) {
      // True sync calculations...
      // not that KZTimer %sync shit
      if(
          // Buttons switch from A to D 
          // Or D to A
          ((((buttons & IN_MOVELEFT) > 0 && (g_iPreviousButtons[client] & IN_MOVELEFT) == 0) ||
          ((buttons & IN_MOVERIGHT) > 0 && (g_iPreviousButtons[client] & IN_MOVERIGHT) == 0)) ||
          ((g_iPreviousButtons[client] & IN_MOVERIGHT) > 0 && (g_iPreviousButtons[client] & IN_MOVELEFT) > 0)) ||

          // Buttons switch from W to S
          // Or S to W
          ((((buttons & IN_FORWARD) > 0 && (g_iPreviousButtons[client] & IN_FORWARD) == 0) ||
          ((buttons & IN_BACK) > 0 && (g_iPreviousButtons[client] & IN_BACK) == 0)) ||
          ((g_iPreviousButtons[client] & IN_BACK) > 0 && (g_iPreviousButtons[client] & IN_FORWARD) > 0))) {
        // sorry for that...
        g_bKeyChanged[client] = true;
        g_iKeyTransitionTick[client] = g_iAbsTicks[client];  
      }
    }

    if(!g_bDirectionChanged[client] &&
        (fDeltaAngleAbs != 0.0 &&
        ((fDeltaAngle < 0.0 && g_fPreviousDeltaAngle[client] > 0.0) ||
        (fDeltaAngle > 0.0 && g_fPreviousDeltaAngle[client] < 0.0) ||
        g_fPreviousDeltaAngleAbs[client] == 0.0))) {
      // i dont like maths in sp

      //g_bDirectionChanged means mouse changed....
      g_bDirectionChanged[client] = true;
      g_iAngleTransitionTick[client] = g_iAbsTicks[client];
    }

    // if client switches key and mouse movement...
    if(g_bKeyChanged[client] && g_bDirectionChanged[client]) {
      //reset bools
      g_bKeyChanged[client] = false;
      g_bDirectionChanged[client] = false;

      int iTick = g_iKeyTransitionTick[client] - g_iAngleTransitionTick[client];

      // Only update array if they are actually syncing their
      // keys and mouse movement
      if(-25 <= iTick <= 25) {
        g_aStrafeHistory[client].Push(iTick);
        g_iCurrentStrafe[client]++;

        if((g_iCurrentStrafe[client] % SAMPLE_SIZE) == 0)
          AnalyzeStats(client);
      }

      if(g_iBashTriggerCountdown[client] > 0)
        g_iBashTriggerCountdown[client]--;
    }

    if((buttons & IN_LEFT) > 0)
      g_bLeftThisJump[client] = true;

    if((buttons & IN_RIGHT) > 0)
      g_bRightThisJump[client] = true;

    if(g_bLeftThisJump[client] && g_bRightThisJump[client]) {
      vel[0] = 0.0;
      vel[1] = 0.0;
    }
  }
  else {
    g_bKeyChanged[client] = false;
    g_bDirectionChanged[client] = false;

    g_bLeftThisJump[client] = false;
    g_bRightThisJump[client] = false;
  }

  float fAbsVelocity[3];
  GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

  float fSpeed = (SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)));

  // i think i did maths wrong here?
  //TODO
  if((FloatAbs(fDeltaAngleAbs - g_fPreviousOptimizedAngle) <= (g_fPreviousOptimizedAngle[client] / 128.0) && fSpeed < 2560.0) {
    if(++g_iPerfAngleStreak[client] == 10)
      AC_Trigger(client, T_LOW, DESC3, "fuck");
    else if(g_iPerfAngleStreak[client] == 30)
      AC_Trigger(client, T_MED, DESC3, "heck");
    else if(g_iPerfAngleStreak[client] == 40)
      AC_Trigger(client, T_HIGH, DESC3, "save me");
    else if(g_iPerfAngleStreak[client] == 50)
      AC_Trigger(client, T_DEF, DESC3, "help");
  }
  else
    g_iPerfAngleStreak[client] = 0;

  g_iPreviousButtons[client] = buttons;
  g_fPreviousOptimizedAngle[client] = ArcSine(30.0 / fSpeed) * 57.29577951308;
  g_fPreviousDeltaAngleAbs[client] = fDeltaAngleAbs;
  g_fPreviousDeltaAngle[client] = fDeltaAngle;

  return Plugin_Continue;
}

void AnalyzeStats(int client) {
  int iTickDifference = 0;
  int iZeroes = 0;

  for(int i = (g_iCurrentStrafe[client] - SAMPLE_SIZE); i < g_iCurrentStrafe[client] - 1; i++) {
    int iTick = Abs(g_aStrafeHistory[client].Get(i));
    iTickDifference += iTick;

    if(iTick == 0)
      iZeroes++;
  }

  if(iTickDifference < 3) {
    AC_Trigger(client, T_DEF, DESC2);
    g_iBashTriggerCountdown[client] = 35;
  }
  else if(iTickDifference < 6) {
    AC_Trigger(client, T_HIGH, DESC2);
    g_iBashTriggerCountdown[client] = 35;
  }
  else if(iTickDifference < 9) {
    AC_Trigger(client, T_MED, DESC2);
    g_iBashTriggerCountdown[client] = 35;
  }
  else if(iTickDifference < 15) {
    AC_Trigger(client, T_LOW, DESC2);
    g_iBashTriggerCountdown[client] = 35;
  }

  if(g_iBashTriggerCountdown[client] > 0) {
    char[] szStrafeStats = new char[256];
    FormatStrafes(client, szStrafeStats, 256);

    AC_NotifyAdmins("%s", szStrafeStats);

    return;
  }

  if(iZeroes > 30) {
    AC_Trigger(client, T_DEF, DESC1, szStrafeStats);
    g_iBashTriggerCountdown[client] = 35;
  }
  
  else if(iZeroes > 27) {
    AC_Trigger(client, T_HIGH, DESC1, szStrafeStats);
    g_iBashTriggerCountdown[client] = 35;
  }
  
  else if(iZeroes > 23) {
    AC_Trigger(client, T_MED, DESC1, szStrafeStats);
    g_iBashTriggerCountdown[client] = 35;
  }
  
  else if(iZeroes > 19) {
    AC_Trigger(client, T_LOW, DESC1, szStrafeStats);
    g_iBashTriggerCountdown[client] = 35;
  }

  if(g_iBashTriggerCountdown[client] > 0) {
    char[] szStrafeStats = new char[256];
    FormatStrafes(client, szStrafeStats, 256);

    AC_NotifyAdmins("%s", szStrafeStats);

    return;
  }
}
