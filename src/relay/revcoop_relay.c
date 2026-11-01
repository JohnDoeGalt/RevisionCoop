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
 * A window (Win32, no console): mode and host settings, host / continue, the friends who
 * host, and a log. Steam and the relay run on a worker thread; the window never calls Steam.
 *   RevCoop.exe                    the window
 *   RevCoop.exe host [map]         the window, hosting at once (default map 01_NYC_UNATCOIsland)
 *   RevCoop.exe join <lobby id>    the window, joining at once
 *   RevCoop.exe continue           the window, hosting the saved game of the current mode
 * Options: --game <co-op folder>  --port <game port, 7790>  --url-extra <?opts for the host URL>
 *          --game-args <extra Revision.exe arguments>  --no-launch (relay only)  --mode <name>
 *          --apply-mode <name> (write the mode and settings into RevNet.ini and exit; IP launchers)
 *          --open <url> (with --apply-mode: also set the URL the game opens)
 * Test build: build.bat fake -> RevCoopFake.exe, Steam faked between two relays on one PC
 * (REVCOOP_FAKE_STEAM, see steam_start; tools/run_relay_test.ps1).
 */
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <intrin.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <setjmp.h>
#include <commctrl.h>
#include <shellapi.h>
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

typedef uint64_t u64;

/* Lobbies only match this exact value: bump it when packages or the relay protocol change. */
#define REVCOOP_PROTOCOL "6"

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

/* ---------------------------------------------------------------- window <-> worker */

/* The worker tells the window through posted messages carrying a malloc'd UTF-8 string
   (the window frees it). */
enum { WM_APP_LOG = WM_APP + 1, WM_APP_STATUS, WM_APP_ERROR, WM_APP_READY, WM_APP_SESSION, WM_APP_FRIENDS, WM_APP_FATAL };
static HWND g_wnd;
static DWORD g_worker_tid;
static jmp_buf g_jmp;           /* the worker's idle loop: a failed session lands here */
static bool g_jmp_ready;
static volatile LONG g_quit;    /* the window is closing: sessions end, the worker stops */

static void post_text(UINT msg, const char *text)
{
    if (g_wnd) PostMessageA(g_wnd, msg, 0, (LPARAM)_strdup(text));
}

/* A line in the window's log. */
static void say(const char *fmt, ...)
{
    char buf[1024];
    va_list a;
    va_start(a, fmt);
    vsnprintf(buf, sizeof(buf), fmt, a);
    va_end(a);
    post_text(WM_APP_LOG, buf);
}

static void status(const char *fmt, ...)
{
    char buf[512];
    va_list a;
    va_start(a, fmt);
    vsnprintf(buf, sizeof(buf), fmt, a);
    va_end(a);
    post_text(WM_APP_STATUS, buf);
}

/* In a session: the window shows the message and the worker goes back to waiting.
   Anywhere else (start-up): a message box, then the end. */
static void fail(const char *msg)
{
    if (g_jmp_ready && GetCurrentThreadId() == g_worker_tid) {
        post_text(WM_APP_ERROR, msg);
        longjmp(g_jmp, 1);
    }
    if (g_wnd && GetCurrentThreadId() == g_worker_tid) { post_text(WM_APP_FATAL, msg); ExitThread(1); }
    MessageBoxA(g_wnd, msg, "Revision Co-op", MB_ICONERROR);
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

static SOCKET udp_socket(int port);

#ifndef REVCOOP_FAKE_STEAM
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

    /* Steam not running yet: wait for it (the player starts it after seeing the window);
       running but refusing for 10 s: give up with its reason. */
    char err[1024] = "";
    int r = -1, refused = 0;
    status("Connecting to Steam...");
    while (!g_quit) {
        if (S.IsSteamRunning()) {
            if ((r = S.InitFlat(err)) == 0) break;
            if (++refused >= 10) {
                char buf[1200];
                snprintf(buf, sizeof(buf), "Could not connect to Steam (code %d): %s", r, err);
                fail(buf);
            }
        } else
            status("Steam is not running: start Steam and log in. This window connects by itself.");
        Sleep(1000);
    }
    if (g_quit) ExitThread(0);
    S.DispatchInit();
    g_pipe = S.GetHSteamPipe();
    g_user = S.User(); g_mm = S.Matchmaking(); g_friends = S.Friends();
    g_msgs = S.Messages(); g_utils = S.Utils();
    g_me = S.GetSteamID(g_user);
    if (S.InitRelay) S.InitRelay(g_utils);
}
#else
/* A test build (build.bat fake -> RevCoopFake.exe, never shipped): Steam played by two relays
   on one PC, so host and join run end to end with one Steam account (tools/run_relay_test.ps1).
   REVCOOP_FAKE_ME=1001 is the host, 1002 the joiner; a message to a user is a UDP datagram to
   127.0.0.1:(46100 + its id % 1000), the lobby (id 5001, owner 1001) and its data a file in
   %TEMP%. Everything above S (lobby checks, mode follow, the relay itself) is the real code. */
static SOCKET f_sock;
static u64 f_me;
static struct { CallbackMsg m; unsigned char param[512]; } f_cbs[16];
static int f_ncb;
static unsigned char *f_queue[2][256];
static int f_nq[2];

