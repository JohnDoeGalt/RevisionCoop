/*
 * RevCoop: Steam relay for Deus Ex: Revision co-op (RevNet, on Revision's own code).
 * Based on HXCoop by cranebeaker (MIT, see LICENSE-hxcoop); RevCoop adds host-owned modes:
 *  - the game is the co-op folder's copy of Revision.exe (<Revision>\CoopNet, RevNet.ini);
 *    this relay lives in CoopNet\Relay with its own steam_api.dll and steam_appid.txt (480),
 *    the game's own steam_appid.txt (397550) stays in CoopNet.
 *  - a mode is Modes\<name>.mode in the co-op folder: Title=, Game= (game class) and the
 *    Paths=/OverrideLocalizationPaths=/SavePath= lines that select its packages, maps and
 *    save folder (Revision, Vanilla, Shifter, Biomod, HR). The host's mode goes into the
 *    lobby; a joining player's RevNet.ini gets the same lines before the game starts.
 *  - Revision's launcher ignores a URL on its command line: the URL to open goes into
 *    RevNetUser.ini ([RevNet.CoopLaunch] AutoOpen=), which the game opens once.
 *
 * HXCoop: Steam ("Spacewar", AppID 480) relay for HX Deus Ex co-op.
 *
 * Players never deal with IP addresses or port forwarding:
 *  - host:  creates a friends-only Steam lobby, starts the game as a listen server and
 *           relays every friend's packets between Steam and the local game port;
 *  - join:  finds Steam friends who host (or takes a lobby id / invite), binds a local
 *           UDP port and starts the game connected to it, relaying to the host over Steam.
 * UE1 does its own reliability, so packets go as unreliable Steam messages on channel 0.
 * Channel 1 carries a 1 s keep-alive and a goodbye.
 * Game packets carry a 1 byte connection id in both directions. On a map change the game
 * opens a new connection from a new local port while the old one still sends for a moment;
 * each client side source address gets its own id, and the host side gives each id its own
 * socket (so its own source port), or the server takes the new handshake for the old
 * connection.
 *
 * steam_api.dll is loaded at runtime through the flat C API (no SDK headers), see
 * spacewar.md. Needs steam_appid.txt = 480 in the working directory.
 *
 *   RevCoop.exe                    menu
 *   RevCoop.exe host [map]         host, default map 01_NYC_UNATCOIsland
 *   RevCoop.exe join [lobby id]    join (no id: a friend who is hosting)
 *   RevCoop.exe continue           host the saved game of the current mode
 * Options: --game <co-op folder>  --port <game port, 7790>  --url-extra <?opts for the host URL>
 *          --game-args <extra Revision.exe arguments>  --no-launch (relay only)  --mode <name>
 *          --apply-mode <name> (write the mode and settings into RevNet.ini and exit; IP launchers)
 *          --open <url> (with --apply-mode: also set the URL the game opens)
 */
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>

typedef uint64_t u64;

/* Lobbies only match this exact value: bump it when packages or the relay protocol change. */
#define REVCOOP_PROTOCOL "3"

/* ---------------------------------------------------------------- steam flat api */

typedef struct { int32_t user; int32_t callback; uint8_t *param; int32_t param_size; } CallbackMsg;
#pragma pack(push, 8)
typedef struct { u64 call; int32_t callback; uint32_t param_size; } APICallCompleted;
typedef struct { int32_t result; u64 lobby; } LobbyCreated;
typedef struct { u64 lobby; uint32_t perms; bool locked; uint32_t response; } LobbyEnter;
typedef struct { u64 lobby, user_changed, making_change; uint32_t state; } LobbyChatUpdate;
typedef struct { u64 lobby, friend_id; } GameLobbyJoinRequested;
typedef struct { u64 friend_id; char connect[256]; } GameRichPresenceJoinRequested;
typedef struct { u64 game_id; uint32_t ip; uint16_t port, query_port; u64 lobby; } FriendGameInfo;
#pragma pack(pop)

#define CB_LOBBY_JOIN_REQUESTED 333
#define CB_RICH_PRESENCE_JOIN   337
#define CB_LOBBY_ENTER          504
#define CB_LOBBY_CHAT_UPDATE    506
#define CB_LOBBY_CREATED        513
#define CB_CALL_COMPLETED       703
#define CB_SESSION_REQUEST      1251
#define CB_SESSION_FAILED       1252

#define SEND_UNRELIABLE_NO_NAGLE 1
#define SEND_RELIABLE            8
#define IDENT_SIZE               160 /* real size 136, kept opaque */

static struct {
    bool (__cdecl *IsSteamRunning)(void);
    int (__cdecl *InitFlat)(char *err);
    void (__cdecl *Shutdown)(void);
    int32_t (__cdecl *GetHSteamPipe)(void);
    void (__cdecl *DispatchInit)(void);
    void (__cdecl *RunFrame)(int32_t);
    bool (__cdecl *GetNextCallback)(int32_t, CallbackMsg *);
    void (__cdecl *FreeLastCallback)(int32_t);
    bool (__cdecl *GetAPICallResult)(int32_t, u64, void *, int, int, bool *);
    void *(__cdecl *User)(void);
    void *(__cdecl *Matchmaking)(void);
    void *(__cdecl *Friends)(void);
    void *(__cdecl *Messages)(void);
    void *(__cdecl *Utils)(void);
    u64 (__cdecl *GetSteamID)(void *);
    u64 (__cdecl *CreateLobby)(void *, int, int);
    u64 (__cdecl *JoinLobby)(void *, u64);
    void (__cdecl *LeaveLobby)(void *, u64);
    bool (__cdecl *SetLobbyData)(void *, u64, const char *, const char *);
    const char *(__cdecl *GetLobbyData)(void *, u64, const char *);
    u64 (__cdecl *GetLobbyOwner)(void *, u64);
    int (__cdecl *GetNumLobbyMembers)(void *, u64);
    u64 (__cdecl *GetLobbyMemberByIndex)(void *, u64, int);
    bool (__cdecl *SetRichPresence)(void *, const char *, const char *);
    void (__cdecl *InviteDialog)(void *, u64);
    int (__cdecl *GetFriendCount)(void *, int);
    u64 (__cdecl *GetFriendByIndex)(void *, int, int);
    bool (__cdecl *GetFriendGamePlayed)(void *, u64, FriendGameInfo *);
    const char *(__cdecl *GetFriendPersonaName)(void *, u64);
    const char *(__cdecl *GetPersonaName)(void *);
    void (__cdecl *IdentSet)(void *, u64);
    u64 (__cdecl *IdentGet)(const void *);
    int (__cdecl *SendMessageToUser)(void *, const void *, const void *, uint32_t, int, int);
    int (__cdecl *ReceiveMessages)(void *, int, void **, int);
    bool (__cdecl *AcceptSession)(void *, const void *);
    bool (__cdecl *CloseSession)(void *, const void *);
    void (__cdecl *MessageRelease)(void *);
    bool (__cdecl *SetConfigInt)(void *, int, int32_t);
    void (__cdecl *InitRelay)(void *);
} S;

