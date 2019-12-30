enum {
	T_LOW,
	T_MED,
	T_HIGH,
	T_DEF,
	T_TEST
};

/**
 * Pre hook for detections
 *
 * @param client        Client entity index.
 * @param level         Trigger level, see enum.
 * @param cheatDesc     Short name of the detected cheat.
 * @return              Plugin_Continue to do nothing.
 *                      Plugin_Changed to modify various values.
 *                      Plugin_Handled to not call post hook AC_Trigger.
 *                      Plugin_Stop to ignore trigger fully.
 */
//forward Action AC_Triggered(int client, int &level, char[] cheatDesc);

/**
 * Post hook for detections
 *
 * @param client        Client entity index.
 * @param level         Trigger level, see enum.
 * @param cheatDesc     Short name of the detected cheat.
 * @param cheatInfo     The stats that were detected and assumed cheated.
 * @noreturn
 */
native void AC_Trigger(int client, int level, char[] cheatDesc);

/**
 * Prints a message to admins in chat and console, plays short beep sound.
 *
 * @param format        Formatting things.
 * @param any           Variable number of format parameters.
 * @noreturn
 */
native void AC_NotifyAdmins(const char[] format, any ...);

/**
 * Notify discord webhook
 *
 * @param client        Client entity index.
 * @param level         Trigger level, see enum.
 * @param cheatDesc     Short name of the detected cheat.
 * @param cheatInfo     The stats that were detected and assumed cheated.
 * @noreturn
 */
native void AC_NotifyDiscord(int client, int level, char[] cheatDesc, char[] cheatInfo);

/**
 * Logs detections to specified log file.
 *
 * @param format        Formatting things.
 * @param any           Variable number of format parameters.
 * @noreturn
 */
native void AC_LogToServer(const char[] format, any ...);

/**
 * Enable to not get punished due to detections, everything works as normal besides punishments.
 *
 * @param client        Client entity index.
 * @return              True if no punishments.
 */
native bool AC_IsTesting(int client);

/**
 * Built to not false pos on bad players (tends to happen without this)
 *
 * @param client        Client entity index.
 * @param bestLJ        Short name of best LJ ex. Green, Red, Gold.
 * @return              True if their pb is high enough.
 */
native bool AC_AllowDetect(int client);

/**
 * Check to not false pos while in various states.
 *
 * @param client				Client entity index.
 * @param watrer				Check for water level?
 * @return 						  True if the test passed.
 */
stock bool IsMoveTypeLeagl(int client, bool water = true) {
	MoveType iMoveType = GetEntityMoveType(client);

	return(!water || GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2) &&
				(GetEntityFlags(client) & FL_ATCONTROLS) == 0 &&
				(iMoveType == MOVETYPE_WALK || iMoveType == MOVETYPE_ISOMETRIC || iMoveType == MOVETYPE_LADDER);
}

// handles most the natives
public SharedPlugin __pl_ac = {
	name = "AC-Main",
	file = "AC-Main.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ac_SetNTVOptional() {
	MarkNativeAsOptional("AC_Trigger");
	MarkNativeAsOptional("AC_NotifyAdmins");
	MarkNativeAsOptional("AC_NotifyDiscord");
	MarkNativeAsOptional("AC_LogToServer");
	MarkNativeAsOptional("AC_IsTesting");
}
#endif

// handles if someone can get detected for mouse movements and strafe stats
public SharedPlugin __pl_js = {
	name = "JS-Module",
	file = "JumpStats.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_js_SetNTVOptional() {
	MarkNativeAsOptional("AC_AllowDetect");
}
#endif