static void f_callback(int id, const void *param, int size)
{
    if (f_ncb == 16) return;
    memset(&f_cbs[f_ncb], 0, sizeof(f_cbs[0]));
    f_cbs[f_ncb].m.callback = id; f_cbs[f_ncb].m.param_size = size;
    memcpy(f_cbs[f_ncb].param, param, size);
    f_ncb++;
}
static void f_lobby_file(char *out) { char t[MAX_PATH]; GetTempPathA(MAX_PATH, t); snprintf(out, MAX_PATH, "%srevcoop_fake_lobby.txt", t); }
static bool __cdecl f_true0(void) { return true; }
static int __cdecl f_init(char *err) { (void)err; return 0; }
static void __cdecl f_void0(void) {}
static int32_t __cdecl f_pipe(void) { return 1; }
static void __cdecl f_run(int32_t p) { (void)p; }
static bool __cdecl f_next(int32_t p, CallbackMsg *m) { (void)p; if (!f_ncb) return false; *m = f_cbs[0].m; m->param = f_cbs[0].param; return true; }
static void __cdecl f_free(int32_t p) { (void)p; if (f_ncb) { memmove(f_cbs, f_cbs + 1, sizeof(f_cbs[0]) * (f_ncb - 1)); f_ncb--; } }
static bool __cdecl f_result(int32_t p, u64 c, void *b, int s, int cb, bool *failed) { (void)p; (void)c; (void)b; (void)s; (void)cb; *failed = true; return false; }
static void *__cdecl f_iface(void) { return (void *)1; }
static u64 __cdecl f_steamid(void *u) { (void)u; return f_me; }
static u64 __cdecl f_create_lobby(void *mm, int type, int max)
{
    char p[MAX_PATH]; FILE *f; LobbyCreated c = { 1, 5001 };
    (void)mm; (void)type; (void)max;
    f_lobby_file(p); if ((f = fopen(p, "w"))) fclose(f);
    f_callback(CB_LOBBY_CREATED, &c, sizeof(c));
    return 1;
}
static u64 __cdecl f_join_lobby(void *mm, u64 lobby) { LobbyEnter e; (void)mm; memset(&e, 0, sizeof(e)); e.lobby = lobby; e.response = 1; f_callback(CB_LOBBY_ENTER, &e, sizeof(e)); return 1; }
static void __cdecl f_leave_lobby(void *mm, u64 lobby) { (void)mm; (void)lobby; }
static bool __cdecl f_set_data(void *mm, u64 lobby, const char *k, const char *v)
{
    char p[MAX_PATH]; FILE *f; (void)mm; (void)lobby;
    f_lobby_file(p); if ((f = fopen(p, "a"))) { fprintf(f, "%s=%s\n", k, v); fclose(f); }
    return true;
}
static const char *__cdecl f_get_data(void *mm, u64 lobby, const char *k)
{
    static char v[256]; char p[MAX_PATH], line[512]; FILE *f; size_t n = strlen(k); (void)mm; (void)lobby;
    v[0] = 0; f_lobby_file(p);
    if ((f = fopen(p, "r"))) {
        while (fgets(line, sizeof(line), f))
            if (!strncmp(line, k, n) && line[n] == '=') { snprintf(v, sizeof(v), "%s", line + n + 1); v[strcspn(v, "\r\n")] = 0; }
        fclose(f);
    }
    return v;
}
static u64 __cdecl f_owner(void *mm, u64 lobby) { (void)mm; (void)lobby; return 1001; }
static int __cdecl f_members(void *mm, u64 lobby) { (void)mm; (void)lobby; return 2; }
static u64 __cdecl f_member(void *mm, u64 lobby, int i) { (void)mm; (void)lobby; return 1001 + i; }
static bool __cdecl f_presence(void *fr, const char *k, const char *v) { (void)fr; (void)k; (void)v; return true; }
static void __cdecl f_invite(void *fr, u64 l) { (void)fr; (void)l; }
static int __cdecl f_friend_count(void *fr, int flags) { (void)fr; (void)flags; return 0; }
static u64 __cdecl f_friend(void *fr, int i, int flags) { (void)fr; (void)i; (void)flags; return 0; }
static bool __cdecl f_played(void *fr, u64 f, FriendGameInfo *gi) { (void)fr; (void)f; (void)gi; return false; }
static const char *__cdecl f_name_of(void *fr, u64 sid) { (void)fr; return sid == 1001 ? "FakeHost" : "FakeJoiner"; }
static const char *__cdecl f_my_name(void *fr) { return f_name_of(fr, f_me); }
static void __cdecl f_ident_set(void *buf, u64 sid) { memcpy(buf, &sid, sizeof(sid)); }
static u64 __cdecl f_ident_get(const void *buf) { u64 sid; memcpy(&sid, buf, sizeof(sid)); return sid; }
static int __cdecl f_send(void *m, const void *id, const void *data, uint32_t size, int flags, int channel)
{
    static unsigned char pkt[65536 + 16];
    struct sockaddr_in a; u64 to = f_ident_get(id); (void)m; (void)flags;
    if (size > 65536) return 0;
    pkt[0] = (unsigned char)channel; memcpy(pkt + 1, &f_me, 8); memcpy(pkt + 9, data, size);
    memset(&a, 0, sizeof(a)); a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    a.sin_port = htons((u_short)(46100 + to % 1000));
    sendto(f_sock, (char *)pkt, (int)size + 9, 0, (struct sockaddr *)&a, sizeof(a));
    return 1;
}
/* A received message as the relay reads one: data pointer at 0, size at 4, sender at 16. */
static int __cdecl f_receive(void *m, int channel, void **out, int max)
{
    static unsigned char pkt[65536 + 16];
    int got, n = 0; (void)m;
    while ((got = recv(f_sock, (char *)pkt, sizeof(pkt), 0)) >= 9) {
        int ch = pkt[0] & 1, size = got - 9;
        unsigned char *msg;
        if (f_nq[ch] == 256) continue;
        msg = calloc(1, 32 + size);
        *(unsigned char **)msg = msg + 32; *(int *)(msg + 4) = size;
        memcpy(msg + 16, pkt + 1, 8); memcpy(msg + 32, pkt + 9, size);
        f_queue[ch][f_nq[ch]++] = msg;
    }
    while (n < max && n < f_nq[channel]) { out[n] = f_queue[channel][n]; n++; }
    memmove(f_queue[channel], f_queue[channel] + n, sizeof(f_queue[0][0]) * (f_nq[channel] - n));
    f_nq[channel] -= n;
    return n;
}
static bool __cdecl f_session(void *m, const void *id) { (void)m; (void)id; return true; }
static void __cdecl f_release(void *msg) { free(msg); }
static bool __cdecl f_config(void *u, int k, int32_t v) { (void)u; (void)k; (void)v; return true; }