static void *g_user, *g_mm, *g_friends, *g_msgs, *g_utils;
static int32_t g_pipe;
static u64 g_me;

static void fail(const char *msg)
{
    printf("\n%s\n\nPress a key to close.\n", msg);
    _getch();
    exit(1);
}

static FARPROC need(HMODULE m, const char *name)
{
    FARPROC p = GetProcAddress(m, name);
    if (!p) {
        char buf[300];
        snprintf(buf, sizeof(buf), "steam_api.dll is missing %s (too old?).", name);
        fail(buf);
    }
    return p;
}

#define LOAD(field, name) *(FARPROC *)&S.field = need(m, name)
#define LOAD_OPT(field, name) *(FARPROC *)&S.field = GetProcAddress(m, name)

static void steam_start(void)
{
    FILE *f = fopen("steam_appid.txt", "r");
    if (f) fclose(f);
    else if ((f = fopen("steam_appid.txt", "w"))) { fputs("480", f); fclose(f); }

    HMODULE m = LoadLibraryA("steam_api.dll");
    if (!m) fail("steam_api.dll not found next to RevCoop.exe.");
    LOAD(IsSteamRunning, "SteamAPI_IsSteamRunning");
    LOAD(InitFlat, "SteamAPI_InitFlat");
    LOAD(Shutdown, "SteamAPI_Shutdown");
    LOAD(GetHSteamPipe, "SteamAPI_GetHSteamPipe");
    LOAD(DispatchInit, "SteamAPI_ManualDispatch_Init");
    LOAD(RunFrame, "SteamAPI_ManualDispatch_RunFrame");
    LOAD(GetNextCallback, "SteamAPI_ManualDispatch_GetNextCallback");
    LOAD(FreeLastCallback, "SteamAPI_ManualDispatch_FreeLastCallback");
    LOAD(GetAPICallResult, "SteamAPI_ManualDispatch_GetAPICallResult");
    LOAD(User, "SteamAPI_SteamUser_v023");
    LOAD(Matchmaking, "SteamAPI_SteamMatchmaking_v009");
    LOAD(Friends, "SteamAPI_SteamFriends_v018");
    LOAD(Messages, "SteamAPI_SteamNetworkingMessages_SteamAPI_v002");
    LOAD(Utils, "SteamAPI_SteamNetworkingUtils_SteamAPI_v004");
    LOAD(GetSteamID, "SteamAPI_ISteamUser_GetSteamID");
    LOAD(CreateLobby, "SteamAPI_ISteamMatchmaking_CreateLobby");
    LOAD(JoinLobby, "SteamAPI_ISteamMatchmaking_JoinLobby");
    LOAD(LeaveLobby, "SteamAPI_ISteamMatchmaking_LeaveLobby");
    LOAD(SetLobbyData, "SteamAPI_ISteamMatchmaking_SetLobbyData");
    LOAD(GetLobbyData, "SteamAPI_ISteamMatchmaking_GetLobbyData");
    LOAD(GetLobbyOwner, "SteamAPI_ISteamMatchmaking_GetLobbyOwner");
    LOAD(GetNumLobbyMembers, "SteamAPI_ISteamMatchmaking_GetNumLobbyMembers");
    LOAD(GetLobbyMemberByIndex, "SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex");
    LOAD(SetRichPresence, "SteamAPI_ISteamFriends_SetRichPresence");
    LOAD(InviteDialog, "SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialog");
    LOAD(GetFriendCount, "SteamAPI_ISteamFriends_GetFriendCount");
    LOAD(GetFriendByIndex, "SteamAPI_ISteamFriends_GetFriendByIndex");
    LOAD(GetFriendGamePlayed, "SteamAPI_ISteamFriends_GetFriendGamePlayed");
    LOAD(GetFriendPersonaName, "SteamAPI_ISteamFriends_GetFriendPersonaName");
    LOAD(GetPersonaName, "SteamAPI_ISteamFriends_GetPersonaName");
    LOAD(IdentSet, "SteamAPI_SteamNetworkingIdentity_SetSteamID64");
    LOAD(IdentGet, "SteamAPI_SteamNetworkingIdentity_GetSteamID64");
    LOAD(SendMessageToUser, "SteamAPI_ISteamNetworkingMessages_SendMessageToUser");
    LOAD(ReceiveMessages, "SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel");
    LOAD(AcceptSession, "SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser");
    LOAD(CloseSession, "SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser");
    LOAD(MessageRelease, "SteamAPI_SteamNetworkingMessage_t_Release");
    LOAD(SetConfigInt, "SteamAPI_ISteamNetworkingUtils_SetGlobalConfigValueInt32");
    LOAD_OPT(InitRelay, "SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess");

    if (!S.IsSteamRunning()) fail("Steam is not running. Start Steam, log in, and try again.");
    char err[1024] = "";
    int r = S.InitFlat(err);
    if (r != 0) {
        char buf[1200];
        snprintf(buf, sizeof(buf), "Could not connect to Steam (code %d): %s", r, err);
        fail(buf);
    }
    S.DispatchInit();
    g_pipe = S.GetHSteamPipe();
    g_user = S.User(); g_mm = S.Matchmaking(); g_friends = S.Friends();
    g_msgs = S.Messages(); g_utils = S.Utils();
    g_me = S.GetSteamID(g_user);
    if (S.InitRelay) S.InitRelay(g_utils);
}

static void ident(void *buf, u64 sid) { memset(buf, 0, IDENT_SIZE); S.IdentSet(buf, sid); }

/* Sender of a received SteamNetworkingMessage_t: identity at 16 (32 bit MSVC layout), 12 as fallback. */
static u64 msg_sender(void *msg)
{
    u64 sid = S.IdentGet((char *)msg + 16);
    if (!sid) sid = S.IdentGet((char *)msg + 12);
    return sid;
}

