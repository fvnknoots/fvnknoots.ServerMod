//------------------------------------------------------------------------------
// disclaimer: shamelessly stolen code from takyon and karma
//------------------------------------------------------------------------------

global function fm_Init

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
const int NOMAX = 9999

#if NETLIB
const int NL_CIDR = 20
#endif

const int C_SILENT   = 1 << 0
const int C_ADMIN    = 1 << 1
const int C_FORCE    = 1 << 2
const int C_ADMINARG = 1 << 3

struct CommandInfo {
    array<string> names
    bool functionref(entity, array<string>) fn
    int minArgs,
    int maxArgs
    string usage,
    string adminUsage,
    int flags
}

const int PS_MODIFIERS = 1 << 0
const int PS_ALIVE     = 1 << 1

enum PlayerSearchResultKind {
    DEAD      = -3,
    NOT_FOUND = -2,
    MULTIPLE  = -1,
    SINGLE    =  0,
    ALL       =  1,
    US        =  2,
    THEM      =  3
}

enum MapRotation {
    LINEAR = 0,
    RANDOM = 1
}

struct PlayerSearchResult {
    int kind
    array<entity> players
}

struct KickInfo {
    array<entity> voters
    int threshold
}

struct PlayerScore {
    entity player
    float val
}

struct NextMapScore {
    string map
    int votes
}

struct CustomCommand {
    string name
    array<string> lines
}

struct {
    bool debugEnabled

    array<string> adminUids
    bool adminAuthEnabled
    string adminPassword
    array<string> authenticatedAdmins
    bool adminAuthUnauthChatBlock
    bool adminJoinNotification

    array<CommandInfo> commands

    bool welcomeEnabled
    string welcome
    array<string> welcomeNotes
    array<string> welcomedPlayers

    bool rulesEnabled
    string rulesOk
    string rulesNotOk

    bool kickEnabled
    bool kickSave
    float kickPercentage
    int kickMinPlayers
    table<string, KickInfo> kickTable
    array<string> kickedPlayers
    array<string> kickedNetworks
    
    bool mapsEnabled
    array<string> maps
    int mapRotation
    bool nextMapEnabled
    array<string> nextMapOnlyMaps
    int nextMapOnlyMapsMaxPlayers
    table<entity, string> nextMapVoteTable
    bool nextMapHintEnabled
    array<string> nextMapHintedPlayers
    bool nextMapRepeatEnabled

    bool switchEnabled
    int switchDiff
    int switchLimit
    bool switchKill
    table<string, int> switchCountTable

    bool balanceEnabled
    float balancePercentage
    int balanceMinPlayers
    int balanceThreshold
    array<entity> balanceVoters
    bool balancePostmatch

    bool autobalanceEnabled
    int autobalanceDiff
    array<entity> autobalancePlayerQueue

    bool extendEnabled
    float extendPercentage
    int extendMinutes
    int extendThreshold
    array<entity> extendVoters

    bool skipEnabled
    float skipPercentage
    int skipThreshold
    array<entity> skipVoters

    bool rollEnabled
    int rollLimit
    table<string, int> rollCountTable

    bool muteEnabled
    bool muteSave
    array<string> mutedPlayers

    bool lockdownEnabled
    bool isLockdown

    bool killstreakEnabled
    int killstreakIncrement
    table<string, int> playerKillstreaks

    bool yellEnabled
    bool slayEnabled
    bool freezeEnabled
    bool stimEnabled
    bool salvoEnabled
    bool tankEnabled
    bool flyEnabled
    bool mrvnEnabled
    bool gruntEnabled

    bool chaosEnabled

    bool jokePitfallsEnabled
    table<string, int> pitfallTable

    bool jokeMarvinEnabled
    bool jokeDroneEnabled
    bool jokeKillsEnabled
    bool jokeEzfragsEnabled

    bool customCommandsEnabled
    array<CustomCommand> customCommands

    bool antispamEnabled
    int antispamPeriod
    int antispamLimit
    table< entity, array<float> > playerMessageTimes

    bool chatMentionEnabled

    array<CustomCommand> retouchedCommands
    CustomCommand gymModeCommand
} file

