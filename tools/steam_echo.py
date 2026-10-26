"""Real Steam delivery between two Steam identities on this PC, through the calls the relay uses
(ISteamNetworkingMessages: SendMessageToUser, ReceiveMessagesOnChannel, sessions; the sender read
as the relay reads it). One Steam account can't message itself, so the other end is an anonymous
AppID 480 game server (its own Steam id, no account). Python + ctypes with Valve's signed
steam_api64.dll (from any installed Steam game), so no unsigned test program has to run.
Steam must be running and signed in.

  python -I tools/steam_echo.py [count] [steam_api64.dll]      PASS when every ping comes back
"""
import ctypes as C, glob, os, shutil, subprocess, sys, tempfile, time

u64, i32 = C.c_uint64, C.c_int
IDENT = 160                          # SteamNetworkingIdentity is 136 bytes; kept opaque
SESSION_REQUEST = 1251


class CallbackMsg(C.Structure):
    _fields_ = [("user", C.c_int32), ("callback", C.c_int32), ("param", C.c_void_p), ("size", C.c_int32)]


def steam(dll):
    s = C.CDLL(dll)
    sig = {
        "SteamAPI_InitFlat": (i32, [C.c_char_p]),
        "SteamInternal_GameServer_Init_V2": (i32, [C.c_uint32, C.c_uint16, C.c_uint16, i32, C.c_char_p, C.c_char_p, C.c_char_p]),
        "SteamAPI_ManualDispatch_Init": (None, []),
        "SteamAPI_ManualDispatch_RunFrame": (None, [i32]),
        "SteamAPI_ManualDispatch_GetNextCallback": (C.c_bool, [i32, C.POINTER(CallbackMsg)]),
        "SteamAPI_ManualDispatch_FreeLastCallback": (None, [i32]),
        "SteamAPI_GetHSteamPipe": (i32, []),
        "SteamGameServer_GetHSteamPipe": (i32, []),
        "SteamAPI_SteamUser_v023": (C.c_void_p, []),
        "SteamAPI_ISteamUser_GetSteamID": (u64, [C.c_void_p]),
        "SteamAPI_SteamGameServer_v015": (C.c_void_p, []),
        "SteamAPI_ISteamGameServer_LogOnAnonymous": (None, [C.c_void_p]),
        "SteamAPI_ISteamGameServer_BLoggedOn": (C.c_bool, [C.c_void_p]),
        "SteamAPI_ISteamGameServer_GetSteamID": (u64, [C.c_void_p]),
        "SteamAPI_SteamNetworkingMessages_SteamAPI_v002": (C.c_void_p, []),
        "SteamAPI_SteamGameServerNetworkingMessages_SteamAPI_v002": (C.c_void_p, []),
        "SteamAPI_SteamNetworkingUtils_SteamAPI_v004": (C.c_void_p, []),
        "SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess": (None, [C.c_void_p]),
        "SteamAPI_SteamNetworkingIdentity_SetSteamID64": (None, [C.c_void_p, u64]),
        "SteamAPI_SteamNetworkingIdentity_GetSteamID64": (u64, [C.c_void_p]),
        "SteamAPI_ISteamNetworkingMessages_SendMessageToUser": (i32, [C.c_void_p, C.c_void_p, C.c_void_p, C.c_uint32, i32, i32]),
        "SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel": (i32, [C.c_void_p, i32, C.POINTER(C.c_void_p), i32]),
        "SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser": (C.c_bool, [C.c_void_p, C.c_void_p]),
        "SteamAPI_SteamNetworkingMessage_t_Release": (None, [C.c_void_p]),
    }
    for name, (res, args) in sig.items():
        f = getattr(s, name)
        f.restype, f.argtypes = res, args
    return s


def ident(s, sid):
    buf = C.create_string_buffer(IDENT)
    s.SteamAPI_SteamNetworkingIdentity_SetSteamID64(buf, sid)
    return buf


def sender(s, msg):
    """The relay's msg_sender: identity at 16, else 12 (SteamNetworkingMessage_t)."""
    sid = s.SteamAPI_SteamNetworkingIdentity_GetSteamID64(C.c_void_p(msg + 16))
    return sid or s.SteamAPI_SteamNetworkingIdentity_GetSteamID64(C.c_void_p(msg + 12))


def payload(msg):
    data = C.c_void_p.from_address(msg).value
    size = C.c_int.from_address(msg + C.sizeof(C.c_void_p)).value
    return C.string_at(data, size)


def pump(s, pipe, msgs):
    cb = CallbackMsg()
    s.SteamAPI_ManualDispatch_RunFrame(pipe)
    while s.SteamAPI_ManualDispatch_GetNextCallback(pipe, C.byref(cb)):
        if cb.callback == SESSION_REQUEST:
            print("server: session request from", s.SteamAPI_SteamNetworkingIdentity_GetSteamID64(C.c_void_p(cb.param)), flush=True)
            s.SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser(msgs, C.c_void_p(cb.param))
        s.SteamAPI_ManualDispatch_FreeLastCallback(pipe)


def receive(s, msgs):
    out = (C.c_void_p * 32)()
    n = s.SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel(msgs, 0, out, 32)
    return [out[i] for i in range(max(n, 0))]


