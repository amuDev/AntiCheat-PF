#include <sourcemod>
#include <AC-Helper>

#pragma newdecls required
#pragma semicolon 1

char ;

int ;

bool ;

Handle ;

public Plugin myinfo = {
  name = "AntiCheat for movement servers",
  author = "hiiamu, zwolof, powerind",
  description = "Main module for cheat detections",
  version = "0.1.0",
  url = "/id/hiiamu/, /id/zwolof/, /id/powerind/"
}

//TODO
/**
 * Maybe dont use Triggered and just use Trigger?
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("AC_Triggered", Native_Triggered);
  CreateNative("AC_Trigger", Native_Trigger);
  CreateNative("AC_NotifyAdmins", Native_NotifyAdmins);
  CreateNative("AC_LogToServer", Native_LogToServer);
  CreateNative("AC_IsTesting", Native_IsTesting);

  RegPluginLibrary("AC-Main");
  return APLRes_Success;
}

public void OnPluginStart() {
  RegAdminCmd("sm_testac", Admin_ToggleTest, ADMFLAG_BAN, "Toggles test mode for players");

  BuildPath(Path_SM, g_szLogPath, PLATFORM_MAX_PATH)
}






