//------------------------------------------------------------------------------
// init
//------------------------------------------------------------------------------
void function fm_Init() {
    file.debugEnabled = GetConVarBool("fm_debug_enabled")

    // admins
    array<string> adminUids = split(GetConVarString("fm_admin_uids"), ",")
    foreach (string uid in adminUids) {
        file.adminUids.append(strip(uid))
    }
    file.adminAuthEnabled = GetConVarBool("fm_admin_auth_enabled")
    file.adminPassword = GetConVarString("fm_admin_password")
    file.authenticatedAdmins = []
    file.adminAuthUnauthChatBlock = GetConVarBool("fm_admin_auth_unauth_chat_block")
    file.adminJoinNotification = GetConVarBool("fm_admin_join_notification")

    // welcome
    file.welcomeEnabled = GetConVarBool("fm_welcome_enabled")
    file.welcome = GetConVarString("fm_welcome")
    file.welcomeNotes = []
    array<string> welcomeNotes = split(GetConVarString("fm_welcome_notes"), "|")
    foreach (string welcomeNote in welcomeNotes) {
        file.welcomeNotes.append(strip(welcomeNote))
    }
    file.welcomedPlayers = []

    // rules
    file.rulesEnabled = GetConVarBool("fm_rules_enabled")
    file.rulesOk = GetConVarString("fm_rules_ok")
    file.rulesNotOk = GetConVarString("fm_rules_not_ok")

    // kick
    file.kickEnabled = GetConVarBool("fm_kick_enabled")
    file.kickSave = GetConVarBool("fm_kick_save")
    file.kickPercentage = GetConVarFloat("fm_kick_percentage")
    file.kickMinPlayers = GetConVarInt("fm_kick_min_players")
    file.kickTable = {}
    file.kickedPlayers = []
    file.kickedNetworks = []

    // maps
    file.mapsEnabled = GetConVarBool("fm_maps_enabled")
    file.mapRotation = GetConVarInt("fm_map_rotation")
    if (file.mapRotation < MapRotation.LINEAR || file.mapRotation > MapRotation.RANDOM) {
        string msg = format("ignoring invalid map rotation %d, defaulting to linear (0)", file.mapRotation)
        Log(msg)
        file.mapRotation = MapRotation.LINEAR
    }

    file.maps = []
    array<string> maps = split(GetConVarString("fm_maps"), ",")
    foreach (string dirtyMap in maps) {
        string map = strip(dirtyMap)
        if (!IsValidMap(map)) {
            Log("ignoring invalid map '" + map + "'")
            continue
        }

        file.maps.append(map)
    }
    file.nextMapEnabled = GetConVarBool("fm_nextmap_enabled")
    file.nextMapOnlyMaps = []
    file.nextMapOnlyMapsMaxPlayers = GetConVarInt("fm_nextmap_only_maps_max_players")
    file.nextMapVoteTable = {}
    file.nextMapHintEnabled = GetConVarBool("fm_nextmap_hint_enabled")
    file.nextMapHintedPlayers = []
    file.nextMapRepeatEnabled = GetConVarBool("fm_nextmap_repeat_enabled")

    array<string> nextMapOnlyMaps = split(GetConVarString("fm_nextmap_only_maps"), ",")
    foreach (string dirtyMap in nextMapOnlyMaps) {
        string map = strip(dirtyMap)
        if (!IsValidMap(map)) {
            Log("ignoring invalid map '" + map + "'")
            continue
        }

        file.nextMapOnlyMaps.append(map)
    }

    // switch
    file.switchEnabled = GetConVarBool("fm_switch_enabled")
    file.switchDiff = GetConVarInt("fm_switch_diff")
    file.switchLimit = GetConVarInt("fm_switch_limit")
    file.switchKill = GetConVarBool("fm_switch_kill")
    file.switchCountTable = {}

    // balance
    file.balanceEnabled = GetConVarBool("fm_balance_enabled")
    file.balancePercentage = GetConVarFloat("fm_balance_percentage")
    file.balanceMinPlayers = GetConVarInt("fm_balance_min_players")
    file.balanceThreshold = 0
    file.balanceVoters = []
    file.balancePostmatch = GetConVarBool("fm_balance_postmatch")

    // autobalance
    file.autobalanceEnabled = GetConVarBool("fm_autobalance_enabled")
    file.autobalanceDiff = GetConVarInt("fm_autobalance_diff")
    file.autobalancePlayerQueue = []

    // extend
    file.extendEnabled = GetConVarBool("fm_extend_enabled")
    file.extendPercentage = GetConVarFloat("fm_extend_percentage")
    file.extendMinutes = GetConVarInt("fm_extend_minutes")
    file.extendThreshold = 0
    file.extendVoters = []

    // skip
    file.skipEnabled = GetConVarBool("fm_skip_enabled")
    file.skipPercentage = GetConVarFloat("fm_skip_percentage")
    file.skipVoters = []

    // roll
    file.rollEnabled = GetConVarBool("fm_roll_enabled")
    file.rollLimit = GetConVarInt("fm_roll_limit")
    file.rollCountTable = {}

    // admin commands
    file.muteEnabled = GetConVarBool("fm_mute_enabled")
    file.muteSave = GetConVarBool("fm_mute_save")
    file.mutedPlayers = []

    file.lockdownEnabled = GetConVarBool("fm_lockdown_enabled")

    file.yellEnabled = GetConVarBool("fm_yell_enabled")
    file.slayEnabled = GetConVarBool("fm_slay_enabled")
    file.freezeEnabled = GetConVarBool("fm_freeze_enabled")
    file.stimEnabled = GetConVarBool("fm_stim_enabled")
    file.salvoEnabled = GetConVarBool("fm_salvo_enabled")
    file.tankEnabled = GetConVarBool("fm_tank_enabled")
    file.flyEnabled = GetConVarBool("fm_fly_enabled")
    file.mrvnEnabled = GetConVarBool("fm_mrvn_enabled")
    file.gruntEnabled = GetConVarBool("fm_grunt_enabled")
    file.chaosEnabled = GetConVarBool("fm_chaos_enabled")

    // player experience
    file.killstreakEnabled = GetConVarBool("fm_killstreak_enabled")
    file.killstreakIncrement = GetConVarInt("fm_killstreak_increment")
    file.playerKillstreaks = {}

    // jokes
    file.jokePitfallsEnabled = GetConVarBool("fm_joke_pitfalls_enabled")
    file.pitfallTable = {}

    file.jokeMarvinEnabled = GetConVarBool("fm_joke_marvin_enabled")
    file.jokeDroneEnabled = GetConVarBool("fm_joke_drone_enabled")
    file.jokeKillsEnabled = GetConVarBool("fm_joke_kills_enabled")
    file.jokeEzfragsEnabled = GetConVarBool("fm_joke_ezfrags_enabled")

    // misc
    file.antispamEnabled = GetConVarBool("fm_antispam_enabled")
    file.antispamPeriod = GetConVarInt("fm_antispam_period")
    file.antispamLimit = GetConVarInt("fm_antispam_limit")
    file.playerMessageTimes = {}

    file.chatMentionEnabled = GetConVarBool("fm_chat_mention_enabled")

    // define commands
    CommandInfo cmdHelp = NewCommandInfo(
        ["!help"],
        CommandHelp,
        0, 0,
        "!help => get help", ""
    )

    CommandInfo cmdRules = NewCommandInfo(
        ["!rules"],
        CommandRules,
        0, 0,
        "!rules => show rules", ""
    )

    CommandInfo cmdKick = NewCommandInfo(
        ["!kick"],
        CommandKick,
        1, 1,
        "!kick <full or partial player name> => vote to kick a player",
        "!kick <full or partial player name> (force) => vote to kick a player (or force)",
        C_FORCE
    )

    CommandInfo cmdMaps = NewCommandInfo(
        ["!maps"],
        CommandMaps,
        0, 0,
        "!maps => list available maps", ""
    )

    CommandInfo cmdNextMap = NewCommandInfo(
        ["!nextmap", "!nm"],
        CommandNextMap,
        1, 3,
        "!nextmap/!nm <full or partial map name> => vote for next map", ""
    )

    CommandInfo cmdSwitch = NewCommandInfo(
        ["!switch", "!sw"],
        CommandSwitch,
        0, 0,
        "!switch/!sw => join opposite team",
        "!switch/!sw (player) => join opposite team (or switch another player)",
        C_ADMINARG
    )

    CommandInfo cmdBalance = NewCommandInfo(
        ["!teambalance", "!tb"],
        CommandBalance,
        0, 0,
        "!teambalance/!tb => vote for team balance",
        "!teambalance/!tb (force) => vote for team balance (or force)",
        C_FORCE
    )

    CommandInfo cmdExtend = NewCommandInfo(
        ["!extend", "!ex"],
        CommandExtend,
        0, 0,
        "!extend/!ex => vote to extend map time",
        "!extend/!ex (force) => vote to extend map time (or force)",
        C_FORCE
    )

    CommandInfo cmdSkip = NewCommandInfo(
        ["!skip"],
        CommandSkip,
        0, 0,
        "!skip => vote to skip current map",
        "!skip (force) => vote to skip current map (or force)",
        C_FORCE
    )

    CommandInfo cmdRoll = NewCommandInfo(
        ["!roll"],  
        CommandRoll,
        0, 0,
        "!roll => roll a number between 0 and 100", ""
    )

    // admin commands
    CommandInfo cmdAuth = NewCommandInfo(
        ["!auth"],
        CommandAuth,
        1, 1,
        "!auth <password> => authenticate yourself as an admin", "",
        C_ADMIN | C_SILENT
    )

    CommandInfo cmdMute = NewCommandInfo(
        ["!mute"],
        CommandMute,
        1, 1,
        "!mute <full or partial player name> => mute a player", "",
        C_ADMIN
    )

    CommandInfo cmdUnmute = NewCommandInfo(
        ["!unmute"],
        CommandUnmute,
        1, 1,
        "!unmute <full or partial player name> => unmute a player", "",
        C_ADMIN
    )

    CommandInfo cmdLockdown = NewCommandInfo(
        ["!lockdown"],
        CommandLockdown,
        0, 0,
        "!lockdown => prevent new players from joining", "",
        C_ADMIN
    )

    CommandInfo cmdUnlockdown = NewCommandInfo(
        ["!unlockdown"],
        CommandUnlockdown,
        0, 0,
        "!unlockdown => allow new players to join", "",
        C_ADMIN
    )

    CommandInfo cmdYell = NewCommandInfo(
        ["!yell"],  
        CommandYell,
        1, NOMAX,
        "!yell ... => yell something", "",
        C_ADMIN | C_SILENT
    )

    CommandInfo cmdSlay = NewCommandInfo(
        ["!slay"],
        CommandSlay,
        1, 1,
        "!slay <player | all | us | them> => slay players", "",
        C_ADMIN
    )

    CommandInfo cmdFreeze = NewCommandInfo(
        ["!freeze"],
        CommandFreeze,
        1, 1,
        "!freeze <player | all | us | them> => freeze players", "",
        C_ADMIN
    )

    CommandInfo cmdStim = NewCommandInfo(
        ["!stim"],
        CommandStim,
        1, 1,
        "!stim <player | all | us | them> => give stim", "",
        C_ADMIN
    )

    CommandInfo cmdSalvo = NewCommandInfo(
        ["!salvo"],
        CommandSalvo,
        1, 1,
        "!salvo <player | all | us | them> => give flight core", "",
        C_ADMIN
    )

    CommandInfo cmdTank = NewCommandInfo(
        ["!tank"],
        CommandTank,
        1, 1,
        "!tank <player | all | us | them> => make tanky", "",
        C_ADMIN
    )

    CommandInfo cmdFly = NewCommandInfo(
        ["!fly"],
        CommandFly,
        1, 1,
        "!fly <player | all | us | them> => make floaty", "",
        C_ADMIN
    )

    CommandInfo cmdUnfly = NewCommandInfo(
        ["!unfly"],
        CommandUnfly,
        1, 1,
        "!unfly <player | all | us | them> => make not floaty", "",
        C_ADMIN
    )

    CommandInfo cmdMrvn = NewCommandInfo(
        ["!mrvn"],
        CommandMrvn,
        0, 0,
        "!mrvn => spawn a marvin", "",
        C_ADMIN
    )

    CommandInfo cmdGrunt = NewCommandInfo(
        ["!grunt"],
        CommandGrunt,
        0, 1,
        "!grunt [player name] => spawn a grunt", "",
        C_ADMIN
    )

    CommandInfo cmdChaos = NewCommandInfo(
        ["!chaos"],
        CommandChaos,
        0, 0,
        "!chaos => chaos", "",
        C_ADMIN
    )

    // add commands and callbacks based on convars
    if (file.adminAuthEnabled) {
        file.commands.append(cmdAuth)
        AddCallback_OnClientDisconnected(Admin_OnClientDisconnected)
    }

    if (file.adminJoinNotification) {
        AddCallback_OnClientConnected(AdminJoinNotify_OnClientConnected)
    }

    if (file.welcomeEnabled) {
        AddCallback_OnPlayerRespawned(Welcome_OnPlayerRespawned)
        AddCallback_OnClientDisconnected(Welcome_OnClientDisconnected)
    }

    file.commands.append(cmdHelp)

    if (file.rulesEnabled) {
        file.commands.append(cmdRules)
    }

    if (file.kickEnabled) {
        file.commands.append(cmdKick)
        AddCallback_OnClientConnected(Kick_Callback)
        AddCallback_OnPlayerRespawned(Kick_Callback)
        AddCallback_OnPlayerKilled(Kick_OnPlayerKilled)
        AddCallback_OnClientDisconnected(Kick_OnClientDisconnected)
    }

    int totalMaps = file.maps.len() + file.nextMapOnlyMaps.len()
    if (totalMaps > 0) {
        AddCallback_GameStateEnter(eGameState.Postmatch, PostmatchChangeMap)
    }

    if (file.mapsEnabled && totalMaps > 1) {
        file.commands.append(cmdMaps)
        if (file.nextMapEnabled) {
            file.commands.append(cmdNextMap)
            AddCallback_GameStateEnter(eGameState.WinnerDetermined, NextMap_OnWinnerDetermined)
            AddCallback_OnClientDisconnected(NextMap_OnClientDisconnected)
            if (file.nextMapHintEnabled) {
                AddCallback_OnPlayerRespawned(NextMapHint_OnPlayerRespawned)
            }
        }
    }

    if (file.switchEnabled && !IsFFAGame()) {
        file.commands.append(cmdSwitch)
    }

    if (file.balanceEnabled && !IsFFAGame()) {
        file.commands.append(cmdBalance)
        AddCallback_OnClientDisconnected(Balance_OnClientDisconnected)
    }

    if (file.balancePostmatch && !IsFFAGame()) {
        AddCallback_GameStateEnter(eGameState.Postmatch, Balance_Postmatch)
    }

    if (file.autobalanceEnabled && !IsFFAGame()) {
        AddCallback_GameStateEnter(eGameState.Playing, Autobalance_Start)
        AddCallback_OnClientConnected(Autobalance_OnClientConnected)
        AddCallback_OnClientDisconnected(Autobalance_OnClientDisconnected)
    }

    if (file.extendEnabled) {
        file.commands.append(cmdExtend)
        AddCallback_OnClientDisconnected(Extend_OnClientDisconnected)
    }

    if (file.skipEnabled && totalMaps > 1) {
        file.commands.append(cmdSkip)
        AddCallback_OnClientDisconnected(Skip_OnClientDisconnected)
    }

    if (file.muteEnabled) {
        file.commands.append(cmdMute)
        file.commands.append(cmdUnmute)
        if (!file.muteSave) {
            AddCallback_OnClientDisconnected(Mute_OnClientDisconnected)
        }
    }

    if (file.lockdownEnabled) {
        file.commands.append(cmdLockdown)
        file.commands.append(cmdUnlockdown)
        AddCallback_OnClientConnected(Lockdown_OnPlayerConnected)
    }

    if (file.yellEnabled) {
        file.commands.append(cmdYell)
    }

    if (file.slayEnabled) {
        file.commands.append(cmdSlay)
    }

    if (file.freezeEnabled) {
        file.commands.append(cmdFreeze)
    }

    if (file.stimEnabled) {
        file.commands.append(cmdStim)
    }

    if (file.salvoEnabled) {
        file.commands.append(cmdSalvo)
    }

    if (file.tankEnabled) {
        file.commands.append(cmdTank)
    }

    if (file.flyEnabled) {
        file.commands.append(cmdFly)
        file.commands.append(cmdUnfly)
    }

    if (file.mrvnEnabled) {
        file.commands.append(cmdMrvn)
    }

    if (file.gruntEnabled) {
        file.commands.append(cmdGrunt)
    }

    if (file.chaosEnabled) {
        file.commands.append(cmdChaos)
    }

    if (file.rollEnabled) {
        file.commands.append(cmdRoll)
    }

    if (file.killstreakEnabled) {
        AddCallback_OnPlayerKilled(Killstreak_OnPlayerKilled)
    }

    if (file.jokePitfallsEnabled) {
        AddCallback_OnPlayerKilled(Pitfalls_OnPlayerKilled)
    }

    if (file.jokeMarvinEnabled) {
        AddDeathCallback("npc_marvin", Marvin_DeathCallback)
    }

    if (file.jokeDroneEnabled) {
        AddDeathCallback("npc_drone", Drone_DeathCallback)
    }

    if (file.jokeKillsEnabled) {
        AddCallback_OnPlayerKilled(JokeKills_OnPlayerKilled)
    }

    // custom commands
    file.customCommandsEnabled = GetConVarBool("fm_custom_commands_enabled")
    file.customCommands = []
    if (file.customCommandsEnabled) {
        string customCommands = GetConVarString("fm_custom_commands")
        array<string> entries = split(customCommands, "|")
        foreach (string entry in entries) {
            array<string> pair = split(entry, "=")
            if (pair.len() != 2) {
                Log("ignoring invalid custom command: " + entry)
                continue
            }

            CustomCommand command
            command.name = pair[0]
            command.lines = [] 
            command.lines.append(pair[1])
            file.customCommands.append(command)
        }
    }

    // gym mode integration
#if GYMMODE
    file.gymModeCommand.name = "!gym"
    file.gymModeCommand.lines = GymMode_Changes()
#endif

    // retouched integration
    file.retouchedCommands = []
#if RETOUCHED
    foreach (array<string> changes in RETOUCHED_CHANGELIST) {
        CustomCommand c
        c.name = "!" + changes[0].tolower()
        for (int i = 1; i < changes.len(); i++) {
            c.lines.append(changes[i].tolower())
        }
        file.retouchedCommands.append(c)
    }
#endif

    // the beef
    if (file.jokeEzfragsEnabled) {
        AddCallback_OnReceivedSayTextMessage(EzfragsCallback)
    }

    AddCallback_OnReceivedSayTextMessage(ChatCallback)

    if (file.antispamEnabled) {
        AddCallback_OnReceivedSayTextMessage(AntispamCallback)
    }

    if (file.chatMentionEnabled) {
        AddCallback_OnReceivedSayTextMessage(ChatMentionCallback)
    }
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
CommandInfo function NewCommandInfo(
    array<string> names,
    bool functionref(entity, array<string>) fn,
    int minArgs, int maxArgs,
    string usage, string adminUsage,
    int flags = 0x0
) {
    CommandInfo commandInfo
    commandInfo.names = names
    commandInfo.fn = fn
    commandInfo.minArgs = minArgs
    commandInfo.maxArgs = maxArgs
    commandInfo.usage = usage
    commandInfo.adminUsage = adminUsage
    commandInfo.flags = flags
    return commandInfo
}

// spaghetti bolognese
ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    if (IsLobby()) {
        return messageInfo
    }

    entity player = messageInfo.player
    string message = strip(messageInfo.message)
    array<string> args = split(message, " ")

    // fuzz check
    if (args.len() == 0) {
        messageInfo.shouldBlock = true
        return messageInfo
    }

    string command = args[0].tolower()
    args.remove(0)

    // prevent spoofers from pretending to be admins
    if (file.adminAuthEnabled && file.adminAuthUnauthChatBlock && IsNonAuthenticatedAdmin(player) && command != "!auth") {
        SendMessage(player, ErrorColor("authenticate first"))
        messageInfo.shouldBlock = true
        return messageInfo
    }

    bool isCommand = format("%c", message[0]) == "!"
    if (!isCommand) {
        // prevent mewn from leaking the admin password
        if (file.adminAuthEnabled && IsAdmin(player) && message.tolower().find(file.adminPassword.tolower()) != null) {
            SendMessage(player, ErrorColor("learn to type, mewn"))
            messageInfo.shouldBlock = true
        }

        if (file.mutedPlayers.contains(player.GetUID())) {
            Log("[ChatCallback] muted message from " + player.GetPlayerName() + ": " + messageInfo.message)
            SendMessage(player, ErrorColor("you are muted"))
            messageInfo.shouldBlock = true
        }

        return messageInfo
    }

    foreach (CustomCommand c in file.customCommands) {
        if (c.name == command) {
            foreach (string line in c.lines) {
                SendMessage(player, PrivateColor(line))
            }

            return messageInfo
        }
    }

#if GYMMODE
    if (command == "!gym") {
        foreach (string line in file.gymModeCommand.lines) {
            SendMessage(player, PrivateColor(line))
        }

        return messageInfo
    }
#endif

#if RETOUCHED
    foreach (CustomCommand c in file.retouchedCommands) {
        if (c.name == command) {
            foreach (string line in c.lines) {
                SendMessage(player, PrivateColor(line))
            }

            return messageInfo
        }
    }
#endif

    bool commandFound = false
    bool commandSuccess = false
    foreach (CommandInfo c in file.commands) {
        if (!c.names.contains(command)) {
            continue
        }

        bool isAdminCmd = (c.flags & C_ADMIN) > 0
        if (isAdminCmd && !IsAdmin(player)) {
            break
        }

        commandFound = true

        bool isSilentCmd = (c.flags & C_SILENT) > 0
        messageInfo.shouldBlock = isSilentCmd

        if (isAdminCmd && IsNonAuthenticatedAdmin(player) && command != "!auth") {
            SendMessage(player, ErrorColor("authenticate first"))
            commandSuccess = false
            break
        }

        int maxArgs = c.maxArgs
        bool isForceableCmd = (c.flags & C_FORCE) > 0;
        if (IsAdmin(player) && isForceableCmd) {
            maxArgs += 1
            // check here if force is valid to avoid duplicate code in commands
            if (args.len() == maxArgs) {
                string force = args[maxArgs - 1]
                if (force != "force") {
                    SendMessage(player, ErrorColor("unknown option: " + force))
                    commandSuccess = false
                    break
                }

                if (IsNonAuthenticatedAdmin(player)) {
                    SendMessage(player, ErrorColor("authenticate first"))
                    commandSuccess = false
                    break
                }
            }
        }

        bool hasAdminArg = (c.flags & C_ADMINARG) > 0
        if (IsAdmin(player) && hasAdminArg) {
            maxArgs += 1
            if (args.len() == maxArgs && IsNonAuthenticatedAdmin(player)) {
                SendMessage(player, ErrorColor("authenticate first"))
                commandSuccess = false
                break
            }
        }

        if (args.len() < c.minArgs || (args.len() > maxArgs)) {
            string usage = c.usage
            if (IsAdmin(player) && c.adminUsage != "") {
                usage = c.adminUsage
            }

            SendMessage(player, ErrorColor("usage: " + usage))
            commandSuccess = false
            break
        }

        commandSuccess = c.fn(player, args)
    }

    if (!commandFound) {
        SendMessage(player, ErrorColor("unknown command: " + command))
        messageInfo.shouldBlock = true
    } else if (!commandSuccess) {
        messageInfo.shouldBlock = true
    }

    return messageInfo
}