static int send_to(u64 sid, const void *data, int size, int flags, int channel)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    return S.SendMessageToUser(g_msgs, id, data, (uint32_t)size, flags, channel);
}

static void accept_session(u64 sid)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    S.AcceptSession(g_msgs, id);
}

static void close_session(u64 sid)
{
    unsigned char id[IDENT_SIZE];
    ident(id, sid);
    S.CloseSession(g_msgs, id);
}

static const char *friend_name(u64 sid)
{
    const char *n = S.GetFriendPersonaName(g_friends, sid);
    return n && *n ? n : "?";
}

/* ---------------------------------------------------------------- options, game launch */

static char g_game_dir[MAX_PATH];
static int g_port = 7790;
static char g_url_extra[512];
static char g_game_args[1024];
static bool g_no_launch;
static HANDLE g_game;

/* The co-op folder: the one with RevNet.u (and its copy of Revision.exe), normally our parent. */
static void find_game_dir(void)
{
    char exe[MAX_PATH], *slash;
    GetModuleFileNameA(NULL, exe, sizeof(exe));
    if ((slash = strrchr(exe, '\\'))) *slash = 0;
    const char *tries[] = { "%s\\..\\RevNet.u", "%s\\RevNet.u" };
    for (int i = 0; i < 2; i++) {
        char p[MAX_PATH];
        snprintf(p, sizeof(p), tries[i], exe);
        if (GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES) {
            char full[MAX_PATH];
            GetFullPathNameA(p, sizeof(full), full, NULL);
            if ((slash = strrchr(full, '\\'))) *slash = 0;
            snprintf(g_game_dir, sizeof(g_game_dir), "%s", full);
            return;
        }
    }
}

/* ---------------------------------------------------------------- modes, saves */

static char g_mode[64];          /* current mode name (Modes\<name>.mode) */
static char g_mode_title[128];
static char g_game_class[128];

static void mode_path(char *out, size_t size, const char *name, const char *ext)
{
    snprintf(out, size, "%s\\Modes\\%s%s", g_game_dir, name, ext);
}

static bool file_exists(const char *p) { return GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES; }

/* Mode names are file names chosen by the host: never trust them for path tricks. */
static bool valid_mode_name(const char *s)
{
    if (!*s || strlen(s) > 48) return false;
    for (; *s; s++) if (!((*s >= 'A' && *s <= 'Z') || (*s >= 'a' && *s <= 'z') || (*s >= '0' && *s <= '9') || *s == '_')) return false;
    return true;
}

/* Reads Title= and Game= of a mode; false when the mode file is missing. */
static bool load_mode(const char *name)
{
    char p[MAX_PATH], line[1024];
    if (!valid_mode_name(name)) return false;
    mode_path(p, sizeof(p), name, ".mode");
    FILE *f = fopen(p, "r");
    if (!f) return false;
    snprintf(g_mode, sizeof(g_mode), "%s", name);
    snprintf(g_mode_title, sizeof(g_mode_title), "%s", name);
    snprintf(g_game_class, sizeof(g_game_class), "RevNet.CoopGameInfo");
    while (fgets(line, sizeof(line), f)) {
        line[strcspn(line, "\r\n")] = 0;
        if (!strncmp(line, "Title=", 6)) snprintf(g_mode_title, sizeof(g_mode_title), "%s", line + 6);
        else if (!strncmp(line, "Game=", 5)) snprintf(g_game_class, sizeof(g_game_class), "%s", line + 5);
    }
    fclose(f);
    return true;
}

static bool is_mode_key(const char *line)
{
    return !_strnicmp(line, "Paths=", 6) || !_strnicmp(line, "OverrideLocalizationPaths=", 26) || !_strnicmp(line, "SavePath=", 9);
}

/* Replaces the package/map lines of RevNet.ini with the current mode's: in [Core.System]
   and in [RevisionInternal.LaunchSystem], which is what Revision.exe reads. */
static void apply_mode(void)
{
    char ini[MAX_PATH], tmp[MAX_PATH], mp[MAX_PATH], line[2048];
    snprintf(ini, sizeof(ini), "%s\\RevNet.ini", g_game_dir);
    snprintf(tmp, sizeof(tmp), "%s\\RevNet.ini.tmp", g_game_dir);
    mode_path(mp, sizeof(mp), g_mode, ".mode");
    FILE *in = fopen(ini, "r"), *out = fopen(tmp, "w"), *mf;
    if (!in || !out) fail("Could not update RevNet.ini (is the game folder read-only?).");
    bool in_system = false;
    while (fgets(line, sizeof(line), in)) {
        char *t = line + strspn(line, " \t");
        if (*t == '[') {
            in_system = !_strnicmp(t, "[Core.System]", 13) || !_strnicmp(t, "[RevisionInternal.LaunchSystem]", 31);
            fputs(line, out);
            if (in_system && (mf = fopen(mp, "r"))) {
                char ml[1024];
                while (fgets(ml, sizeof(ml), mf)) if (is_mode_key(ml)) fputs(ml, out);
                fclose(mf);
            }
            continue;
        }
        if (in_system && is_mode_key(t)) continue;
        fputs(line, out);
    }
    fclose(in); fclose(out);
    if (!MoveFileExA(tmp, ini, MOVEFILE_REPLACE_EXISTING)) fail("Could not replace RevNet.ini.");
}

/* Current mode: Modes\current.txt, else the first .mode file found. */
static void pick_default_mode(void)
{
    char p[MAX_PATH], name[64] = "";
    snprintf(p, sizeof(p), "%s\\Modes\\current.txt", g_game_dir);
    FILE *f = fopen(p, "r");
    if (f) { if (fgets(name, sizeof(name), f)) name[strcspn(name, "\r\n")] = 0; fclose(f); }
    if (load_mode(name)) return;
    WIN32_FIND_DATAA fd;
    mode_path(p, sizeof(p), "*", ".mode");
    HANDLE h = FindFirstFileA(p, &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            char *dot = strrchr(fd.cFileName, '.');
            if (dot) *dot = 0;
            if (load_mode(fd.cFileName)) break;
        } while (FindNextFileA(h, &fd));
        FindClose(h);
    }
    if (!g_mode[0]) fail("No modes found (Modes\\*.mode). Run the installer again.");
}

static void save_current_mode(void)
{
    char p[MAX_PATH];
    snprintf(p, sizeof(p), "%s\\Modes\\current.txt", g_game_dir);
    FILE *f = fopen(p, "w");
    if (f) { fputs(g_mode, f); fclose(f); }
}