static void steam_start(void)
{
    const char *me = getenv("REVCOOP_FAKE_ME");
    f_me = me ? strtoull(me, NULL, 10) : 1001;
    f_sock = udp_socket((int)(46100 + f_me % 1000));
    if (f_sock == INVALID_SOCKET) fail("Fake Steam: could not open its UDP port.");
    *(void **)&S.IsSteamRunning = f_true0; *(void **)&S.InitFlat = f_init; *(void **)&S.Shutdown = f_void0;
    *(void **)&S.GetHSteamPipe = f_pipe; *(void **)&S.DispatchInit = f_void0; *(void **)&S.RunFrame = f_run;
    *(void **)&S.GetNextCallback = f_next; *(void **)&S.FreeLastCallback = f_free; *(void **)&S.GetAPICallResult = f_result;
    *(void **)&S.User = f_iface; *(void **)&S.Matchmaking = f_iface; *(void **)&S.Friends = f_iface;
    *(void **)&S.Messages = f_iface; *(void **)&S.Utils = f_iface; *(void **)&S.GetSteamID = f_steamid;
    *(void **)&S.CreateLobby = f_create_lobby; *(void **)&S.JoinLobby = f_join_lobby; *(void **)&S.LeaveLobby = f_leave_lobby;
    *(void **)&S.SetLobbyData = f_set_data; *(void **)&S.GetLobbyData = f_get_data; *(void **)&S.GetLobbyOwner = f_owner;
    *(void **)&S.GetNumLobbyMembers = f_members; *(void **)&S.GetLobbyMemberByIndex = f_member;
    *(void **)&S.SetRichPresence = f_presence; *(void **)&S.InviteDialog = f_invite;
    *(void **)&S.GetFriendCount = f_friend_count; *(void **)&S.GetFriendByIndex = f_friend; *(void **)&S.GetFriendGamePlayed = f_played;
    *(void **)&S.GetFriendPersonaName = f_name_of; *(void **)&S.GetPersonaName = f_my_name;
    *(void **)&S.IdentSet = f_ident_set; *(void **)&S.IdentGet = f_ident_get;
    *(void **)&S.SendMessageToUser = f_send; *(void **)&S.ReceiveMessages = f_receive;
    *(void **)&S.AcceptSession = f_session; *(void **)&S.CloseSession = f_session;
    *(void **)&S.MessageRelease = f_release; *(void **)&S.SetConfigInt = f_config;
    g_pipe = 1; g_user = g_mm = g_friends = g_msgs = g_utils = (void *)1;
    g_me = f_me;
}
#endif

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

/* The installed modes (names and titles) for the window's list; the current mode stays. */
static char g_mode_names[16][64], g_mode_titles[16][128];
static int g_modes;

static void list_modes(void)
{
    char p[MAX_PATH], was[64];
    WIN32_FIND_DATAA fd;
    snprintf(was, sizeof(was), "%s", g_mode);
    g_modes = 0;
    mode_path(p, sizeof(p), "*", ".mode");
    HANDLE h = FindFirstFileA(p, &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        char *dot = strrchr(fd.cFileName, '.');
        if (dot) *dot = 0;
        if (g_modes < 16 && load_mode(fd.cFileName)) {
            snprintf(g_mode_names[g_modes], 64, "%s", g_mode);
            snprintf(g_mode_titles[g_modes], 128, "%s", g_mode_title);
            g_modes++;
        }
    } while (FindNextFileA(h, &fd));
    FindClose(h);
    load_mode(was);
}

/* ---------------------------------------------------------------- host settings */

/* The host's game settings; the server decides, so they apply to everyone.
   Kept in Modes\settings.txt. Difficulty goes in the host URL, friendly fire in RevNet.ini. */
static int g_difficulty = 1;   /* 0 Easy, 1 Medium, 2 Hard, 3 Deus Ex, 4 Custom: Revision's custom difficulty
                                  screens on the host's game before it starts (RevNet.CoopCustomDifficulty) */
static int g_friendly_fire = 0; /* index into ff_values */
static const char *difficulty_names[] = { "Easy", "Medium", "Hard", "Deus Ex", "Custom (set in game)" };
static const char *ff_values[] = { "0.000000", "0.500000", "1.000000" };
static const char *ff_names[] = { "Off", "Half damage", "Full damage" };
/* CoopGameInfo.DeathRule and SaveRule. */
static int g_death = 0, g_saves = 0;
static int g_agent = 0;  /* the player's own class: 0 JC's kind (nano), 1 the Mech (docs/MECH_CLASS.md), 2 the Light Mech (docs/LIGHT_MECH_CLASS.md) */
static const char *agent_names[] = { "Nano-augmented agent (JC's kind)", "Mech: mechanical augmentation (heavy)", "Light Mech: Adam Jensen's augmentations (light)" };
static const char *agent_keys[] = { "", "Mech", "LightMech" };  /* RevNet.CoopLaunch Agent */
static const char *death_names[] = { "Downed: a teammate revives you with a medkit", "The team reloads the last save at once" };
static const char *save_names[] = { "Quick saves and autosaves", "Autosaves only (harder)" };
/* CoopGameInfo.RifleRework: 0 here = on (the rifle as a 7.62 battle rifle with select fire, for everyone). */
static int g_rifle = 0;
static const char *rifle_names[] = { "7.62 battle rifle, select fire", "The mode's own" };
/* The modes' own switches (Revision.RevGameInfo: what Revision's options set; the host's game reads
   them, for everyone): Biomod has them all, Shifter and HR the skill system. Bit i: switch_keys[i] on. */
static const char *switch_keys[] = { "bNewSkillSystem", "bBioModAugTracking", "bBioModNoReticleForScopedWeapons",
    "bShifterEnableRandomInventory", "bShifterEnableOverpoweredUniqueWeapons", "bShifterEnableMiniRocketLauncher",
    "bShifterEnabledShotgunAmmoPacking", "bShifterEnableWeaponModRateOfFire" };
static const char *switch_names[] = { "Skill points for subduing enemies (skill system)", "Aug tracking instead of aug targeting",
    "No reticle on scoped weapons", "Random inventory on enemies", "Unique weapons (Jackhammer, Precision Rifle, Railgun)",
    "Mini rocket launcher on MJ12 commandos", "Shotgun ammo packing", "Rate-of-fire weapon mod" };
static int g_switches = 0xFF;  /* Revision's defaults: all on */

static int mode_switches(const char *mode)
{
    if (!_stricmp(mode, "Biomod")) return 0xFF;
    if (!_stricmp(mode, "Shifter") || !_stricmp(mode, "HR")) return 1;
    return 0;
}

static void load_settings(void)
{
    char p[MAX_PATH], line[128];
    snprintf(p, sizeof(p), "%s\\Modes\\settings.txt", g_game_dir);
    FILE *f = fopen(p, "r");
    if (!f) return;
    while (fgets(line, sizeof(line), f)) {
        if (!strncmp(line, "Difficulty=", 11)) { g_difficulty = atoi(line + 11); if (g_difficulty < 0 || g_difficulty > 4) g_difficulty = 1; }
        else if (!strncmp(line, "Switches=", 9)) g_switches = atoi(line + 9) & 0xFF;
        else if (!strncmp(line, "FriendlyFire=", 13)) { g_friendly_fire = atoi(line + 13); if (g_friendly_fire < 0 || g_friendly_fire > 2) g_friendly_fire = 0; }
        else if (!strncmp(line, "Death=", 6)) g_death = atoi(line + 6) & 1;
        else if (!strncmp(line, "Saves=", 6)) g_saves = atoi(line + 6) & 1;
        else if (!strncmp(line, "Agent=", 6)) { g_agent = atoi(line + 6); if (g_agent < 0 || g_agent > 2) g_agent = 0; }
        else if (!strncmp(line, "Rifle=", 6)) g_rifle = atoi(line + 6) & 1;
    }
    fclose(f);
}