ClServer_MessageStruct function AntispamCallback(ClServer_MessageStruct messageInfo) {
    // only visible messages are counted towards spam
    if (messageInfo.shouldBlock) {
        return messageInfo
    }

    entity player = messageInfo.player
    if (IsAuthenticatedAdmin(player)) {
        return messageInfo
    }

    float latestTime = Time()
    array<float> messageTimes = [latestTime]
    if (player in file.playerMessageTimes) {
        messageTimes = file.playerMessageTimes[player]
        messageTimes.append(latestTime)
    }

    file.playerMessageTimes[player] <- messageTimes

    // don't do any further processing if limit hasn't been reached
    if (messageTimes.len() < file.antispamLimit) {
        return messageInfo
    }

    // remove message times older than antispam period
    float cutoff = latestTime - float(file.antispamPeriod)
    while (messageTimes.len() > 0 && messageTimes[0] < cutoff) {
        messageTimes.remove(0)
    }

    // valid message if limit hasn't been reached during period
    if (messageTimes.len() < file.antispamLimit) {
        return messageInfo
    }

    // take action at this point
    string playerName = player.GetPlayerName()
    ServerCommand("kick " + playerName)
    Log("[AntispamCallback] " + playerName + " kicked due to spam")
    AnnounceMessage(AnnounceColor(playerName + " has been kicked due to spam"))

    return messageInfo
}