/* Lets the host cycle through the installed modes. */
static void choose_mode(void)
{
    char names[16][64], p[MAX_PATH], was[64];
    int n = 0, cur = 0;
    WIN32_FIND_DATAA fd;
    snprintf(was, sizeof(was), "%s", g_mode);
    mode_path(p, sizeof(p), "*", ".mode");
    HANDLE h = FindFirstFileA(p, &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        char *dot = strrchr(fd.cFileName, '.');
        if (dot) *dot = 0;
        if (n < 16 && valid_mode_name(fd.cFileName)) snprintf(names[n++], 64, "%s", fd.cFileName);
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    printf("\nModes (the host's choice applies to everyone):\n");
    for (int i = 0; i < n; i++) {
        load_mode(names[i]);
        printf("  %d) %s\n", i + 1, g_mode_title);
        if (!_stricmp(names[i], was)) cur = i;
    }
    printf("Choose a number: ");
    for (;;) {
        int c = _getch();
        if (c >= '1' && c < '1' + n) { cur = c - '1'; break; }
        if (c == 27) break;
    }
    load_mode(names[cur]);
    save_current_mode();
    printf("%d\n", cur + 1);
}

/* ---------------------------------------------------------------- host settings */

/* The host's game settings; the server decides, so they apply to everyone.
   Kept in Modes\settings.txt. Difficulty goes in the host URL, friendly fire in RevNet.ini. */
static int g_difficulty = 1;   /* 0 Easy, 1 Medium, 2 Hard, 3 Deus Ex */
static int g_friendly_fire = 0; /* index into ff_values */
static const char *difficulty_names[] = { "Easy", "Medium", "Hard", "Deus Ex" };
static const char *ff_values[] = { "0.000000", "0.500000", "1.000000" };
static const char *ff_names[] = { "off", "half damage", "full damage" };
/* CoopGameInfo.DeathRule and SaveRule. */
static int g_death = 0, g_saves = 0;
static const char *death_names[] = { "a teammate revives you with a medkit, else the team reloads", "the team reloads the last save at once" };
static const char *save_names[] = { "quick saves and autosaves", "autosaves only (harder)" };

static void load_settings(void)
{
    char p[MAX_PATH], line[128];
    snprintf(p, sizeof(p), "%s\\Modes\\settings.txt", g_game_dir);
    FILE *f = fopen(p, "r");
    if (!f) return;
    while (fgets(line, sizeof(line), f)) {
        if (!strncmp(line, "Difficulty=", 11)) g_difficulty = atoi(line + 11) & 3;
        else if (!strncmp(line, "FriendlyFire=", 13)) { g_friendly_fire = atoi(line + 13); if (g_friendly_fire < 0 || g_friendly_fire > 2) g_friendly_fire = 0; }
        else if (!strncmp(line, "Death=", 6)) g_death = atoi(line + 6) & 1;
        else if (!strncmp(line, "Saves=", 6)) g_saves = atoi(line + 6) & 1;
    }
    fclose(f);
}

static void save_settings(void)
{
    char p[MAX_PATH];
    snprintf(p, sizeof(p), "%s\\Modes\\settings.txt", g_game_dir);
    FILE *f = fopen(p, "w");
    if (f) { fprintf(f, "Difficulty=%d\nFriendlyFire=%d\nDeath=%d\nSaves=%d\n", g_difficulty, g_friendly_fire, g_death, g_saves); fclose(f); }
}

/* Sets Key=Value in [Section] of an ini in the co-op folder (the line is replaced, or added
   to the section; a missing ini is created). */
static void set_ini_key(const char *file, const char *section, const char *key, const char *value)
{
    char ini[MAX_PATH], tmp[MAX_PATH], line[2048], head[160];
    size_t klen = strlen(key);
    snprintf(ini, sizeof(ini), "%s\\%s", g_game_dir, file);
    snprintf(tmp, sizeof(tmp), "%s\\%s.tmp", g_game_dir, file);
    snprintf(head, sizeof(head), "[%s]", section);
    FILE *in = fopen(ini, "r"), *out = fopen(tmp, "w");
    if (!out) { snprintf(line, sizeof(line), "Could not update %s (is the game folder read-only?).", file); fail(line); }
    bool in_section = false, done = false;
    while (in && fgets(line, sizeof(line), in)) {
        if (line[0] == '[') {
            if (in_section && !done) { fprintf(out, "%s=%s\n", key, value); done = true; }
            in_section = !_strnicmp(line, head, strlen(head));
        } else if (in_section && !_strnicmp(line, key, klen) && line[klen] == '=') {
            if (!done) fprintf(out, "%s=%s\n", key, value);
            done = true;
            continue;
        }
        fputs(line, out);
    }
    if (!done) {  /* the file ended inside the section, or there was none */
        if (!in_section) fprintf(out, "[%s]\n", section);
        fprintf(out, "%s=%s\n", key, value);
    }
    if (in) fclose(in);
    fclose(out);
    if (!MoveFileExA(tmp, ini, MOVEFILE_REPLACE_EXISTING)) { snprintf(line, sizeof(line), "Could not replace %s.", file); fail(line); }
}

/* The host's server reads these from RevNet.ini; Mode names its co-op save section. */
static void apply_settings(void)
{
    char n[8];
    set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", "FriendlyFire", ff_values[g_friendly_fire]);
    set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", "Mode", g_mode);
    snprintf(n, sizeof(n), "%d", g_death);
    set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", "DeathRule", n);
    snprintf(n, sizeof(n), "%d", g_saves);
    set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", "SaveRule", n);
}

static void choose_settings(void)
{
    for (;;) {
        printf("\nHost settings (they apply to everyone in your game):\n"
               "  1) Difficulty: %s\n  2) Friendly fire: %s\n  3) When a player dies: %s\n  4) Saves: %s\n"
               "Press 1-4 to change, Enter when done: ",
               difficulty_names[g_difficulty], ff_names[g_friendly_fire], death_names[g_death], save_names[g_saves]);
        int c = _getch();
        if (c == '1') g_difficulty = (g_difficulty + 1) & 3;
        else if (c == '2') g_friendly_fire = (g_friendly_fire + 1) % 3;
        else if (c == '3') g_death ^= 1;
        else if (c == '4') g_saves ^= 1;
        else break;
    }
    save_settings();
    printf("\n");
}

/* "?Name=<Steam name>" for the game URL. Co-op saves give returning players their gear by
   name, so the Steam name keeps that working without anyone setting a name in the game. URL
   option separators and spaces are left out; at most 20 characters. */
static void name_option(char *out, size_t size)
{
    const char *n = S.GetPersonaName(g_friends);
    char clean[21]; int k = 0;
    for (; n && *n && k < 20; n++) {
        unsigned char c = (unsigned char)*n;
        if (c > 32 && c < 127 && c != '?' && c != '#' && c != '=' && c != '/' && c != '\\' && c != '"' && c != '|')
            clean[k++] = (char)c;
    }
    clean[k] = 0;
    if (k) snprintf(out, size, "?Name=%s", clean); else out[0] = 0;
}

/* The game opens AutoOpen once from its menu map (RevNet.CoopLaunch). */
static void set_auto_open(const char *url)
{
    set_ini_key("RevNetUser.ini", "RevNet.CoopLaunch", "AutoOpen", url);
}

static void launch_game(const char *url)
{
    if (g_no_launch) return;
    char cmd[2048], exe[MAX_PATH];
    set_auto_open(url);
    snprintf(exe, sizeof(exe), "%s\\Revision.exe", g_game_dir);
    /* The game's working folder is the co-op folder: its steam_appid.txt (397550) keeps
       Revision.exe from restarting itself through Steam without these arguments. */
    snprintf(cmd, sizeof(cmd), "\"%s\" INI=RevNet.ini USERINI=RevNetUser.ini %s", exe, g_game_args);
    STARTUPINFOA si; PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si)); si.cb = sizeof(si);
    if (!CreateProcessA(exe, cmd, NULL, NULL, FALSE, 0, NULL, g_game_dir, &si, &pi)) {
        char buf[MAX_PATH + 100];
        snprintf(buf, sizeof(buf), "Could not start %s (error %lu).", exe, GetLastError());
        fail(buf);
    }
    CloseHandle(pi.hThread);
    g_game = pi.hProcess;
    printf("Started the game: %s\n", url);
}

