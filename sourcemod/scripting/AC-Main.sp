#include <sourcemod>
#include <AC-Helper>

#pragma newdecls required
#pragma semicolon 1

char g_szLogPath[PLATFORM_MAX_PATH]
   , g_szBeepSound[PLATFORM_MAX_PATH];

bool g_bTesting[MAXPLAYERS+1]
   , g_bLowDetection;

public Plugin myinfo = {
  name = "AntiCheat for movement servers",
  author = "hiiamu, zwolof, powerind",
  description = "Main module for cheat detections",
  version = "0.1.0",
  url = "/id/hiiamu/, /id/zwolof/, /id/powerind/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  //CreateNative("AC_Triggered", Native_Triggered); removed unless i need it...
  CreateNative("AC_Trigger", Native_Trigger);
  CreateNative("AC_NotifyAdmins", Native_NotifyAdmins);
  CreateNative("AC_LogToServer", Native_LogToServer);
  CreateNative("AC_IsTesting", Native_IsTesting);

  RegPluginLibrary("AC-Main");
  return APLRes_Success;
}

public void OnPluginStart() {
  RegAdminCmd("sm_testac", Admin_ToggleTest, ADMFLAG_BAN, "Toggles test mode for players");

  BuildPath(Path_SM, g_szLogPath, PLATFORM_MAX_PATH, "logs/AC.log");
}

public void OnMapStart() {
  Handle hConfig = LoadGameConfigFile("funcommands.games");

  if(hConfig == null) {
    SetFailState("Unable to load \"funncommands.games\"");
    return;
  }

  if(GameConfGetKeyValue(hConfig, "SoundBeep", g_szBeepSound, PLATFORM_MAX_PATH))
    PrecacheSound(g_szBeepSound, true);

  delete hConfig;
}

public void OnClientPutInServer(int client) {
  g_bTesting[client] = false;
}

public Action Admin_ToggleTest(int client, int args) {
  g_bTesting[client] = !g_bTesting[client];
  ReplyToCommand(client, "Testing has been %s.", (g_bTesting[client]) ? "enabled":"disabled");

  return Plugin_Handled;
}

public int Native_IsTesting(Handle plugin, int numParams) {
  int client = GetNativeCell(1);

  if(g_bTesting[client])
    return true;
  else
    return false;
}

public int Native_Trigger(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int level = GetNativeCell(2);

  char[] szLevel = new char[16];
  char[] szCheatDesc = new char[32];
  char[] szCheatInfo = new char[300];

  GetNativeString(3, szCheatDesc, 32);
  GetNativeString(4, szCheatInfo, 512);

  if(level == T_LOW) {
    strcopy(szLevel, 16, "LOW");
    g_bLowDetection = true;
  }
  else if(level == T_MED) {
    strcopy(szLevel, 16, "MED");
  }
  else if(level == T_HIGH) {
    strcopy(szLevel, 16, "HIGH");
    if(!AC_IsTesting(client))
      KickClient(client, "[AC] %s", szCheatDesc);
  }
  else if(level == T_DEF) {
    strcopy(szLevel, 16, "DEF");
    if(!AC_IsTesting(client))
      KickClient(client, "[AC] %s", szCheatDesc);
  }

  char[] szAuth = new char[32];
  GetClientAuthId(client, AuthId_Steam3, szAuth, 32);

  char[] szBuffer = new char[128];
  if(!AC_IsTesting(client)) {
    Format(szBuffer, 128, "\x03%N\x01 - \x05%s\x01 Cheat: %s | Level: %s", client, szAuth, szCheatDesc, szLevel);
    LogToFileEx(g_szLogPath, "%L - %s Cheat: %s | Level: %s", client, szAuth, szCheatDesc, szLevel);
    //TODO Notify discord
  }
  else
    Format(szBuffer, 128, "\x03%N\x01 - TEST \x05%s\x01 Cheat: %s | Level: %s", client, szAuth, szCheatDesc, szLevel);

  AC_NotifyAdmins("%s", szBuffer);
  return;
}

public int Native_NotifyAdmins(Handle plugin, int numParams) {
  static int iWritten = 0;

  char[] szBuffer = new char[300];
  FormatNativeString(0, 1, 2, 300, iWritten, szBuffer);

  for(int i = 1; i <= MaxClients; i++) {
    if(CheckCommandAccess(i, "admin", ADMFLAG_GENERIC)) {
      PrintToChat(i, "\07[AC]\01 %s", szBuffer);
      PrintToConsole(i, "[AC] %s", szBuffer);
      if(!g_bLowDetection)
        ClientCommand(i, "play */%s", g_szBeepSound);
    }
  }
  g_bLowDetection = false;
}

public int Native_LogToServer(Handle plugin, int numParams) {
  char[] szPlugin = new char[32];

  if(!GetPluginInfo(plugin, PlInfo_Name, szPlugin, 32)) {
    GetPluginFilename(plugin, szPlugin, 32);
  }

  static int iWritten = 0;

  char[] szBuffer = new char[300];
  FormatNativeString(0, 1, 2, 300, iWritten, szBuffer);
  LogToFileEx(g_szLogPath, "[%s] %s", szPlugin, szBuffer);
}