static void save_settings(void)
{
    char p[MAX_PATH];
    snprintf(p, sizeof(p), "%s\\Modes\\settings.txt", g_game_dir);
    FILE *f = fopen(p, "w");
    if (f) { fprintf(f, "Difficulty=%d\nFriendlyFire=%d\nDeath=%d\nSaves=%d\nAgent=%d\nRifle=%d\nSwitches=%d\n", g_difficulty, g_friendly_fire, g_death, g_saves, g_agent, g_rifle, g_switches); fclose(f); }
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
    set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", "RifleRework", g_rifle ? "0" : "1");
    /* Both sections: Revision's own, and the co-op game's (a subclass reads inherited settings there). */
    for (int i = 0; i < 8; i++) {
        set_ini_key("RevNet.ini", "Revision.RevGameInfo", switch_keys[i], (g_switches >> i) & 1 ? "True" : "False");
        set_ini_key("RevNet.ini", "RevNet.CoopGameInfo", switch_keys[i], (g_switches >> i) & 1 ? "True" : "False");
    }
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
    /* A name of letters this leaves out (Cyrillic, CJK...): one of our own, so two such friends
       aren't both "Player" (the game keys a player's saved things by name). */
    if (k) snprintf(out, size, "?Name=%s", clean);
    else snprintf(out, size, "?Name=Player%04u", (unsigned)(g_me % 10000));
}

/* The host's game password for this session (the security sweep of 2026-10-31): the game's port
   is open on the LAN, so it lets in only who has it; it is in the friends-only lobby's data, which
   only members can read. Mixed from the CPU's counter, the time, a stack address and the ids
   (no new imports: Smart App Control re-judges the exe on one). */
static char g_token[17];
static void make_token(unsigned long long lobby)
{
    volatile int here;
    unsigned long long x = __rdtsc() ^ ((unsigned long long)GetTickCount() << 32) ^ (unsigned long long)(size_t)&here
        ^ g_me ^ (lobby << 7);
    for (int i = 0; i < 2; i++) {      /* splitmix64 */
        x += 0x9E3779B97F4A7C15ULL;
        x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
        x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
        x ^= x >> 31;
    }
    snprintf(g_token, sizeof(g_token), "%016llx", x);
}

/* The game opens AutoOpen once from its menu map (RevNet.CoopLaunch), as the player's class
   (Agent: every URL it opens gets ?RevClass=, rejoins too). */
static void set_auto_open(const char *url)
{
    set_ini_key("RevNetUser.ini", "RevNet.CoopLaunch", "AutoOpen", url);
    set_ini_key("RevNetUser.ini", "RevNet.CoopLaunch", "Agent", agent_keys[g_agent]);
}

/* The game's environment: ours without SteamAppId/SteamGameId. Steam's API set them to this
   relay's AppID (480), and the game, inheriting them, stopped at "Steam Error: Application load
   error" (measured); it takes its own (397550) from its folder's steam_appid.txt. */
static wchar_t *game_environment(void)
{
    wchar_t *env = GetEnvironmentStringsW(), *out, *o, *e;
    size_t n = 2;
    for (e = env; *e; e += wcslen(e) + 1) n += wcslen(e) + 1;
    o = out = malloc(n * sizeof(wchar_t));
    for (e = env; *e; e += wcslen(e) + 1)
        if (_wcsnicmp(e, L"SteamAppId=", 11) && _wcsnicmp(e, L"SteamGameId=", 12)) { wcscpy(o, e); o += wcslen(e) + 1; }
    *o = 0;
    if (o == out) o[1] = 0;  /* an empty block still ends in two zeros */
    FreeEnvironmentStringsW(env);
    return out;
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
    wchar_t *env = game_environment();
    STARTUPINFOA si; PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si)); si.cb = sizeof(si);
    BOOL ok = CreateProcessA(exe, cmd, NULL, NULL, FALSE, CREATE_UNICODE_ENVIRONMENT, env, g_game_dir, &si, &pi);
    free(env);
    if (!ok) {
        char buf[MAX_PATH + 100];
        snprintf(buf, sizeof(buf), "Could not start %s (error %lu).", exe, GetLastError());
        fail(buf);
    }
    CloseHandle(pi.hThread);
    g_game = pi.hProcess;
    say("Started the game: %s", url);
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
    say("%s left (%s).", friend_name(p->sid), why);
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
        say("%s connected through Steam.", friend_name(sid));
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
        make_token(g_lobby);
        S.SetLobbyData(g_mm, g_lobby, "pw", g_token);
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
        else say("Ignored a connection from %s (not in your lobby).", friend_name(sid));
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