static bool game_exited(void)
{
    return g_game && WaitForSingleObject(g_game, 0) == WAIT_OBJECT_0;
}

/* ---------------------------------------------------------------- callbacks */

typedef void (*CbHandler)(int id, void *data);

static void pump(CbHandler h)
{
    CallbackMsg msg;
    S.RunFrame(g_pipe);
    while (S.GetNextCallback(g_pipe, &msg)) {
        if (msg.callback == CB_CALL_COMPLETED) {
            APICallCompleted *done = (APICallCompleted *)msg.param;
            void *buf = calloc(1, done->param_size + 16);
            bool failed = true;
            if (S.GetAPICallResult(g_pipe, done->call, buf, done->param_size, done->callback, &failed) && !failed)
                h(done->callback, buf);
            free(buf);
        } else
            h(msg.callback, msg.param);
        S.FreeLastCallback(g_pipe);
    }
}

/* ---------------------------------------------------------------- udp helpers */

static SOCKET udp_socket(int port)
{
    SOCKET s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK); a.sin_port = htons((u_short)port);
    if (bind(s, (struct sockaddr *)&a, sizeof(a)) != 0) { closesocket(s); return INVALID_SOCKET; }
    u_long nb = 1; ioctlsocket(s, FIONBIO, &nb);
    DWORD bytes; BOOL off = FALSE; /* SIO_UDP_CONNRESET: ignore ICMP port unreachable */
    WSAIoctl(s, 0x9800000C, &off, sizeof(off), NULL, 0, &bytes, NULL, NULL);
    int buf = 1 << 20;
    setsockopt(s, SOL_SOCKET, SO_RCVBUF, (char *)&buf, sizeof(buf));
    setsockopt(s, SOL_SOCKET, SO_SNDBUF, (char *)&buf, sizeof(buf));
    return s;
}

static int local_port(SOCKET s)
{
    struct sockaddr_in a; int len = sizeof(a);
    getsockname(s, (struct sockaddr *)&a, &len);
    return ntohs(a.sin_port);
}

static void relay_config(void)
{
    /* k_ESteamNetworkingConfig_SendBufferSize 9, RecvBufferSize 47, RecvMaxMessageSize 49 */
    S.SetConfigInt(g_utils, 9, 4 << 20);
    S.SetConfigInt(g_utils, 47, 4 << 20);
}

/* ---------------------------------------------------------------- host */

#define MAX_PEERS 16
#define MAX_CONNS 8
typedef struct { int id; SOCKET s; DWORD last; } Conn;
typedef struct { u64 sid; Conn conns[MAX_CONNS]; DWORD last_heard, last_ping; } Peer;
static Peer g_peers[MAX_PEERS];
static u64 g_lobby;
static bool g_lobby_failed;

/* Anyone who knows a Steam id can ask it for a session: only members of our friends-only
   lobby get through to the game. */
static bool in_lobby(u64 sid)
{
    int n = S.GetNumLobbyMembers(g_mm, g_lobby);
    for (int i = 0; i < n; i++) if (S.GetLobbyMemberByIndex(g_mm, g_lobby, i) == sid) return true;
    return false;
}

static Peer *find_peer(u64 sid)
{
    for (int i = 0; i < MAX_PEERS; i++) if (g_peers[i].sid == sid) return &g_peers[i];
    return NULL;
}

static void drop_peer(Peer *p, const char *why)
{
    if (!p || !p->sid) return;
    printf("%s left (%s).\n", friend_name(p->sid), why);
    for (int i = 0; i < MAX_CONNS; i++) if (p->conns[i].s) closesocket(p->conns[i].s);
    close_session(p->sid);
    memset(p, 0, sizeof(*p));
}

static SOCKET game_socket(void)
{
    SOCKET s = udp_socket(0);
    if (s == INVALID_SOCKET) return s;
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK); a.sin_port = htons((u_short)g_port);
    connect(s, (struct sockaddr *)&a, sizeof(a));
    return s;
}

static Peer *add_peer(u64 sid)
{
    for (int i = 0; i < MAX_PEERS; i++) {
        Peer *p = &g_peers[i];
        if (p->sid) continue;
        memset(p, 0, sizeof(*p));
        p->sid = sid; p->last_heard = p->last_ping = GetTickCount();
        printf("%s connected through Steam.\n", friend_name(sid));
        return p;
    }
    return NULL;
}

/* The socket for one game connection of a peer, created on first use. Connections idle
   for 30 s are closed, the oldest one is reused when all slots are taken. */