def server(dll, id_file):
    s = steam(dll)
    err = C.create_string_buffer(1024)
    versions = b"SteamUtils010\0SteamNetworkingUtils004\0SteamGameServer015\0SteamNetworkingMessages002\0"
    r = s.SteamInternal_GameServer_Init_V2(0x7F000001, 27115, 27116, 1, b"1.0.0.0", versions, err)   # loopback: no firewall prompt
    if r:
        print("server: game server init failed", r, err.value, flush=True)
        return 1
    s.SteamAPI_ManualDispatch_Init()
    pipe = s.SteamGameServer_GetHSteamPipe()
    gs = s.SteamAPI_SteamGameServer_v015()
    msgs = s.SteamAPI_SteamGameServerNetworkingMessages_SteamAPI_v002()
    s.SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess(s.SteamAPI_SteamNetworkingUtils_SteamAPI_v004())
    s.SteamAPI_ISteamGameServer_LogOnAnonymous(gs)
    t0 = time.time()
    while not s.SteamAPI_ISteamGameServer_BLoggedOn(gs) and time.time() - t0 < 30:
        pump(s, pipe, msgs)
        time.sleep(0.05)
    if not s.SteamAPI_ISteamGameServer_BLoggedOn(gs):
        print("server: anonymous logon timed out", flush=True)
        return 1
    me = s.SteamAPI_ISteamGameServer_GetSteamID(gs)
    open(id_file, "w").write(str(me))
    print("server: logged on as", me, flush=True)
    t0 = time.time()
    while time.time() - t0 < 120:
        pump(s, pipe, msgs)
        for m in receive(s, msgs):
            data, frm = payload(m), sender(s, m)
            s.SteamAPI_ISteamNetworkingMessages_SendMessageToUser(msgs, ident(s, frm), data, len(data), 8, 0)
            s.SteamAPI_SteamNetworkingMessage_t_Release(m)
        time.sleep(0.002)
    return 0


def client(dll, id_file, count):
    s = steam(dll)
    srv = int(open(id_file).read())
    err = C.create_string_buffer(1024)
    r = s.SteamAPI_InitFlat(err)
    if r:
        print("client: Steam init failed", r, err.value)
        return 1
    s.SteamAPI_ManualDispatch_Init()
    pipe = s.SteamAPI_GetHSteamPipe()
    msgs = s.SteamAPI_SteamNetworkingMessages_SteamAPI_v002()
    s.SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess(s.SteamAPI_SteamNetworkingUtils_SteamAPI_v004())
    me = s.SteamAPI_ISteamUser_GetSteamID(s.SteamAPI_SteamUser_v023())
    print("client: %d (the signed-in user) -> %d (anonymous game server)" % (me, srv))
    peer, sent, rtts, starts = ident(s, srv), 0, [], {}
    t0 = time.time()
    while time.time() - t0 < 60 and len(rtts) < count:
        pump(s, pipe, msgs)
        if sent < count and time.time() - t0 >= sent * 0.25:
            ping = b"ping %d" % sent
            starts[sent] = time.perf_counter()
            s.SteamAPI_ISteamNetworkingMessages_SendMessageToUser(msgs, peer, ping, len(ping), 8, 0)
            sent += 1
        for m in receive(s, msgs):
            data = payload(m)
            if sender(s, m) == srv and data.startswith(b"ping "):
                rtts.append((time.perf_counter() - starts[int(data[5:])]) * 1000)
            s.SteamAPI_SteamNetworkingMessage_t_Release(m)
        time.sleep(0.002)
    print("client: sent %d, echoed back %d%s" % (sent, len(rtts), ", round trip %.0f ms on average, %.0f at most" % (sum(rtts) / len(rtts), max(rtts)) if rtts else ""))
    return 0 if len(rtts) == count else 1


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("server", "client"):
        role, dll, id_file = sys.argv[1:4]
        sys.exit(server(dll, id_file) if role == "server" else client(dll, id_file, int(sys.argv[4])))
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    found = sys.argv[2] if len(sys.argv) > 2 else max(
        glob.glob(r"C:\Program Files (x86)\Steam\steamapps\common\*\**\steam_api64.dll", recursive=True), key=os.path.getmtime)
    work = tempfile.mkdtemp(prefix="steam_echo_")
    dll = shutil.copy(found, work)
    open(os.path.join(work, "steam_appid.txt"), "w").write("480")
    id_file = os.path.join(work, "server_id.txt")
    srv = subprocess.Popen([sys.executable, "-I", os.path.abspath(__file__), "server", dll, id_file], cwd=work)
    try:
        t0 = time.time()
        while not os.path.exists(id_file) and srv.poll() is None and time.time() - t0 < 40:
            time.sleep(0.5)
        if not os.path.exists(id_file):
            print("FAIL steam echo: the game server did not log on")
            return 1
        r = subprocess.run([sys.executable, "-I", os.path.abspath(__file__), "client", dll, id_file, str(count)], cwd=work).returncode
        print("PASS steam echo" if r == 0 else "FAIL steam echo")
        return r
    finally:
        srv.kill()
        srv.wait()
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main() or 0)