ClServer_MessageStruct function EzfragsCallback(ClServer_MessageStruct messageInfo) {
    if (messageInfo.shouldBlock) {
        return messageInfo
    }

    if (messageInfo.message.tolower().find("ezfrags") == null) {
        return messageInfo
    }

    array<string> words = []
    foreach (string word in split(messageInfo.message, " ")) {
        if (word.tolower().find("ezfrags") != null) {
            words.append("https://tinyurl.com/mrxtmpj5")
        } else {
            words.append(word)
        }
    }

    messageInfo.message = Join(words, " ")
    return messageInfo
}

ClServer_MessageStruct function ChatMentionCallback(ClServer_MessageStruct messageInfo) {
    // fuzz sanitizing is done in ChatCallBack
    if (messageInfo.shouldBlock) {
        return messageInfo
    }

    array<string> oldWords = split(messageInfo.message, " ")
    array<string> newWords = []
    foreach (string word in oldWords) {
        bool isMention = format("%c", word[0]) == "@"
        if (!isMention || word.len() == 1) {
            newWords.append(word)
            continue
        }

        string namePart = word.slice(1)
        array<entity> players = FindPlayersBySubstring(namePart)
        if (players.len() != 1) {
            newWords.append(word)
            continue
        }

        entity player = players[0]
        string mention = PrivateColor("@" + player.GetPlayerName() + White(""))
        newWords.append(mention)
    }

    messageInfo.message = Join(newWords, " ")
    return messageInfo
}

//------------------------------------------------------------------------------
// admins
//------------------------------------------------------------------------------
void function Admin_OnClientDisconnected(entity player) {
    if (!IsAdmin(player)) {
        return
    }

    string uid = player.GetUID()
    if (file.authenticatedAdmins.contains(uid)) {
        file.authenticatedAdmins.remove(file.authenticatedAdmins.find(uid))
    }
}

void function AdminJoinNotify_OnClientConnected(entity player)
{
    if (!IsAdmin(player)) {
        return
    }

    string msg = format("an admin (%s) has joined the game", player.GetPlayerName())
    AnnounceMessage(AnnounceColor(msg))
}

//------------------------------------------------------------------------------
// welcome
//------------------------------------------------------------------------------
void function Welcome_OnPlayerRespawned(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        return
    }

    SendMessage(player, PrivateColor(file.welcome))
    bool hasNoteNumber = file.welcomeNotes.len() > 1
    for (int i = 0; i < file.welcomeNotes.len(); i++) {
        string notePrefix = hasNoteNumber ? format("note %d: ", i + 1) : "note: "
        string note = ErrorColor(notePrefix) + PrivateColor(file.welcomeNotes[i])
        SendMessage(player, note)
    }

    file.welcomedPlayers.append(uid)
}

void function Welcome_OnClientDisconnected(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        file.welcomedPlayers.remove(file.welcomedPlayers.find(uid))
    }
}

//------------------------------------------------------------------------------
// help
//------------------------------------------------------------------------------
bool function CommandHelp(entity player, array<string> args) {
    array<string> userCommands = []
    array<string> retouchedCommands = []
    array<string> adminCommands = []
    foreach (CommandInfo c in file.commands) {
        string names = Join(c.names, "/")
        if (c.flags & C_ADMIN) {
            adminCommands.append(names)
        } else {
            userCommands.append(names)
        }
    }

    foreach (CustomCommand c in file.customCommands) {
        userCommands.append(c.name)
    }

#if GYMMODE
    userCommands.append(file.gymModeCommand.name)
#endif

#if RETOUCHED
    foreach (CustomCommand c in file.retouchedCommands) {
        retouchedCommands.append(c.name)
    }
#endif

    string userHelp = "available commands: " + Join(userCommands, ", ")
    SendMessage(player, PrivateColor(userHelp))

    string retouchedHelp = "balance changes: " + Join(retouchedCommands, ", ")
    if (retouchedCommands.len() > 0) {
        SendMessage(player, PrivateColor(retouchedHelp))
    }

    if (IsAdmin(player)) {
        string adminHelp = "admin commands: " + Join(adminCommands, ", ")
        SendMessage(player, PrivateColor(adminHelp))
    }

    array<string> onlineAdminNames = []
    foreach (entity possibleAdmin in GetPlayerArray()) {
        if (!IsAdmin(possibleAdmin)) {
            continue
        }

        string displayName = possibleAdmin.GetPlayerName()
        if (IsNonAuthenticatedAdmin(possibleAdmin)) {
            displayName += "(?)"
        }

        onlineAdminNames.append(displayName)
    }

    if (onlineAdminNames.len() == 0) {
        return true
    }

    string adminsOnline = "admins online: " + Join(onlineAdminNames, ", ")
    SendMessage(player, PrivateColor(adminsOnline))

    return true
}

//------------------------------------------------------------------------------
// rules
//------------------------------------------------------------------------------
bool function CommandRules(entity player, array<string> args) {
    SendMessage(player, PrivateColor("ok = " + file.rulesOk))
    SendMessage(player, ErrorColor("not ok = " + file.rulesNotOk))
    return true
}

//------------------------------------------------------------------------------
// auth
//------------------------------------------------------------------------------
bool function CommandAuth(entity player, array<string> args) {
    if (IsAuthenticatedAdmin(player)) {
        SendMessage(player, PrivateColor("you are already authenticated"))
        return false
    }

    string password = args[0]
    if (password != file.adminPassword) {
        SendMessage(player, ErrorColor("wrong password"))
        return false
    }

    file.authenticatedAdmins.append(player.GetUID())
    SendMessage(player, PrivateColor("hello, admin!"))

    return true
}

//------------------------------------------------------------------------------
// kick
//------------------------------------------------------------------------------
bool function CommandKick(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName)
    if (result.kind < 0) {
        return false
    }

    entity target = result.players[0]
    string targetUid = target.GetUID()
    string targetName = target.GetPlayerName()
    string playerDesc = GetPlayerDescr(target)

    if (player == target) {
        SendMessage(player, ErrorColor("you can't kick yourself"))
        return false
    }

    bool isForced = args.len() == 2
    if (IsAuthenticatedAdmin(player) && isForced) {
        // allow admins to force kick spoofed admins
        if (IsAuthenticatedAdmin(target)) {
            SendMessage(player, ErrorColor("you can't kick an authenticated admin"))
            return false
        }

        Log("[CommandKick] " + playerDesc + " kicked by " + player.GetPlayerName())
        KickPlayer(target)
        return true
    }

    if (IsAdmin(target)) {
        SendMessage(player, ErrorColor("you can't kick an admin"))
        return false
    }

    if (GetPlayerArray().len() < file.kickMinPlayers) {
        // TODO: store into kicktable anyway?
        SendMessage(player, ErrorColor("not enough players for kick vote, at least " + file.kickMinPlayers + " required"))
        return false
    }

    // ensure kicked player is in file.kickTable
    if (targetUid in file.kickTable) {
        KickInfo kickInfo = file.kickTable[targetUid]
        if (!kickInfo.voters.contains(player)){
            kickInfo.voters.append(player)
        }
    } else {
        KickInfo kickInfo
        kickInfo.voters = []
        kickInfo.voters.append(player)
        kickInfo.threshold = Threshold(GetPlayerArray().len(), file.kickPercentage)
        file.kickTable[targetUid] <- kickInfo
    }

    // kick if votes exceed threshold
    KickInfo kickInfo = file.kickTable[targetUid]
    if (kickInfo.voters.len() >= kickInfo.threshold) {
        Log("[CommandKick] " + playerDesc + " kicked by player vote")
        KickPlayer(target)
    } else {
        int remainingVotes = kickInfo.threshold - kickInfo.voters.len()
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " wants to kick " + targetName + ", " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function KickPlayer(entity player, bool announce = true) {
    string playerUid = player.GetUID()
    if (playerUid in file.kickTable) {
        delete file.kickTable[playerUid]
    }

    if (file.kickSave) {
        if (!file.kickedPlayers.contains(playerUid)) {
            file.kickedPlayers.append(playerUid)
        }

#if NETLIB
        string playerNetwork = NL_GetPlayerIPv4NetworkString(player, NL_CIDR)
        if (!file.kickedNetworks.contains(playerNetwork)) {
            file.kickedNetworks.append(playerNetwork)
        }
#endif
    }

    ServerCommand("kickid " + playerUid)
    if (announce) {
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " has been kicked"))
    }
}

void function Kick_Callback(entity player) {
    string playerDesc = GetPlayerDescr(player)

#if NETLIB
    string playerNetwork = NL_GetPlayerIPv4NetworkString(player, NL_CIDR)
    if (file.kickedNetworks.contains(playerNetwork)) {
        string msg = format("[Kick_Callback] kicking player %s due to network match: %s", playerDesc, playerNetwork)
        Log(msg)
        KickPlayer(player, false)
        return
    }
#endif

    if (file.kickedPlayers.contains(player.GetUID())) {
        string msg = format("[Kick_Callback] kicking player %s due to UID match", playerDesc)
        Log(msg)
        KickPlayer(player, false)
    }
}

void function Kick_OnPlayerKilled(entity victim, entity attacker, var damageInfo)
{
    if (victim.IsPlayer()) {
        Kick_Callback(victim)
    }

    if (attacker.IsPlayer()) {
        Kick_Callback(attacker)
    }
}

void function Kick_OnClientDisconnected(entity player) {
    foreach (string targetUid, KickInfo kickInfo in file.kickTable) {
        array<entity> voters = kickInfo.voters
        if (voters.contains(player)) {
            voters.remove(voters.find(player))
        }

        if (voters.len() == 0) {
            delete file.kickTable[targetUid]
        } else {
            kickInfo.voters = voters
            file.kickTable[targetUid] = kickInfo
        }
    }
}