/* load: continue the mode's co-op save (?CoopLoad=1). */
static int run_host(const char *map, bool load)
{
    S.CreateLobby(g_mm, 1 /* friends only */, MAX_PEERS + 1);
    status("Creating a friends-only Steam lobby...");
    DWORD t0 = GetTickCount();
    while (!g_lobby && !g_lobby_failed && GetTickCount() - t0 < 15000) { pump(host_cb); Sleep(20); }
    if (!g_lobby) fail("Steam did not create a lobby. Check that you are online in Steam.");

    char url[1024], name[32];
    apply_mode();
    apply_settings();
    name_option(name, sizeof(name));
    snprintf(url, sizeof(url), "%s?Listen?Port=%d?Game=%s?Difficulty=%d%s?GamePassword=%s%s%s%s", map, g_port, g_game_class,
             g_difficulty == 4 ? 1 : g_difficulty, g_difficulty == 4 ? "?CustomDifficulty=True" : "", g_token, name, load ? "?CoopLoad=1" : "", g_url_extra);
    launch_game(url);

    status("Hosting %s. Friends join from their Revision Co-op window, or in Steam: right-click you, Join Game. Close the game to stop.",
           g_mode_title);
    say("Lobby id %llu (a friend can type it under Join).", (unsigned long long)g_lobby);

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
        if (game_exited() || g_quit) break;
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

static int run_join(u64 lobby)
{
    g_join_lobby = lobby;
    status("Joining...");
    for (int attempt = 0; attempt < 3 && !g_host; attempt++) {
        g_join_failed = false;
        say("Joining lobby %llu...", (unsigned long long)g_join_lobby);
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
    say("Host: %s, mode: %s", friend_name(g_host), g_mode_title);
    accept_session(g_host);

    SOCKET s = udp_socket(0);
    if (s == INVALID_SOCKET) fail("Could not open a local UDP port.");
    int port = local_port(s);
    char url[256], name[32], pw[17] = "";
    name_option(name, sizeof(name));
    /* The host's game password (make_token): hex digits only, else none. */
    const char *lp = S.GetLobbyData(g_mm, g_join_lobby, "pw");
    if (lp && strlen(lp) == 16 && strspn(lp, "0123456789abcdef") == 16) snprintf(pw, sizeof(pw), "%s", lp);
    snprintf(url, sizeof(url), "127.0.0.1:%d%s%s%s", port, name, pw[0] ? "?Password=" : "", pw);
    launch_game(url);
    status("Playing in %s's game (%s). Keep this window open; close the game to stop.", friend_name(g_host), g_mode_title);
    say("Relaying 127.0.0.1:%d <-> %s over Steam.", port, friend_name(g_host));

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
                    if (*(int *)((char *)msgs[i] + 4) >= 1 && (*(char **)msgs[i])[0] == 'B') say("The host closed the game.");
                }
                S.MessageRelease(msgs[i]);
            }
        }
        DWORD now = GetTickCount();
        if (now - last_ping > 1000) { last_ping = now; send_to(g_host, "K", 1, SEND_RELIABLE, 1); }
        if (now - last_heard > 20000 && now - warned > 20000) { warned = now; say("No answer from the host for 20 s..."); }
        if (game_exited() || g_quit) break;
        Sleep(1);
    }
    send_to(g_host, "B", 1, SEND_RELIABLE, 1);
    S.LeaveLobby(g_mm, g_join_lobby);
    for (int i = 0; i < 20; i++) { pump(join_cb); Sleep(10); }
    close_session(g_host);
    closesocket(s);
    return 0;
}

/* ---------------------------------------------------------------- worker */

/* What the window asks for; the worker takes it when it isn't in a session. */
enum { CMD_NONE, CMD_HOST, CMD_CONTINUE, CMD_JOIN };
static volatile LONG g_cmd;
static u64 g_cmd_lobby;                          /* CMD_JOIN */
static char g_own_mode[64];                      /* the player's chosen mode (a join uses the host's) */
static char g_host_map[64] = "01_NYC_UNATCOIsland";

typedef struct { int n; u64 lobby[32]; char name[32][64]; } FriendList;

/* After a session, ended or failed: out of the lobby, no peers, and the player's own mode
   again (joining switches to the host's). */
static void end_session(void)
{
    for (int i = 0; i < MAX_PEERS; i++) if (g_peers[i].sid) drop_peer(&g_peers[i], "session ended");
    if (g_lobby) {
        S.LeaveLobby(g_mm, g_lobby);
        S.SetRichPresence(g_friends, "connect", "");
        S.SetRichPresence(g_friends, "status", "");
        g_lobby = 0;
    }
    if (g_join_lobby) { S.LeaveLobby(g_mm, g_join_lobby); g_join_lobby = 0; }
    if (g_host) { close_session(g_host); g_host = 0; }
    g_lobby_failed = g_join_failed = false;
    if (g_game) { CloseHandle(g_game); g_game = NULL; }
    load_mode(g_own_mode);  /* (not pick_default_mode: its fail() would land back here) */
    status("Ready.");
    PostMessageA(g_wnd, WM_APP_SESSION, 0, 0);
}

/* The friends who host, sent to the window when the list changes. */
static void update_friends(bool force)
{
    static FriendList last;
    FriendList now;
    u64 owners[32];
    memset(&now, 0, sizeof(now));
    now.n = list_hosting_friends(now.lobby, owners, 32);
    for (int i = 0; i < now.n; i++) snprintf(now.name[i], 64, "%s", friend_name(owners[i]));
    if (!force && !memcmp(&now, &last, sizeof(now))) return;
    last = now;
    FriendList *f = malloc(sizeof(*f));
    *f = now;
    PostMessageA(g_wnd, WM_APP_FRIENDS, 0, (LPARAM)f);
}

static DWORD WINAPI worker(void *unused)
{
    static DWORD listed;
    WSADATA w;
    (void)unused;
    WSAStartup(MAKEWORD(2, 2), &w);
    steam_start();
    relay_config();
    post_text(WM_APP_READY, S.GetPersonaName(g_friends));
    status("Ready.");
    say("To host: choose the mode and settings, then Host a new game. To join: choose a friend who is hosting, then Join.");
    update_friends(true);

    if (setjmp(g_jmp)) { end_session(); update_friends(true); }  /* a failed session lands here */
    g_jmp_ready = true;
    while (!g_quit) {
        LONG cmd = InterlockedExchange(&g_cmd, CMD_NONE);
        if (cmd == CMD_NONE && g_join_lobby) { cmd = CMD_JOIN; g_cmd_lobby = g_join_lobby; }  /* a Steam invite or "Join Game" */
        if (cmd != CMD_NONE) {
            PostMessageA(g_wnd, WM_APP_SESSION, 1, 0);
            if (cmd == CMD_JOIN) run_join(g_cmd_lobby);
            else if (cmd == CMD_CONTINUE) {
                char saved[128];
                if (!read_saved_map(saved, sizeof(saved)))
                    fail("No saved game in this mode yet. Host a game first: it saves a few seconds into every map, and when the host quick-saves.");
                say("Continuing the saved game on %s.", saved);
                run_host(saved, true);
            } else
                run_host(g_host_map, false);
            say("The game closed.");
            end_session();
            update_friends(true);
            continue;
        }
        pump(join_cb);
        if (GetTickCount() - listed > 1500) { listed = GetTickCount(); update_friends(false); }
        Sleep(50);
    }
    S.Shutdown();
    return 0;
}

/* ---------------------------------------------------------------- window */

enum { ID_ICON = 100, ID_TITLE, ID_WHO, ID_MODE, ID_DIFF, ID_FF, ID_DEATH, ID_SAVES, ID_HOST, ID_CONTINUE,
       ID_SAVED, ID_FRIENDS, ID_LOBBY, ID_JOIN, ID_STATUS, ID_LOG, ID_AGENT, ID_RIFLE, ID_MODEOPTS };