static Conn *peer_conn(Peer *p, int id)
{
    Conn *free_slot = NULL, *oldest = &p->conns[0];
    for (int i = 0; i < MAX_CONNS; i++) {
        Conn *c = &p->conns[i];
        if (c->s && c->id == id) return c;
        if (!c->s && !free_slot) free_slot = c;
        if (c->last < oldest->last) oldest = c;
    }
    if (!free_slot) { closesocket(oldest->s); memset(oldest, 0, sizeof(*oldest)); free_slot = oldest; }
    free_slot->s = game_socket();
    if (free_slot->s == INVALID_SOCKET) { free_slot->s = 0; return NULL; }
    free_slot->id = id; free_slot->last = GetTickCount();
    return free_slot;
}

static void host_cb(int id, void *data)
{
    switch (id) {
    case CB_LOBBY_CREATED: {
        LobbyCreated *c = data;
        if (c->result != 1) { g_lobby_failed = true; break; }
        g_lobby = c->lobby;
        char buf[64];
        S.SetLobbyData(g_mm, g_lobby, "revcoop", REVCOOP_PROTOCOL);
        S.SetLobbyData(g_mm, g_lobby, "mode", g_mode);
        S.SetLobbyData(g_mm, g_lobby, "host", S.GetPersonaName(g_friends));
        snprintf(buf, sizeof(buf), "+connect_lobby %llu", (unsigned long long)g_lobby);
        S.SetRichPresence(g_friends, "connect", buf);
        S.SetRichPresence(g_friends, "status", "Hosting Deus Ex: Revision co-op");
        break;
    }
    case CB_SESSION_REQUEST: {
        u64 sid = S.IdentGet(data);
        if (in_lobby(sid)) accept_session(sid);
        else printf("Ignored a connection from %s (not in your lobby).\n", friend_name(sid));
        break;
    }
    case CB_SESSION_FAILED: {
        u64 sid = S.IdentGet((char *)data + 0);
        drop_peer(find_peer(sid), "connection failed");
        break;
    }
    case CB_LOBBY_CHAT_UPDATE: {
        LobbyChatUpdate *u = data;
        if (u->state & (0x2 | 0x4 | 0x8 | 0x10)) drop_peer(find_peer(u->user_changed), "left the lobby");
        break;
    }
    }
}

/* Map of the current mode's co-op save: SavedMap= in [<mode>] of RevNetSave.ini
   (written by RevNet.CoopSave, one per-object section per mode, named by the object
   alone; empty when there is no save). */
static bool read_saved_map(char *out, size_t size)
{
    char path[MAX_PATH], line[512], head[96];
    bool in_section = false;
    out[0] = 0;
    snprintf(path, sizeof(path), "%s\\RevNetSave.ini", g_game_dir);
    snprintf(head, sizeof(head), "[%s]", g_mode);
    FILE *f = fopen(path, "r");
    if (!f) return false;
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '[') { in_section = !_strnicmp(line, head, strlen(head)); continue; }
        if (in_section && !strncmp(line, "SavedMap=", 9)) {
            snprintf(out, size, "%s", line + 9);
            out[strcspn(out, "\r\n")] = 0;
            break;
        }
    }
    fclose(f);
    return out[0] != 0;
}