//------------------------------------------------------------------------------
// maps
//------------------------------------------------------------------------------
table<string, string> MAP_NAME_TABLE = {
    mp_angel_city = "Angel City",
    mp_black_water_canal = "Black Water Canal",
    mp_coliseum = "Coliseum",
    mp_coliseum_column = "Pillars",
    mp_colony02 = "Colony",
    mp_complex3 = "Complex",
    mp_crashsite3 = "Crash Site",
    mp_drydock = "Drydock",
    mp_eden = "Eden",
    mp_forwardbase_kodai = "Forwardbase Kodai",
    mp_glitch = "Glitch",
    mp_grave = "Boomtown",
    mp_homestead = "Homestead",
    mp_lf_deck = "Deck",
    mp_lf_meadow = "Meadow",
    mp_lf_stacks = "Stacks",
    mp_lf_township = "Township",
    mp_lf_traffic = "Traffic",
    mp_lf_uma = "UMA",
    mp_relic02 = "Relic",
    mp_rise = "Rise",
    mp_thaw = "Exoplanet",
    mp_wargames = "Wargames"
}

string function MapName(string map) {
    return MAP_NAME_TABLE[map].tolower()
}

bool function IsValidMap(string map) {
    return map in MAP_NAME_TABLE
}

string function MapsString(array<string> maps) {
    array<string> mapNames = []
    foreach (string map in maps) {
        mapNames.append(MapName(map))
    }

    return Join(mapNames, ", ")
}

array<string> function AllMaps() {
    array<string> allMaps = []
    foreach (map in file.maps) {
        allMaps.append(map)
    }
    foreach (map in file.nextMapOnlyMaps) {
        allMaps.append(map)
    }

    return allMaps
}

bool function CommandMaps(entity player, array<string> args) {
    string mapsInRotation = MapsString(file.maps)
    SendMessage(player, PrivateColor("maps in rotation: " + mapsInRotation))
    if (file.nextMapOnlyMaps.len() > 0) {
        string voteOnlyMaps = MapsString(file.nextMapOnlyMaps)
        string msg = format("maps by vote only (with %d players or less): %s", file.nextMapOnlyMapsMaxPlayers, voteOnlyMaps)
        SendMessage(player, PrivateColor(msg))
    }

    return true
}

bool function CommandNextMap(entity player, array<string> args) {
    string mapName = Join(args, " ")
    array<string> foundMaps = FindMapsBySubstring(mapName)

    if (foundMaps.len() == 0) {
        SendMessage(player, ErrorColor("map '" + mapName + "' not found"))
        return false
    }

    if (foundMaps.len() > 1) {
        SendMessage(player, ErrorColor("multiple matches for map '" + mapName + "', be more specific"))
        return false
    }

    string nextMap = foundMaps[0]
    if (!file.maps.contains(nextMap) && !file.nextMapOnlyMaps.contains(nextMap)) {
        string mapsAvailable = MapsString(AllMaps())
        SendMessage(player, ErrorColor(MapName(nextMap) + " is not in the map pool, available maps: " + mapsAvailable))
        return false
    }

    if (mapName.tolower() == "anal") {
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " tried the funny"))
        return false
    }

    if (nextMap == GetMapName() && !file.nextMapRepeatEnabled) {
        SendMessage(player, ErrorColor("you can't vote for the current map"))
        return false
    }

    int playerCount = GetPlayerArray().len()
    if (file.nextMapOnlyMaps.contains(nextMap) && !file.maps.contains(nextMap) && playerCount > file.nextMapOnlyMapsMaxPlayers) {
        string msg = format("you can only vote for %s when there are %d players or less", MapName(nextMap), file.nextMapOnlyMapsMaxPlayers)
        SendMessage(player, ErrorColor(msg))
        return false
    }

    file.nextMapVoteTable[player] <- nextMap
    AnnounceMessage(AnnounceColor(player.GetPlayerName() + " wants to play on " + MapName(nextMap)))
    return true;
}

void function PostmatchChangeMap() {
    thread DoChangeMap(GAME_POSTMATCH_LENGTH - 1)
}

void function DoChangeMap(float waitTime) {
    wait waitTime

    string nextMap = GetUsualNextMap()
    if (file.nextMapEnabled) {
        string drawnNextMap = DrawNextMapFromVoteTable()
        if (drawnNextMap != "") {
            nextMap = drawnNextMap
        }
    }

    GameRules_ChangeMap(nextMap, GameRules_GetGameMode())
}

string function GetUsualNextMap() {
    string currentMap = GetMapName()
    bool noPlayers = GetPlayerArray().len() == 0
    bool isUnknownMap = !file.maps.contains(currentMap)
    if (noPlayers || isUnknownMap) {
        return file.maps[0]
    }

    if (file.mapRotation == MapRotation.LINEAR) {
        return GetLinearNextMap()
    } 

    return GetRandomNextMap()
}

string function GetLinearNextMap() {
    string currentMap = GetMapName()
    bool isLastMap = currentMap == file.maps[file.maps.len() - 1]
    if (isLastMap) {
        return file.maps[0]
    }

    return file.maps[file.maps.find(currentMap) + 1]
}

string function GetRandomNextMap() {
    string currentMap = GetMapName()
    array<string> randomMapPool = file.maps
    if (randomMapPool.contains(currentMap)) {
        randomMapPool.remove(randomMapPool.find(currentMap))
    }

    if (randomMapPool.len() == 0) {
        return file.maps[0]
    }

    return randomMapPool[RandomInt(randomMapPool.len())]
}

string function DrawNextMapFromVoteTable() {
    array<string> maps = []
    foreach (entity player, string map in file.nextMapVoteTable) {
        maps.append(map)
    }

    if (maps.len() == 0) {
        return ""
    }

    string nextMap = maps[RandomInt(maps.len())]
    return nextMap
}

string function NextMapCandidatesString() {
    array<NextMapScore> scores = NextMapCandidates()
    int totalVotes = file.nextMapVoteTable.len()
    array<string> chanceStrings = []
    for (int i = 0; i < scores.len(); i++) {
        NextMapScore score = scores[i]
        float chance = 100 * (float(score.votes) / float(totalVotes))
        string chanceString = format("%s (%.0f%%)", MapName(score.map), chance)
        chanceStrings.append(chanceString)
    }

    return Join(chanceStrings, ", ")
}

array<NextMapScore> function NextMapCandidates() {
    table<string, int> mapVotes = {}
    foreach (entity player, string map in file.nextMapVoteTable) {
        if (map in mapVotes) {
            int currentVotes = mapVotes[map]
            mapVotes[map] <- currentVotes + 1
        } else {
            mapVotes[map] <- 1
        }
    }

    array<NextMapScore> scores = []
    foreach (string map, int votes in mapVotes) {
        NextMapScore score
        score.map = map
        score.votes = votes
        scores.append(score)
    }

    scores.sort(NextMapScoreSort)
    return scores
}

int function NextMapScoreSort(NextMapScore a, NextMapScore b) {
    if (a.votes == b.votes) {
        return 0
    }
    return a.votes < b.votes ? 1 : -1
}

void function NextMap_OnWinnerDetermined() {
    if (file.nextMapVoteTable.len() > 0) {
        AnnounceMessage(AnnounceColor("next map chances: " + NextMapCandidatesString()))
    }
}

void function NextMap_OnClientDisconnected(entity player) {
    if (player in file.nextMapVoteTable) {
        delete file.nextMapVoteTable[player]
    }
}

void function NextMapHint_OnPlayerRespawned(entity player) {
    string uid = player.GetUID()
    if (file.nextMapHintedPlayers.contains(uid)) {
        return
    }

    float endTime = expect float(GetServerVar("gameEndTime"))
    if (IsCTF()) {
        endTime = expect float(GetServerVar("roundEndTime"))
    }
    if (Time() < endTime / 2.0) {
        return
    }

    if (!(player in file.nextMapVoteTable)) {
        SendMessage(player, PrivateColor("hint: use !nextmap/!nm to vote for next map"))
    }

    file.nextMapHintedPlayers.append(uid)
}

//------------------------------------------------------------------------------
// switch
//------------------------------------------------------------------------------
bool function CommandSwitch(entity player, array<string> args) {
    entity target = player
    bool isAdminSwitch = args.len() == 1
    if (isAdminSwitch) {
        string targetSearchName = args[0]
        PlayerSearchResult result = RunPlayerSearch(player, targetSearchName)
        if (result.kind < 0) {
            return false
        }
        target = result.players[0]
    }

    string targetName = target.GetPlayerName()

    string enoughMsg = "you've switched teams enough"
    string flagMsg = "can't switch while you're holding the flag"
    string teamMsg = "can't switch, there's enough players on the other team"
    string switchMsg = targetName + " has switched teams"

    if (isAdminSwitch) {
        flagMsg = "can't switch " + targetName + ", they're holding a flag"
        teamMsg = "can't switch " + targetName +  ", there's enough players on the other team"
        switchMsg = targetName + "'s team has been switched"
    }

    string targetUid = target.GetUID()
    if (!isAdminSwitch && targetUid in file.switchCountTable) {
        int switchCount = file.switchCountTable[targetUid]
        if (switchCount >= file.switchLimit) {
            SendMessage(player, ErrorColor(enoughMsg))
            return false
        }
    }

    // ctf
    if (!file.switchKill && PlayerHasEnemyFlag(target)) {
        SendMessage(player, ErrorColor(flagMsg))
        return false
    }

    int thisTeam = target.GetTeam()
    int otherTeam = GetOtherTeam(thisTeam)

    int thisTeamCount = GetPlayerArrayOfTeam(thisTeam).len()
    int otherTeamCount = GetPlayerArrayOfTeam(otherTeam).len()

    int playerDiff = thisTeamCount - otherTeamCount
    if (!isAdminSwitch && playerDiff < file.switchDiff && otherTeamCount > 0) {
        SendMessage(player, ErrorColor(teamMsg))
        return false
    }

    int switchCount
    if (targetUid in file.switchCountTable) {
        switchCount = file.switchCountTable[targetUid] + 1
    } else {
        switchCount = 1
    }

    if (!isAdminSwitch) {
        file.switchCountTable[targetUid] <- switchCount
    }

    // ctf: if player is holding a flag, he gotta die *before* setting the team
    if (!isAdminSwitch && file.switchKill && IsAlive(target)) {
        target.Die()
    }

    SetTeam(target, otherTeam)

    AnnounceMessage(AnnounceColor(switchMsg))

    return true
}