static HFONT g_font, g_bold, g_big;
static HICON g_icon, g_icon_small;
static double g_scale = 1;
static bool g_steam_ready, g_in_session;
static u64 g_list_lobby[32];
static int g_list_n;
static HANDLE g_worker;

static wchar_t *wide(const char *s)  /* UTF-8 (Steam names) to a malloc'd UTF-16 string */
{
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    wchar_t *w = malloc((n > 0 ? n : 1) * sizeof(wchar_t));
    if (n <= 0 || !MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n)) w[0] = 0;
    return w;
}

static void set_text(int id, const char *utf8)
{
    wchar_t *w = wide(utf8);
    SetDlgItemTextW(g_wnd, id, w);
    free(w);
}

static void message(const char *utf8, UINT icon)
{
    wchar_t *w = wide(utf8);
    MessageBoxW(g_wnd, w, L"Revision Co-op", icon);
    free(w);
}

/* A child control at 96-dpi coordinates. */
static HWND ctl(DWORD ex, const wchar_t *cls, const char *text, DWORD style, int x, int y, int w, int h, int id, HFONT font)
{
    wchar_t *t = wide(text);
    HWND c = CreateWindowExW(ex, cls, t, WS_CHILD | WS_VISIBLE | style, (int)(x * g_scale), (int)(y * g_scale),
                             (int)(w * g_scale), (int)(h * g_scale), g_wnd, (HMENU)(INT_PTR)id, GetModuleHandleW(NULL), NULL);
    free(t);
    SendMessageW(c, WM_SETFONT, (WPARAM)font, TRUE);
    return c;
}

static HWND combo(int y, const char *label, int id, const char **items, int n, int cur)
{
    ctl(0, WC_STATICW, label, 0, 26, y + 4, 104, 18, 0, g_font);
    HWND c = ctl(0, WC_COMBOBOXW, "", CBS_DROPDOWNLIST | WS_TABSTOP | WS_VSCROLL, 134, y, 300, 200, id, g_font);
    for (int i = 0; i < n; i++) { wchar_t *w = wide(items[i]); SendMessageW(c, CB_ADDSTRING, 0, (LPARAM)w); free(w); }
    SendMessageW(c, CB_SETCURSEL, cur, 0);
    return c;
}

static int cursel(int id) { return (int)SendDlgItemMessageW(g_wnd, id, CB_GETCURSEL, 0, 0); }

/* Buttons and lists follow the state: settings only between sessions, Steam actions only
   once Steam is up, Continue only with a save of the chosen mode. */
static void update_enabled(void)
{
    char saved[128], line[200];
    bool idle = !g_in_session, has = read_saved_map(saved, sizeof(saved));
    const int settings[] = { ID_MODE, ID_DIFF, ID_FF, ID_DEATH, ID_SAVES, ID_AGENT, ID_RIFLE, ID_MODEOPTS };
    for (int i = 0; i < (int)(sizeof(settings) / sizeof(settings[0])); i++) EnableWindow(GetDlgItem(g_wnd, settings[i]), idle);
    EnableWindow(GetDlgItem(g_wnd, ID_HOST), idle && g_steam_ready);
    EnableWindow(GetDlgItem(g_wnd, ID_CONTINUE), idle && g_steam_ready && has);
    EnableWindow(GetDlgItem(g_wnd, ID_FRIENDS), idle && g_steam_ready);
    EnableWindow(GetDlgItem(g_wnd, ID_LOBBY), idle && g_steam_ready);
    EnableWindow(GetDlgItem(g_wnd, ID_JOIN), idle && g_steam_ready);
    if (has) snprintf(line, sizeof(line), "Saved game in this mode: %s", saved);
    else snprintf(line, sizeof(line), "No saved game in this mode yet.");
    set_text(ID_SAVED, line);
}

static void start(LONG cmd)
{
    if (!g_steam_ready || g_in_session) return;
    g_in_session = true;  /* at once: a second click must not start a second session */
    update_enabled();
    InterlockedExchange(&g_cmd, cmd);
}

/* The typed lobby id, else the chosen friend. */
static void join_chosen(void)
{
    wchar_t typed[32];
    GetDlgItemTextW(g_wnd, ID_LOBBY, typed, 32);
    u64 lobby = _wcstoui64(typed, NULL, 10);
    int i = (int)SendDlgItemMessageW(g_wnd, ID_FRIENDS, LB_GETCURSEL, 0, 0);
    if (!lobby && i >= 0 && i < g_list_n) lobby = g_list_lobby[i];
    if (!lobby) { message("Choose a friend who is hosting, or type the lobby id they see.", MB_ICONINFORMATION); return; }
    g_cmd_lobby = lobby;
    start(CMD_JOIN);
}

static void show_friends(FriendList *f)
{
    HWND lb = GetDlgItem(g_wnd, ID_FRIENDS);
    int i = (int)SendMessageW(lb, LB_GETCURSEL, 0, 0);
    u64 was = i >= 0 && i < g_list_n ? g_list_lobby[i] : 0;
    SendMessageW(lb, LB_RESETCONTENT, 0, 0);
    g_list_n = f->n;
    for (i = 0; i < f->n; i++) {
        wchar_t *w = wide(f->name[i]);
        g_list_lobby[i] = f->lobby[i];
        SendMessageW(lb, LB_ADDSTRING, 0, (LPARAM)w);
        free(w);
        if (f->lobby[i] == was) SendMessageW(lb, LB_SETCURSEL, i, 0);
    }
    if (!f->n) SendMessageW(lb, LB_ADDSTRING, 0, (LPARAM)L"No Steam friend is hosting right now.");
    else if (f->n == 1) SendMessageW(lb, LB_SETCURSEL, 0, 0);
}

static void append_log(const char *utf8)
{
    HWND log = GetDlgItem(g_wnd, ID_LOG);
    int len = GetWindowTextLengthW(log);
    wchar_t *w = wide(utf8);
    SendMessageW(log, EM_SETSEL, len, len);
    if (len) SendMessageW(log, EM_REPLACESEL, FALSE, (LPARAM)L"\r\n");
    SendMessageW(log, EM_REPLACESEL, FALSE, (LPARAM)w);
    free(w);
}

/* The mode's own switches: a menu of them, ticked when on (one switched a click); the ones the
   chosen mode hasn't are greyed. */