static int run_host(const char *map)
{
    S.CreateLobby(g_mm, 1 /* friends only */, MAX_PEERS + 1);
    printf("Creating a friends-only Steam lobby...\n");
    DWORD t0 = GetTickCount();
    while (!g_lobby && !g_lobby_failed && GetTickCount() - t0 < 15000) { pump(host_cb); Sleep(20); }
    if (!g_lobby) fail("Steam did not create a lobby. Check that you are online in Steam.");

    char url[1024], name[32];
    apply_settings();
    name_option(name, sizeof(name));
    snprintf(url, sizeof(url), "%s?Listen?Port=%d?Game=%s?Difficulty=%d%s%s", map, g_port, g_game_class, g_difficulty, name, g_url_extra);
    launch_game(url);

    printf("\nHosting %s. Friends join by running Revision Co-op and choosing Join\n"
           "(or Steam friends list: right-click you -> Join Game, with Revision Co-op already open).\n"
           "Lobby id: %llu\nKeep this window open while you play. Close the game to stop.\n\n",
           g_mode_title, (unsigned long long)g_lobby);

    static unsigned char buf[65536];
    for (;;) {
        pump(host_cb);
        void *msgs[64];
        int n;
        while ((n = S.ReceiveMessages(g_msgs, 0, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                u64 sid = msg_sender(msgs[i]);
                Peer *p = find_peer(sid);
                if (!p && in_lobby(sid)) p = add_peer(sid);
                unsigned char *data = *(unsigned char **)msgs[i];
                int size = *(int *)((char *)msgs[i] + 4);
                if (p && size > 1) {
                    Conn *c = peer_conn(p, data[0]);
                    p->last_heard = GetTickCount();
                    if (c) { c->last = p->last_heard; send(c->s, (char *)data + 1, size - 1, 0); }
                }
                S.MessageRelease(msgs[i]);
            }
        }
        while ((n = S.ReceiveMessages(g_msgs, 1, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                Peer *p = find_peer(msg_sender(msgs[i]));
                if (p) {
                    p->last_heard = GetTickCount();
                    if (*(int *)((char *)msgs[i] + 4) >= 1 && (*(char **)msgs[i])[0] == 'B') drop_peer(p, "quit");
                }
                S.MessageRelease(msgs[i]);
            }
        }
        DWORD now = GetTickCount();
        for (int i = 0; i < MAX_PEERS; i++) {
            Peer *p = &g_peers[i];
            if (!p->sid) continue;
            for (int k = 0; k < MAX_CONNS; k++) {
                Conn *c = &p->conns[k];
                int got;
                if (!c->s) continue;
                while ((got = recv(c->s, (char *)buf + 1, sizeof(buf) - 1, 0)) > 0) {
                    buf[0] = (unsigned char)c->id;
                    c->last = now;
                    send_to(p->sid, buf, got + 1, SEND_UNRELIABLE_NO_NAGLE, 0);
                }
                if (c->s && now - c->last > 30000) { closesocket(c->s); memset(c, 0, sizeof(*c)); }
            }
            if (now - p->last_ping > 1000) { p->last_ping = now; send_to(p->sid, "K", 1, SEND_RELIABLE, 1); }
            if (now - p->last_heard > 20000) drop_peer(p, "timed out");
        }
        if (game_exited()) break;
        Sleep(1);
    }
    for (int i = 0; i < MAX_PEERS; i++)
        if (g_peers[i].sid) { send_to(g_peers[i].sid, "B", 1, SEND_RELIABLE, 1); drop_peer(&g_peers[i], "host closed"); }
    S.LeaveLobby(g_mm, g_lobby);
    S.SetRichPresence(g_friends, "connect", "");
    S.SetRichPresence(g_friends, "status", "");
    for (int i = 0; i < 20; i++) { pump(host_cb); Sleep(10); }
    return 0;
}

/* ---------------------------------------------------------------- join */

static u64 g_join_lobby, g_host;
static bool g_join_failed;

static u64 parse_connect(const char *s)
{
    const char *p = strstr(s, "+connect_lobby");
    if (!p) return 0;
    return strtoull(p + 14, NULL, 10);
}

static void join_cb(int id, void *data)
{
    switch (id) {
    case CB_LOBBY_JOIN_REQUESTED:
        if (!g_join_lobby) g_join_lobby = ((GameLobbyJoinRequested *)data)->lobby;
        break;
    case CB_RICH_PRESENCE_JOIN:
        if (!g_join_lobby) g_join_lobby = parse_connect(((GameRichPresenceJoinRequested *)data)->connect);
        break;
    case CB_LOBBY_ENTER: {
        LobbyEnter *e = data;
        if (e->lobby != g_join_lobby) break;
        if (e->response != 1) { g_join_failed = true; break; }
        g_host = S.GetLobbyOwner(g_mm, e->lobby);
        break;
    }
    case CB_SESSION_REQUEST: {
        u64 sid = S.IdentGet(data);
        if (sid == g_host) accept_session(sid);
        break;
    }
    }
}

/* Friends who host: in a lobby (revcoop=<protocol>, checked after joining) while Steam shows
   them in AppID 480 (this relay) or 397550 (the game also signs in to Steam, as Revision). */
static int list_hosting_friends(u64 *lobbies, u64 *owners, int max)
{
    int n = 0, count = S.GetFriendCount(g_friends, 0x04 /* immediate */);
    for (int i = 0; i < count && n < max; i++) {
        u64 f = S.GetFriendByIndex(g_friends, i, 0x04);
        FriendGameInfo gi;
        memset(&gi, 0, sizeof(gi));
        if (!S.GetFriendGamePlayed(g_friends, f, &gi)) continue;
        unsigned app = (unsigned)(gi.game_id & 0xFFFFFF);
        if ((app != 480 && app != 397550) || !gi.lobby) continue;
        lobbies[n] = gi.lobby; owners[n] = f; n++;
    }
    return n;
}

static void pick_lobby(void)
{
    u64 lobbies[32], owners[32];
    int shown = -1;
    printf("Looking for Steam friends who are hosting...\n"
           "(You can also accept a Steam invite, or type a lobby id and press Enter.)\n");
    char typed[64] = ""; int tl = 0;
    while (!g_join_lobby) {
        pump(join_cb);
        int n = list_hosting_friends(lobbies, owners, 32);
        if (n == 1) {
            printf("Found %s.\n", friend_name(owners[0]));
            g_join_lobby = lobbies[0];
            break;
        }
        if (n > 1 && n != shown) {
            printf("\nFriends hosting:\n");
            for (int i = 0; i < n; i++) printf("  %d) %s\n", i + 1, friend_name(owners[i]));
            printf("Type a number and press Enter: ");
            shown = n;
        }
        while (_kbhit()) {
            int c = _getch();
            if (c == '\r') {
                printf("\n");
                u64 v = strtoull(typed, NULL, 10);
                if (v >= 1 && v <= (u64)n) g_join_lobby = lobbies[v - 1];
                else if (v > 1000) g_join_lobby = v;
                tl = 0; typed[0] = 0;
            } else if (c >= '0' && c <= '9' && tl < 60) { typed[tl++] = (char)c; typed[tl] = 0; putchar(c); }
        }
        Sleep(50);
    }
}

static int run_join(u64 lobby)
{
    g_join_lobby = lobby;
    if (!g_join_lobby) pick_lobby();

    for (int attempt = 0; attempt < 3 && !g_host; attempt++) {
        g_join_failed = false;
        printf("Joining lobby %llu...\n", (unsigned long long)g_join_lobby);
        S.JoinLobby(g_mm, g_join_lobby);
        DWORD t0 = GetTickCount();
        while (!g_host && !g_join_failed && GetTickCount() - t0 < 15000) { pump(join_cb); Sleep(20); }
    }
    if (!g_host) fail("Could not join the lobby. Is your friend still hosting?");
    const char *tag = S.GetLobbyData(g_mm, g_join_lobby, "revcoop");
    if (!tag || !*tag) fail("That lobby is not a Revision co-op game.");
    if (strcmp(tag, REVCOOP_PROTOCOL) != 0)
        fail("Your friend has a different version of Revision Co-op. Both of you need the same version (download and run the installer again).");
    const char *host_mode = S.GetLobbyData(g_mm, g_join_lobby, "mode");
    if (!load_mode(host_mode ? host_mode : "")) {
        char buf[200];
        snprintf(buf, sizeof(buf), "Your friend hosts mode \"%s\", which is not installed here. Run the installer again.", host_mode ? host_mode : "?");
        fail(buf);
    }
    apply_mode();
    printf("Host: %s, mode: %s\n", friend_name(g_host), g_mode_title);
    accept_session(g_host);

    SOCKET s = udp_socket(0);
    if (s == INVALID_SOCKET) fail("Could not open a local UDP port.");
    int port = local_port(s);
    char url[256], name[32];
    name_option(name, sizeof(name));
    snprintf(url, sizeof(url), "127.0.0.1:%d%s", port, name);
    launch_game(url);
    printf("Relaying 127.0.0.1:%d <-> %s over Steam. Keep this window open. Close the game to stop.\n", port, friend_name(g_host));

    /* one id per game source address (connection), see the top of the file */
    struct sockaddr_in games[MAX_CONNS]; DWORD games_last[MAX_CONNS]; int games_n = 0;
    unsigned char next_id = 0, ids[MAX_CONNS];
    static unsigned char buf[65536];
    DWORD last_heard = GetTickCount(), last_ping = 0, warned = 0;
    for (;;) {
        pump(join_cb);
        struct sockaddr_in from; int fl = sizeof(from), got;
        while ((got = recvfrom(s, (char *)buf + 1, sizeof(buf) - 1, 0, (struct sockaddr *)&from, &fl)) > 0) {
            int k;
            for (k = 0; k < games_n; k++)
                if (games[k].sin_port == from.sin_port && games[k].sin_addr.s_addr == from.sin_addr.s_addr) break;
            if (k == games_n) {
                if (games_n < MAX_CONNS) games_n++;
                else { k = 0; for (int j = 1; j < MAX_CONNS; j++) if (games_last[j] < games_last[k]) k = j; }
                games[k] = from; ids[k] = next_id++;
            }
            games_last[k] = GetTickCount();
            buf[0] = ids[k];
            send_to(g_host, buf, got + 1, SEND_UNRELIABLE_NO_NAGLE, 0);
            fl = sizeof(from);
        }
        void *msgs[64]; int n;
        while ((n = S.ReceiveMessages(g_msgs, 0, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                unsigned char *data = *(unsigned char **)msgs[i];
                int size = *(int *)((char *)msgs[i] + 4);
                if (msg_sender(msgs[i]) == g_host && size > 1) {
                    last_heard = GetTickCount();
                    for (int k = 0; k < games_n; k++)
                        if (ids[k] == data[0]) { sendto(s, (char *)data + 1, size - 1, 0, (struct sockaddr *)&games[k], sizeof(games[k])); break; }
                }
                S.MessageRelease(msgs[i]);
            }
        }
        while ((n = S.ReceiveMessages(g_msgs, 1, msgs, 64)) > 0) {
            for (int i = 0; i < n; i++) {
                if (msg_sender(msgs[i]) == g_host) {
                    last_heard = GetTickCount();
                    if (*(int *)((char *)msgs[i] + 4) >= 1 && (*(char **)msgs[i])[0] == 'B') printf("The host closed the game.\n");
                }
                S.MessageRelease(msgs[i]);
            }
        }
        DWORD now = GetTickCount();
        if (now - last_ping > 1000) { last_ping = now; send_to(g_host, "K", 1, SEND_RELIABLE, 1); }
        if (now - last_heard > 20000 && now - warned > 20000) { warned = now; printf("No answer from the host for 20 s...\n"); }
        if (game_exited()) break;
        if (g_no_launch && _kbhit() && _getch() == 27) break;
        Sleep(1);
    }
    send_to(g_host, "B", 1, SEND_RELIABLE, 1);
    S.LeaveLobby(g_mm, g_join_lobby);
    for (int i = 0; i < 20; i++) { pump(join_cb); Sleep(10); }
    close_session(g_host);
    return 0;
}

/* ---------------------------------------------------------------- main */

int main(int argc, char **argv)
{
    const char *mode = NULL, *arg = NULL, *want_mode = NULL, *apply_only = NULL, *open_url = NULL;
    SetConsoleTitleA("Deus Ex: Revision Co-op");
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--game") && i + 1 < argc) snprintf(g_game_dir, sizeof(g_game_dir), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--mode") && i + 1 < argc) want_mode = argv[++i];
        else if (!strcmp(argv[i], "--apply-mode") && i + 1 < argc) apply_only = argv[++i];
        else if (!strcmp(argv[i], "--open") && i + 1 < argc) open_url = argv[++i];
        else if (!strcmp(argv[i], "--port") && i + 1 < argc) g_port = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--url-extra") && i + 1 < argc) snprintf(g_url_extra, sizeof(g_url_extra), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--game-args") && i + 1 < argc) snprintf(g_game_args, sizeof(g_game_args), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--no-launch")) g_no_launch = true;
        else if (!strcmp(argv[i], "+connect_lobby") && i + 1 < argc) { mode = "join"; arg = argv[++i]; }
        else if (!mode) mode = argv[i];
        else if (!arg) arg = argv[i];
    }
    if (!g_game_dir[0]) find_game_dir();
    if (!g_game_dir[0]) fail("The co-op game folder (RevNet.u) was not found. Run the Revision Co-op installer again.");

    if (apply_only) {  /* IP launchers: select a mode (and the URL to open) without Steam */
        if (!load_mode(apply_only)) fail("Unknown mode.");
        apply_mode();
        save_current_mode();
        load_settings();
        apply_settings();
        if (open_url) set_auto_open(open_url);
        return 0;
    }
    if (want_mode && !load_mode(want_mode)) fail("Unknown mode.");
    if (!want_mode) pick_default_mode();
    load_settings();

    WSADATA w;
    WSAStartup(MAKEWORD(2, 2), &w);
    steam_start();
    relay_config();
    printf("Deus Ex: Revision Co-op over Steam - signed in as %s\n\n", S.GetPersonaName(g_friends));

    while (!mode) {
        printf("  1) Host a game\n  2) Join a friend's game\n  3) Continue saved game\n  4) Mode: %s\n"
               "  5) Settings: %s difficulty, friendly fire %s\n\nChoose 1-5: ",
               g_mode_title, difficulty_names[g_difficulty], ff_names[g_friendly_fire]);
        for (;;) {
            int c = _getch();
            if (c == '1') { mode = "host"; break; }
            if (c == '2') { mode = "join"; break; }
            if (c == '3') { mode = "continue"; break; }
            if (c == '4') { printf("4\n"); choose_mode(); printf("\n"); break; }
            if (c == '5') { printf("5\n"); choose_settings(); break; }
            if (c == 27) return 0;
        }
        if (mode) printf("%c\n\n", mode[0] == 'h' ? '1' : mode[0] == 'j' ? '2' : '3');
    }
    int r;
    if (_stricmp(mode, "join"))  /* host and continue run the host's mode */
        apply_mode();
    if (!_stricmp(mode, "continue")) {
        char saved[128];
        if (!read_saved_map(saved, sizeof(saved)))
            fail("No saved game for this mode. Host a game first: it saves a few seconds into every map, and when the host quick-saves.");
        printf("Continuing the saved game on %s\n", saved);
        strncat(g_url_extra, "?CoopLoad=1", sizeof(g_url_extra) - strlen(g_url_extra) - 1);
        r = run_host(saved);
    }
    else if (!_stricmp(mode, "host")) r = run_host(arg ? arg : "01_NYC_UNATCOIsland");
    else if (!_stricmp(mode, "join")) r = run_join(arg ? strtoull(arg, NULL, 10) : 0);
    else fail("Usage: RevCoop.exe [host [map] | join [lobby id] | continue]");
    S.Shutdown();
    return r;
}