//------------------------------------------------------------------------------
// balance
//------------------------------------------------------------------------------
bool function CommandBalance(entity player, array<string> args) {
    bool isForced = args.len() == 1
    if (IsAuthenticatedAdmin(player) && isForced) {
        DoBalance()
        return true
    }

    if (GetPlayerArray().len() < file.balanceMinPlayers) {
        SendMessage(player, ErrorColor("not enough players for balance vote, at least " + file.balanceMinPlayers + " required"))
        return false
    }

    if (file.balanceVoters.len() == 0) {
        file.balanceThreshold = Threshold(GetPlayerArray().len(), file.balancePercentage)
    }

    if (!file.balanceVoters.contains(player)) {
        file.balanceVoters.append(player)
    }

    if (file.balanceVoters.len() >= file.balanceThreshold) {
        DoBalance()
    } else {
        int remainingVotes = file.balanceThreshold - file.balanceVoters.len()
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " wants team balance, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoBalance() {
    array<entity> players = GetPlayerArray()

    array<entity> switchablePlayers = []
    foreach (entity player in players) {
        if (CanSwitchTeams(player)) {
            switchablePlayers.append(player)
        }
    }

    array<PlayerScore> scores = GetPlayerScores(switchablePlayers)
    for (int i = 0; i < scores.len(); i++) {
        entity player = scores[i].player
        int oldTeam = player.GetTeam()
        int newTeam = IsEven(i) ? TEAM_IMC : TEAM_MILITIA
        SetTeam(player, newTeam)
    }

    AnnounceMessage(AnnounceColor("teams have been balanced"))

    file.balanceVoters.clear()
}

array<PlayerScore> function GetPlayerScores(array<entity> players) {
    array<PlayerScore> scores
    foreach (entity player in players) {
        PlayerScore score
        score.player = player
        score.val = CalculatePlayerScore(player)
        scores.append(score)
    }

    scores.sort(PlayerScoreSort)

    return scores
}

float function CalculatePlayerScore(entity player) {
    if (IsCTF()) {
        return CalculateCTFScore(player)
    }

    return CalculateKillScore(player)
}

float function CalculateCTFScore(entity player) {
    int captureWeight = 10
    int returnWeight = 5

    int captures = player.GetPlayerGameStat(PGS_ASSAULT_SCORE)
    int returns = player.GetPlayerGameStat(PGS_DEFENSE_SCORE)
    int kills = player.GetPlayerGameStat(PGS_KILLS)
    float score = float((captures * captureWeight) + (returns + returnWeight) + kills)
    return score
}

float function CalculateKillScore(entity player) {
    int kills = player.GetPlayerGameStat(PGS_KILLS)
    int assists = player.GetPlayerGameStat(PGS_ASSISTS)
    int deaths = player.GetPlayerGameStat(PGS_DEATHS)
    if (deaths == 0) {
        deaths = 1
    }

    float ka = float(kills) + float(assists)
    float kad = ka / float(deaths)

    // number of kills + assists, multiplied by kills and assists per death
    return ka * kad
}

int function PlayerScoreSort(PlayerScore a, PlayerScore b) {
    if (a.val == b.val) {
        return 0
    }

    return a.val < b.val ? 1 : -1
}

void function Balance_Postmatch() {
    DoBalance()
}

void function Balance_OnClientDisconnected(entity player) {
    if (file.balanceVoters.contains(player)) {
        file.balanceVoters.remove(file.balanceVoters.find(player))
    }
}


//------------------------------------------------------------------------------
// autobalance
//------------------------------------------------------------------------------
float AUTOBALANCE_INTERVAL = 10

void function Autobalance_Start() {
    Log("starting autobalance loop")
    thread Autobalance_Loop()
}

void function Autobalance_Loop() {
    while (true) {
        wait AUTOBALANCE_INTERVAL
        Autobalance_Check()
    }
}

void function Autobalance_Check() {
    int imcCount = GetPlayerArrayOfTeam(TEAM_IMC).len()
    int militiaCount = GetPlayerArrayOfTeam(TEAM_MILITIA).len()

    int fromTeam
    int diff
    if (imcCount == militiaCount) {
        return
    } else if (imcCount > militiaCount) {
        fromTeam = TEAM_IMC
        diff = imcCount - militiaCount
    } else {
        fromTeam = TEAM_MILITIA
        diff = militiaCount - imcCount
    }

    if (diff < file.autobalanceDiff) {
        return
    }

    DoAutobalance(fromTeam)
}

void function DoAutobalance(int fromTeam) {
    array<entity> prio2 = []
    foreach (entity player in file.autobalancePlayerQueue) {
        if (player.GetTeam() == fromTeam && CanSwitchTeams(player)) {
            prio2.append(player)
        }
    }

    if (prio2.len() == 0) {
        return
    }

    entity playerToSwitch = prio2[0]

    array<entity> prio1 = []
    foreach (entity player in prio2) {
        // prefer not to switch players who have manually switched
        if (!(player.GetUID() in file.switchCountTable)) {
            prio1.append(player)
        }
    }

    if (prio1.len() > 0) {
        playerToSwitch = prio1[0]
    }

    int toTeam = GetOtherTeam(fromTeam) 
    SetTeam(playerToSwitch, toTeam)

    SendMessage(playerToSwitch, PrivateColor("you got autobalanced"))
}

void function Autobalance_OnClientConnected(entity player) {
    if (file.autobalancePlayerQueue.contains(player)) {
        return
    }

    // most recently joined players first in queue
    file.autobalancePlayerQueue.insert(0, player)
}

void function Autobalance_OnClientDisconnected(entity player) {
    if (file.autobalancePlayerQueue.contains(player)) {
        file.autobalancePlayerQueue.remove(file.autobalancePlayerQueue.find(player))
    }
}

//------------------------------------------------------------------------------
// extend
//------------------------------------------------------------------------------
bool function CommandExtend(entity player, array<string> args) {
    bool isForced = args.len() == 1
    if (IsAuthenticatedAdmin(player) && isForced) {
        DoExtend()
        return true
    }

    if (file.extendVoters.len() == 0) {
        file.extendThreshold = Threshold(GetPlayerArray().len(), file.extendPercentage)
    }

    if (!file.extendVoters.contains(player)) {
        file.extendVoters.append(player)
    }

    if (file.extendVoters.len() >= file.extendThreshold) {
        DoExtend()
    } else {
        int remainingVotes = file.extendThreshold - file.extendVoters.len()
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " wants to extend the map, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoExtend() {
    float currentEndTime = expect float(GetServerVar("gameEndTime"))
    float newEndTime = currentEndTime + (60 * file.extendMinutes)
    SetServerVar("gameEndTime", newEndTime)

    AnnounceMessage(AnnounceColor("map has been extended"))

    file.extendVoters.clear()
}

void function Extend_OnClientDisconnected(entity player) {
    if (file.extendVoters.contains(player)) {
        file.extendVoters.remove(file.extendVoters.find(player))
    }
}

//------------------------------------------------------------------------------
// skip
//------------------------------------------------------------------------------
bool function CommandSkip(entity player, array<string> args) {
    if (GetGameState() < eGameState.Playing) {
        SendMessage(player, ErrorColor("match hasn't begun yet"))
        return false
    }

    if (GetGameState() >= eGameState.WinnerDetermined) {
        SendMessage(player, ErrorColor("match is over already"))
        return false
    }
    
    bool isForced = args.len() == 1
    if (IsAuthenticatedAdmin(player) && isForced) {
        DoSkip()
        return true
    }

    if (file.skipVoters.len() == 0) {
        file.skipThreshold = Threshold(GetPlayerArray().len(), file.skipPercentage)
    }

    if (!file.skipVoters.contains(player)) {
        file.skipVoters.append(player)
    }

    if (file.skipVoters.len() >= file.skipThreshold) {
        DoSkip()
    } else {
        int remainingVotes = file.skipThreshold - file.skipVoters.len()
        AnnounceMessage(AnnounceColor(player.GetPlayerName() + " wants to skip the current map, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoSkip() {
    float waitTime = 5.0
    thread SkipAnnounceLoop(waitTime)
    thread DoChangeMap(waitTime)
    file.skipVoters.clear()
}

void function SkipAnnounceLoop(float waitTime) {
    int seconds = int(waitTime)
    AnnounceMessage(AnnounceColor("current map will be skipped in " + seconds + "..."))
    for (int i = seconds - 1; i > 0; i--) {
        // ctf fix, skip crashes if player has flag
        if (IsCTF() && i <= 3) {
            KillAll()
        }

        wait 1.0
        AnnounceMessage(AnnounceColor(i + "..."))
    }
}

void function KillAll() {
    foreach (entity player in GetPlayerArray()) {
        if (IsAlive(player)) {
            player.Die()
        }
    }
}

void function Skip_OnClientDisconnected(entity player) {
    if (file.skipVoters.contains(player)) {
        file.skipVoters.remove(file.skipVoters.find(player))
    }
}

//------------------------------------------------------------------------------
// mute
//------------------------------------------------------------------------------
bool function CommandMute(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName)
    if (result.kind < 0) {
        return false
    }

    entity target = result.players[0]
    string targetName = target.GetPlayerName()
    string targetUid = target.GetUID()

    if (file.mutedPlayers.contains(targetUid)) {
        SendMessage(player, ErrorColor(targetName + " is already muted"))
        return false
    }

    file.mutedPlayers.append(targetUid)
    AnnounceMessage(AnnounceColor(targetName + " has been muted"))

    return true
}

bool function CommandUnmute(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName)
    if (result.kind < 0) {
        return false
    }

    entity target = result.players[0]
    string targetName = target.GetPlayerName()
    string targetUid = target.GetUID()
    if (!file.mutedPlayers.contains(targetUid)) {
        SendMessage(player, ErrorColor(targetName + " is not muted"))
        return false
    }

    file.mutedPlayers.remove(file.mutedPlayers.find(targetUid))
    AnnounceMessage(AnnounceColor(targetName + " is no longer muted"))

    return false
}

void function Mute_OnClientDisconnected(entity player) {
    string uid = player.GetUID()
    if (file.mutedPlayers.contains(uid)) {
        file.mutedPlayers.remove(file.mutedPlayers.find(uid))
    }
}

//------------------------------------------------------------------------------
// lockdown
//------------------------------------------------------------------------------
bool function CommandLockdown(entity player, array<string> _args) {
    if (file.isLockdown) {
        SendMessage(player, ErrorColor("server is already locked down"))
        return false
    }

    file.isLockdown = true

    string msg = AnnounceColor("server is on ")
    msg += ErrorColor("LOCKDOWN")
    msg += AnnounceColor(" (no new players can join)")
    AnnounceMessage(msg)

    return true
}

bool function CommandUnlockdown(entity player, array<string> _args) {
    if (!file.isLockdown) {
        SendMessage(player, ErrorColor("server is not locked down"))
        return false
    }

    file.isLockdown = false
    AnnounceMessage(AnnounceColor("server is no longer on lockdown"))

    return true
}

void function Lockdown_OnPlayerConnected(entity player) {
    if (!file.isLockdown || IsAdmin(player)) {
        return
    }

    string playerName = player.GetPlayerName()
    ServerCommand("kick " + playerName)
}

//------------------------------------------------------------------------------
// yell
//------------------------------------------------------------------------------
bool function CommandYell(entity player, array<string> args) {
    string msg = Join(args, " ").toupper()
    AnnounceHUD(msg, 255, 0, 0)
    return true
}

//------------------------------------------------------------------------------
// slay
//------------------------------------------------------------------------------
bool function CommandSlay(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            target.Die()
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " has been slain"))

    return true
}

//------------------------------------------------------------------------------
// freeze
//------------------------------------------------------------------------------
bool function CommandFreeze(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            target.MovementDisable()
            target.ConsumeDoubleJump()
            target.DisableWeaponViewModel()
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " has been frozen"))

    return true
}