static void mode_options_menu(HWND h)
{
    int have = mode_switches(g_mode);
    HMENU m = CreatePopupMenu();
    for (int i = 0; i < 8; i++) {
        wchar_t *w = wide(switch_names[i]);
        AppendMenuW(m, MF_STRING | (((g_switches >> i) & 1) ? MF_CHECKED : 0) | (((have >> i) & 1) ? 0 : MF_GRAYED), 1 + i, w);
        free(w);
    }
    if (!have) {
        AppendMenuW(m, MF_SEPARATOR, 0, NULL);
        AppendMenuW(m, MF_STRING | MF_GRAYED, 99, L"This mode has no options of its own");
    }
    RECT r;
    GetWindowRect(GetDlgItem(h, ID_MODEOPTS), &r);
    int cmd = TrackPopupMenu(m, TPM_RETURNCMD | TPM_LEFTALIGN | TPM_TOPALIGN, r.left, r.bottom, 0, h, NULL);
    DestroyMenu(m);
    if (cmd >= 1 && cmd <= 8) {
        g_switches ^= 1 << (cmd - 1);
        save_settings();
    }
}

static void create_controls(void)
{
    int cur = 0;
    const char *titles[16];
    for (int i = 0; i < g_modes; i++) { titles[i] = g_mode_titles[i]; if (!_stricmp(g_mode_names[i], g_mode)) cur = i; }

    HWND icon = ctl(0, WC_STATICW, "", SS_ICON, 16, 14, 32, 32, ID_ICON, g_font);
    if (g_icon) SendMessageW(icon, STM_SETICON, (WPARAM)g_icon, 0);
    ctl(0, WC_STATICW, "Deus Ex: Revision Co-op", 0, 58, 10, 380, 28, ID_TITLE, g_big);
    ctl(0, WC_STATICW, "Not signed in to Steam yet.", 0, 58, 40, 380, 18, ID_WHO, g_font);

    combo(68, "You play as", ID_AGENT, agent_names, 3, g_agent);

    ctl(0, WC_BUTTONW, "Your game: everyone who joins plays with these", BS_GROUPBOX, 12, 102, 436, 266, 0, g_font);
    HWND mode = combo(128, "Mode", ID_MODE, titles, g_modes, cur);
    SetWindowPos(mode, NULL, 0, 0, (int)(198 * g_scale), (int)(200 * g_scale), SWP_NOMOVE | SWP_NOZORDER);
    ctl(0, WC_BUTTONW, "Options...", BS_PUSHBUTTON | WS_TABSTOP, 338, 127, 96, 25, ID_MODEOPTS, g_font);
    combo(158, "Difficulty", ID_DIFF, difficulty_names, 5, g_difficulty);
    combo(188, "Friendly fire", ID_FF, ff_names, 3, g_friendly_fire);
    combo(218, "If a player dies", ID_DEATH, death_names, 2, g_death);
    combo(248, "Saves", ID_SAVES, save_names, 2, g_saves);
    combo(278, "Assault rifle", ID_RIFLE, rifle_names, 2, g_rifle);
    ctl(0, WC_BUTTONW, "Host a new game", BS_PUSHBUTTON | WS_TABSTOP, 26, 314, 200, 30, ID_HOST, g_font);
    ctl(0, WC_BUTTONW, "Continue saved game", BS_PUSHBUTTON | WS_TABSTOP, 234, 314, 200, 30, ID_CONTINUE, g_font);
    ctl(0, WC_STATICW, "", 0, 26, 348, 408, 16, ID_SAVED, g_font);

    ctl(0, WC_BUTTONW, "Join a friend", BS_GROUPBOX, 12, 378, 436, 150, 0, g_font);
    ctl(WS_EX_CLIENTEDGE, WC_LISTBOXW, "", LBS_NOTIFY | LBS_NOINTEGRALHEIGHT | WS_VSCROLL | WS_TABSTOP, 26, 402, 408, 72, ID_FRIENDS, g_font);
    ctl(0, WC_STATICW, "Lobby id", 0, 26, 487, 60, 18, 0, g_font);
    ctl(WS_EX_CLIENTEDGE, WC_EDITW, "", ES_AUTOHSCROLL | ES_NUMBER | WS_TABSTOP, 90, 484, 170, 24, ID_LOBBY, g_font);
    ctl(0, WC_BUTTONW, "Join", BS_PUSHBUTTON | WS_TABSTOP, 334, 482, 100, 30, ID_JOIN, g_font);

    ctl(0, WC_STATICW, "Starting...", 0, 14, 538, 432, 34, ID_STATUS, g_bold);
    ctl(WS_EX_CLIENTEDGE, WC_EDITW, "", ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | WS_VSCROLL, 12, 576, 436, 96, ID_LOG, g_font);
    SendDlgItemMessageW(g_wnd, ID_LOG, EM_SETLIMITTEXT, 0, 0);
    update_enabled();
}