//------------------------------------------------------------------------------
// stim
//------------------------------------------------------------------------------
bool function CommandStim(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            StimPlayer(target, 9999)
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " is going fast"))
    return true
}

//------------------------------------------------------------------------------
// salvo
//------------------------------------------------------------------------------
bool function CommandSalvo(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (!IsAlive(target)) {
            continue
        }

        foreach (entity weapon in target.GetMainWeapons()) {
            target.TakeWeaponNow(weapon.GetWeaponClassName())
        }
        target.GiveWeapon("mp_titanweapon_flightcore_rockets", [])
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " has flight core"))
    return true
}

//------------------------------------------------------------------------------
// tank
//------------------------------------------------------------------------------
bool function CommandTank(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    int health = 1000
    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            target.SetMaxHealth(health)
            target.SetHealth(health)
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " is tanky"))
    return true
}

//------------------------------------------------------------------------------
// fly
//------------------------------------------------------------------------------
bool function CommandFly(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            target.SetPhysics(MOVETYPE_NOCLIP)
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " is flying"))
    return true
}

bool function CommandUnfly(entity player, array<string> args) {
    string targetSearchName = args[0]
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (IsAlive(target)) {
            target.SetPhysics(MOVETYPE_WALK)
        }
    }

    string name = PlayerSearchResultName(player, result)
    AnnounceMessage(AnnounceColor(name + " is no longer flying"))
    return true
}

//------------------------------------------------------------------------------
// mrvn
//------------------------------------------------------------------------------

bool function CommandMrvn(entity player, array<string> args) {
    const health = 100
    array<entity> spawnpoints = SpawnPoints_GetPilot()
    spawnpoints.randomize()

    int spawnCount = 0
    foreach (entity spawnpoint in spawnpoints) {
        if (spawnCount >= 25) {
            break
        }

        if (spawnpoint.IsOccupied()) {
            continue
        }

        entity marvin = CreateMarvin(TEAM_UNASSIGNED, spawnpoint.GetOrigin(), spawnpoint.GetAngles())
        marvin.kv.health = health
        marvin.kv.max_health = health
        DispatchSpawn(marvin)
        HideName(marvin)
        thread MarvinJobThink(marvin)

        spawnCount += 1
    }

    string msg = format("%d marvins spawned", spawnCount)
    SendMessage(player, PrivateColor(msg))

    return true
}

//------------------------------------------------------------------------------
// grunt
//------------------------------------------------------------------------------

bool function CommandGrunt(entity player, array<string> args) {
    string targetSearchName = args.len() == 1 ? args[0] : "me"
    PlayerSearchResult result = RunPlayerSearch(player, targetSearchName, PS_MODIFIERS | PS_ALIVE)
    if (result.kind < 0) {
        return false
    }

    foreach (entity target in result.players) {
        if (!IsAlive(target)) {
            continue
        }

        entity grunt = CreateSoldier(target.GetTeam(), target.GetOrigin(), target.GetAngles())
        DispatchSpawn(grunt)
        string squadName = format("%s_%d", target.GetPlayerName(), target.GetTeam())
        SetSquad(grunt, squadName)
        grunt.EnableNPCFlag(NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE)
    }

    return true
}

//------------------------------------------------------------------------------
// chaos
//------------------------------------------------------------------------------
bool function CommandChaos(entity player, array<string> args) {
    array<entity> players = GetPlayerArray()
    array<entity> spawnpoints = SpawnPoints_GetPilot()
    Log("[CommandChaos] spawnpoints.len = " + spawnpoints.len())
    int spawnCount = 0
    for (int i = 0; i < spawnpoints.len(); i++) {
        if (i >= 25) {
            break;
        }

        entity spawnpoint = spawnpoints[i]

        if (spawnpoint.IsOccupied()) {
            continue
        }

        int team = players.getrandom().GetTeam()
        if (!IsFFAGame() && RandomInt(2) == 0) {
            team = GetOtherTeam(team)
        }

        SpawnRandomNPC(team, spawnpoint.GetOrigin(), spawnpoint.GetAngles())
        spawnCount += 1
    }

    string msg = format("%d NPCs spawned", spawnCount)
    SendMessage(player, PrivateColor(msg))

    return true
}

void function SpawnRandomNPC(int team, vector origin, vector angles) {
    float gruntFrac = 1.0
    float spectreFrac = 0.5
    float reaperFrac = 0.25

    float roll = RandomFloat(1.0)
    entity npc = null
    if (roll <= reaperFrac) {
        npc = CreateSuperSpectre(team, origin, angles)
        SetSpawnOption_Titanfall(npc)
        SetSpawnOption_Warpfall(npc)
    } else if (roll <= spectreFrac) {
        npc = CreateSpectre(team, origin, angles)
    } else if (roll <= gruntFrac) {
        npc = CreateSoldier(team, origin, angles)
    }

    DispatchSpawn(npc)
}

//------------------------------------------------------------------------------
// roll
//------------------------------------------------------------------------------
bool function CommandRoll(entity player, array<string> args) {
    string uid = player.GetUID()
    int rollCount = 1
    if (uid in file.rollCountTable) {
        rollCount = file.rollCountTable[uid] + 1
    }

    if (rollCount > file.rollLimit) {
        SendMessage(player, ErrorColor("you've rolled enough"))
        return false
    }

    file.rollCountTable[uid] <- rollCount

    int rollMax = 100
    int num = RandomInt(rollMax) + 1
    float f = float(num) / float(rollMax)

    string name = player.GetPlayerName()
    string msg = AnnounceColor(name + " rolled ") + ErrorColor("" + num)
    msg += AnnounceColor("")
    if (num == 1) {
        msg += ", " + ErrorColor("lol")
    } else if (num == 69) {
        msg += ", " + ErrorColor("nice")
    } else if (num == rollMax) {
        msg += ", what a " + ErrorColor("CHAD")
    } else if (f < 0.5) {
        msg += ", meh"
    } else if (f < 0.9) {
        msg += ", alright"
    } else {
        msg += ", almost"
    }

    AnnounceMessage(AnnounceColor(msg))
    return true
}

//------------------------------------------------------------------------------
// killstreak
//------------------------------------------------------------------------------
void function Killstreak_OnPlayerKilled(entity victim, entity attacker, var damageInfo) {
    if (!victim.IsPlayer() || !attacker.IsPlayer() || GetGameState() != eGameState.Playing) {
        return
    }

    string victimName = victim.GetPlayerName()
    string attackerName = attacker.GetPlayerName()

    int victimKillstreak = GetKillstreak(victim)
    int attackerKillstreak = GetKillstreak(attacker)
    if (victimKillstreak >= file.killstreakIncrement) {
        string msg = ErrorColor(attackerName)
        msg += AnnounceColor(" ended ")
        msg += ErrorColor(victimName + "'s")
        msg += AnnounceColor(" " + victimKillstreak + "-kill streak")
        AnnounceMessage(msg)
    }

    SetKillstreak(victim, 0)
    if (attacker == victim) {
        return
    }

    attackerKillstreak += 1
    if (attackerKillstreak % file.killstreakIncrement == 0) {
        string msg = ErrorColor(attackerName)
        msg += AnnounceColor(" is on a " + attackerKillstreak + "-kill streak")
        AnnounceMessage(msg)
    }

    SetKillstreak(attacker, attackerKillstreak)
}

int function GetKillstreak(entity player) {
    string uid = player.GetUID()
    return uid in file.playerKillstreaks ? file.playerKillstreaks[uid] : 0
}

void function SetKillstreak(entity player, int killstreak) {
    string uid = player.GetUID()
    file.playerKillstreaks[uid] <- killstreak
}

//------------------------------------------------------------------------------
// pitfall joke
//------------------------------------------------------------------------------
table<string, string> PITFALL_MAP_SUBJECT_TABLE = {
    mp_glitch            = "into the pit",
    mp_wargames          = "into the pit",
    mp_crashsite3        = "into the pit",
    mp_drydock           = "off the map",
    mp_relic02           = "off the map",
    mp_complex3          = "off the map",
    mp_forwardbase_kodai = "off the map"
}

void function Pitfalls_OnPlayerKilled(entity victim, entity attacker, var damageInfo) {
    string map = GetMapName()
    if (!(map in PITFALL_MAP_SUBJECT_TABLE)) {
        return
    }

    if (!victim.IsPlayer() || GetGameState() != eGameState.Playing) {
        return
    }
    
    int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
    if (damageSourceId != eDamageSourceId.fall) {
        return
    }

    string playerName = victim.GetPlayerName()
    int count = 1
    if (playerName in file.pitfallTable) {
        count = file.pitfallTable[playerName] + 1
    }

    string subject = PITFALL_MAP_SUBJECT_TABLE[map]
    string msg = playerName + " has fallen " + subject + " " + count + " times"
    if (count == 1) {
        msg = playerName + " fell " + subject
    } else if (count == 2) {
        msg = playerName + " fell " + subject + ", again"
    }

    AnnounceMessage(AnnounceColor(msg))

    file.pitfallTable[playerName] <- count
}

//------------------------------------------------------------------------------
// marvin joke
//------------------------------------------------------------------------------
void function Marvin_DeathCallback(entity victim, var damageInfo) {
    entity attacker = DamageInfo_GetAttacker(damageInfo)
    if (!IsValid(attacker) || !attacker.IsPlayer()) {
        return
    }

    string playerName = attacker.GetPlayerName()
    string msg = playerName + " killed a marvin"
    AnnounceMessage(AnnounceColor(msg))
}

//------------------------------------------------------------------------------
// drone joke
//------------------------------------------------------------------------------
void function Drone_DeathCallback(entity victim, var damageInfo) {
    entity attacker = DamageInfo_GetAttacker(damageInfo)
    if (!IsValid(attacker) || !attacker.IsPlayer()) {
        return
    }

    string playerName = attacker.GetPlayerName()
    string msg = playerName + " destroyed a drone"
    AnnounceMessage(AnnounceColor(msg))
}

//------------------------------------------------------------------------------
// kill jokes
//------------------------------------------------------------------------------
void function JokeKills_OnPlayerKilled(entity victim, entity attacker, var damageInfo) {
    if (!attacker.IsPlayer() || !victim.IsPlayer() || GetGameState() != eGameState.Playing) {
        return
    }
    
    int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
    string verb
    switch (damageSourceId) {
        case eDamageSourceId.phase_shift:
            verb = "got phased by"
            break
        default:
            return
    }

    string attackerName = attacker.GetPlayerName()
    string victimName = victim.GetPlayerName()
    string msg = format("%s %s %s", victimName, verb, attackerName)

    AnnounceMessage(AnnounceColor(msg))
}

//------------------------------------------------------------------------------
// utils
//------------------------------------------------------------------------------

PlayerSearchResult function RunPlayerSearch(
    entity commandUser,
    string playerName,
    int flags = 0x0
) {
    PlayerSearchResult result
    result.kind = PlayerSearchResultKind.NOT_FOUND
    result.players = []

    if ((flags & PS_MODIFIERS) > 0) {
        switch (playerName.tolower()) {
            case "me":
                result.kind = PlayerSearchResultKind.SINGLE
                result.players.append(commandUser)
                return result

            case "all":
                result.kind = PlayerSearchResultKind.ALL
                result.players = GetPlayerArray()
                return result

            case "us":
                if (IsFFAGame()) {
                    result.kind = PlayerSearchResultKind.ALL
                    result.players = GetPlayerArray()
                    return result
                }
                result.kind = PlayerSearchResultKind.US
                result.players = GetPlayerArrayOfTeam(commandUser.GetTeam())
                return result

            case "them":
                if (IsFFAGame()) {
                    result.kind = PlayerSearchResultKind.ALL
                    result.players = GetPlayerArray()
                    return result
                }
                result.kind = PlayerSearchResultKind.THEM
                result.players = GetPlayerArrayOfTeam(GetOtherTeam(commandUser.GetTeam()))
                return result
            default:
                break
        }
    }

    result.players = FindPlayersBySubstring(playerName)
    if (result.players.len() == 0) {
        SendMessage(commandUser, ErrorColor("player '" + playerName + "' not found"))
        result.kind = PlayerSearchResultKind.NOT_FOUND
        return result
    }

    if (result.players.len() > 1) {
        SendMessage(commandUser, ErrorColor("multiple matches for player '" + playerName + "', be more specific"))
        result.kind = PlayerSearchResultKind.MULTIPLE
        return result
    }

    if ((flags & PS_ALIVE) > 0) {
        entity target = result.players[0]
        if (!IsAlive(target)) {
            SendMessage(commandUser, ErrorColor(target.GetPlayerName() + " is dead"))
            result.kind = PlayerSearchResultKind.DEAD
            return result
        }
    }

    result.kind = PlayerSearchResultKind.SINGLE
    return result
}

string function TeamName(int team) {
    if (team == TEAM_IMC) {
        return "imc"
    } else if (team == TEAM_MILITIA) {
        return "militia"
    }

    return "???"
}

string function PlayerSearchResultName(entity commandUser, PlayerSearchResult result) {
    switch (result.kind) {
        case PlayerSearchResultKind.SINGLE:
            return result.players[0].GetPlayerName()

        case PlayerSearchResultKind.ALL:
            return "everyone"

        case PlayerSearchResultKind.US:
            if (IsFFAGame()) {
                return "everyone"
            }
            int usTeam = commandUser.GetTeam()
            return "team " + TeamName(usTeam)

        case PlayerSearchResultKind.THEM:
            if (IsFFAGame()) {
                return "everyone"
            }
            int themTeam = GetOtherTeam(commandUser.GetTeam())
            return "team " + TeamName(themTeam)

        default:
            break
    }
    return ErrorColor("??? fvnhead pls fix ???")
}

void function Log(string s) {
     print("[fvnkhead.mod] " + s)
}

void function Debug(string s) {
    if (!file.debugEnabled) {
        return
    }

    print("[fvnkhead.mod/debug] " + s)
}

string function ErrorColor(string s) {
    return "\x1b[112m" + s
}

string function PrivateColor(string s) {
    return "\x1b[111m" + s
}

string function AnnounceColor(string s) {
    return "\x1b[95m" + s
}

string function White(string s) {
    return "\x1b[0m" + s
}

string function Green(string s) {
    return "\x1b[92m" + s
}

bool function IsAdmin(entity player) {
    return file.adminUids.contains(player.GetUID())
}

bool function IsNonAuthenticatedAdmin(entity player) {
    if (file.adminAuthEnabled) {
        return IsAdmin(player) && !file.authenticatedAdmins.contains(player.GetUID())
    }

    return false
}

bool function IsAuthenticatedAdmin(entity player) {
    if (file.adminAuthEnabled) {
        return IsAdmin(player) && file.authenticatedAdmins.contains(player.GetUID())
    }

    return IsAdmin(player)
}

string function Join(array<string> list, string separator) {
    string s = ""
    for (int i = 0; i < list.len(); i++) {
        s += list[i]
        if (i < list.len() - 1) {
            s += separator
        }
    }

    return s
}

int function Threshold(int count, float percentage) {
    return int(ceil(count * percentage))
}

void function SendMessage(entity player, string text) {
    thread AsyncSendMessage(player, text)
    // TODO: testing
    //Chat_ServerPrivateMessage(player, text, false)
}

void function AsyncSendMessage(entity player, string text) {
    wait 0.1

    if (!IsValid(player)) {
        return
    }

    Chat_ServerPrivateMessage(player, text, false)
}

void function AnnounceMessage(string text) {
    AsyncAnnounceMessage(text)
    // TODO: testing
    //Chat_ServerBroadcast(text)
}

void function AsyncAnnounceMessage(string text) {
    foreach (entity player in GetPlayerArray()) {
        SendMessage(player, text)
    }
    // TODO: testing
    //Chat_ServerBroadcast(text)
}

void function SendHUD(entity player, string msg, int r, int g, int b, int time = 10) {
    SendHudMessage(player, msg, -1, 0.2, r, g, b, 255, 0.15, time, 1)
}

void function AnnounceHUD(string msg, int r, int g, int b, int time = 10) {
    foreach (entity player in GetPlayerArray()) {
        SendHUD(player, msg, r, g, b, time)
    }
}

array<entity> function FindPlayersBySubstring(string substring) {
    substring = substring.tolower()
    array<entity> players = []
    foreach (entity player in GetPlayerArray()) {
        string name = player.GetPlayerName().tolower()
        if (name.find(substring) != null) {
            players.append(player)
        }
    }

    return players
}

array<string> function FindMapsBySubstring(string substring) {
    substring = substring.tolower()
    array<string> maps = []
    foreach (string mapKey, string mapName in MAP_NAME_TABLE) {
        if (mapName.tolower().find(substring) != null) {
            maps.append(mapKey)
        }
    }

    return maps
}

bool function CanSwitchTeams(entity player) {
    // ctf bug, flag can become other team flag so they have 2 flags
    if (PlayerHasEnemyFlag(player)) {
        return false
    }

    return true
}

bool function IsCTF() {
    return GameRules_GetGameMode() == CAPTURE_THE_FLAG
}

string function GetPlayerDescr(entity player)
{
    if (!IsValid(player)) {
        return ""
    }

#if NETLIB
    return NL_GetPlayerDescription(player)
#endif

    return format("'%s'/'%s'", player.GetPlayerName(), player.GetUID())
}