static LRESULT CALLBACK wnd_proc(HWND h, UINT msg, WPARAM wp, LPARAM lp)
{
    switch (msg) {
    case WM_CREATE:
        g_wnd = h;
        create_controls();
        return 0;
    case WM_CTLCOLORSTATIC:  /* the read-only log on a white background, like a normal text box */
        if ((HWND)lp == GetDlgItem(h, ID_LOG)) {
            SetBkColor((HDC)wp, GetSysColor(COLOR_WINDOW));
            return (LRESULT)GetSysColorBrush(COLOR_WINDOW);
        }
        break;
    case WM_COMMAND: {
        int id = LOWORD(wp), code = HIWORD(wp);
        if (id == ID_MODE && code == CBN_SELCHANGE) {
            int i = cursel(ID_MODE);
            if (i >= 0 && i < g_modes && load_mode(g_mode_names[i])) {
                save_current_mode();
                snprintf(g_own_mode, sizeof(g_own_mode), "%s", g_mode);
            }
            update_enabled();
        } else if (id == ID_AGENT && code == CBN_SELCHANGE) {
            g_agent = cursel(ID_AGENT);
            if (g_agent < 0 || g_agent > 2) g_agent = 0;
            save_settings();
        } else if ((id == ID_DIFF || id == ID_FF || id == ID_DEATH || id == ID_SAVES || id == ID_RIFLE) && code == CBN_SELCHANGE) {
            g_difficulty = cursel(ID_DIFF);
            if (g_difficulty < 0 || g_difficulty > 4) g_difficulty = 1;
            g_friendly_fire = cursel(ID_FF) % 3;
            g_death = cursel(ID_DEATH) & 1;
            g_saves = cursel(ID_SAVES) & 1;
            g_rifle = cursel(ID_RIFLE) & 1;
            save_settings();
        } else if (id == ID_MODEOPTS && code == BN_CLICKED) mode_options_menu(h);
        else if (id == ID_HOST && code == BN_CLICKED) start(CMD_HOST);
        else if (id == ID_CONTINUE && code == BN_CLICKED) start(CMD_CONTINUE);
        else if (id == ID_JOIN && code == BN_CLICKED) join_chosen();
        else if (id == ID_FRIENDS && code == LBN_DBLCLK) join_chosen();
        else if (id == ID_FRIENDS && code == LBN_SELCHANGE) SetDlgItemTextW(h, ID_LOBBY, L"");  /* a friend, not a typed id */
        else if (id == ID_LOBBY && code == EN_CHANGE && GetWindowTextLengthW(GetDlgItem(h, ID_LOBBY)))
            SendDlgItemMessageW(h, ID_FRIENDS, LB_SETCURSEL, (WPARAM)-1, 0);
        else if (id == IDOK) {  /* Enter (IsDialogMessage) in the friends list or the lobby id: join */
            HWND f = GetFocus();
            if (f == GetDlgItem(h, ID_LOBBY) || f == GetDlgItem(h, ID_FRIENDS)) join_chosen();
        }
        return 0;
    }
    case WM_APP_LOG: append_log((char *)lp); free((void *)lp); return 0;
    case WM_APP_STATUS: set_text(ID_STATUS, (char *)lp); free((void *)lp); return 0;
    case WM_APP_ERROR:
        append_log((char *)lp);
        message((char *)lp, MB_ICONWARNING);
        free((void *)lp);
        return 0;
    case WM_APP_FATAL:
        message((char *)lp, MB_ICONERROR);
        free((void *)lp);
        DestroyWindow(h);
        return 0;
    case WM_APP_READY: {
        char line[200];
        snprintf(line, sizeof(line), "Signed in to Steam as %s", (char *)lp);
        set_text(ID_WHO, line);
        free((void *)lp);
        g_steam_ready = true;
        update_enabled();
        return 0;
    }
    case WM_APP_SESSION:
        g_in_session = wp != 0;
        update_enabled();
        if (g_in_session) SendDlgItemMessageW(h, ID_FRIENDS, LB_SETCURSEL, (WPARAM)-1, 0);
        return 0;
    case WM_APP_FRIENDS: show_friends((FriendList *)lp); free((void *)lp); return 0;
    case WM_CLOSE:
        if (g_in_session && MessageBoxW(h, L"The game is still running. Closing this window disconnects it from your friends.\n\nClose anyway?",
                                        L"Revision Co-op", MB_YESNO | MB_ICONWARNING) != IDYES)
            return 0;
        InterlockedExchange(&g_quit, 1);
        if (g_worker) WaitForSingleObject(g_worker, 3000);  /* lets a session say goodbye and leave its lobby */
        DestroyWindow(h);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(h, msg, wp, lp);
}

static int run_window(void)
{
    SetProcessDPIAware();
    INITCOMMONCONTROLSEX icc = { sizeof(icc), ICC_STANDARD_CLASSES };
    InitCommonControlsEx(&icc);
    HDC dc = GetDC(NULL);
    g_scale = GetDeviceCaps(dc, LOGPIXELSY) / 96.0;
    ReleaseDC(NULL, dc);

    NONCLIENTMETRICSW ncm = { sizeof(ncm) };
    SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(ncm), &ncm, 0);
    LOGFONTW lf = ncm.lfMessageFont;
    g_font = CreateFontIndirectW(&lf);
    lf.lfWeight = FW_BOLD;
    g_bold = CreateFontIndirectW(&lf);
    lf.lfHeight = lf.lfHeight * 16 / 10;
    g_big = CreateFontIndirectW(&lf);

    char exe[MAX_PATH];  /* Revision's own icon, as on the desktop shortcut */
    snprintf(exe, sizeof(exe), "%s\\Revision.exe", g_game_dir);
    ExtractIconExA(exe, 0, &g_icon, &g_icon_small, 1);

    WNDCLASSEXW wc = { sizeof(wc) };
    wc.lpfnWndProc = wnd_proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.lpszClassName = L"RevCoopWindow";
    wc.hIcon = g_icon;
    wc.hIconSm = g_icon_small;
    RegisterClassExW(&wc);

    DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
    RECT r = { 0, 0, (LONG)(460 * g_scale), (LONG)(684 * g_scale) };
    AdjustWindowRect(&r, style, FALSE);
    int w = r.right - r.left, h = r.bottom - r.top;
    CreateWindowExW(0, L"RevCoopWindow", L"Deus Ex: Revision Co-op", style,
                    (GetSystemMetrics(SM_CXSCREEN) - w) / 2, (GetSystemMetrics(SM_CYSCREEN) - h) / 2, w, h,
                    NULL, NULL, wc.hInstance, NULL);
    if (!g_wnd) return 1;
    ShowWindow(g_wnd, SW_SHOW);

    /* Suspended until its id is known: fail() tells the worker from the window by it. */
    g_worker = CreateThread(NULL, 0, worker, NULL, CREATE_SUSPENDED, &g_worker_tid);
    ResumeThread(g_worker);

    MSG m;
    while (GetMessageW(&m, NULL, 0, 0) > 0)
        if (!IsDialogMessageW(g_wnd, &m)) { TranslateMessage(&m); DispatchMessageW(&m); }
    return 0;
}

/* ---------------------------------------------------------------- main */

int main(int argc, char **argv)
{
    const char *mode = NULL, *arg = NULL, *want_mode = NULL, *apply_only = NULL, *open_url = NULL;
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
    list_modes();
    snprintf(g_own_mode, sizeof(g_own_mode), "%s", g_mode);

    /* A start from the command line (or Steam's +connect_lobby) runs once Steam is up. */
    if (mode && !_stricmp(mode, "host")) {
        if (arg) snprintf(g_host_map, sizeof(g_host_map), "%s", arg);
        g_cmd = CMD_HOST;
    } else if (mode && !_stricmp(mode, "continue"))
        g_cmd = CMD_CONTINUE;
    else if (mode && !_stricmp(mode, "join") && arg && (g_cmd_lobby = strtoull(arg, NULL, 10)))
        g_cmd = CMD_JOIN;
    if (g_cmd) g_in_session = true;
    return run_window();
}
