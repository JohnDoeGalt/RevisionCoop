"""The arm blades as their owner sees them (CoopMechBlade), for each class: its blade arms (tools/blade_arms.py: ours,
built to be seen up close, painted for the class), posed in the view. The right arm leads from the lower right, its
blade toward the middle; the left waits lower in its corner. Drawn (0.7 s), both come up with their housings
hidden in the forearms; each rises onto its line, runs out of its port near the wrist over the hand, and the
blade slides out past the fist (the user's design, 2026-10-29: housing_move, blade_in); three punches, the blade leading
(the user: "punching animations instead of the swipes": Attack: a straight right; Attack2: a straight left; Attack3:
a cross, the rear hand with the body's whole turn, never both at once; "more realistic and more aggressive... real punches... extension or
rotation": punch, from a low guard),  each lasting as the combat knife's does, its HandToHandAttack
notify at the impact (IMPACT); put away,
the blades slide back in and the arms drop. The same blades others see on it slide out in steps (STAGES, staged).

Frames: the arm's (blade_arms: x from the elbow, y to its left, z up); the eye's (x ahead, y left, z up, the eye at the
origin); the view's (as mech_storm: X ahead, Y right, Z up, K view units to a game unit, 256 raw units to one).
"""
import math, os

import numpy as np

from mech_art import norm
import blade_arms
import mech_storm

K = mech_storm.K

# An arm, up to the shoulder (the user, 2026-10-30: "add elbows and the arm below the shoulder to properly model the
# animation"): its shoulder's joint fixed by the eye (SHOULDER; moved a little as the body drives a punch), its upper
# arm and forearm of fixed lengths (blade_arms.UPPER, blade_arms.WRIST), its elbow where the wrist's place puts it
# (solve: two bones, the elbow down and out, swung by swivel). A pose, as seen from its own side (lateral: out to its
# side), in the eye's frame (x ahead, z up): the wrist ahead, out, up; swivel (degrees: the elbow swung about the line
# from the shoulder to the wrist); roll (the forearm's top, the blade's side, turned from up in towards the middle);
# the shoulder moved (ahead, out, up); ext (how far the blade is out: 0 in its housing, 1 out); out (how far the
# housing is run out of its port); lift (the housing risen from where it lies sunk at rest onto its line).
NAMES = "wx wlat wz swivel roll sx slat sz ext out lift g0 g1 g2 g3 gt tw et eh".split()   # g: the fingers' and the thumb's grip
                                                # (degrees curled tighter than the fist as built; less: the hand opening);
                                                # tw: how much the blade goes by the arm's reach (tendon: 1, out all the
                                                # way: 0; below 0, the view's own: the runs between the modes set it);
                                                # et, eh: the tendon's blade and housing set outright (below 0: the
                                                # blade by the arm's reach, the housing out: the idles hold the guard's,
                                                # a punch cocks and fires them)
SHOULDER = np.array([-3.0, 9.0, -9.0])         # the right shoulder's joint: a little behind the eye, out, down
POLE = np.array([0.0, 0.55, -1.0])             # the elbow's way off the line from the shoulder to the wrist: out, down


def tp(*v):
    a = np.zeros(len(NAMES))
    a[NAMES.index("tw")] = a[NAMES.index("et")] = a[NAMES.index("eh")] = -1
    a[:len(v)] = v
    return a


# The guard, low (the user, 2026-10-30: "more reflective of a low guard... a 45 degree angle, facing towards the ground,
# like in a normal kind of punching stance"): the fists low in their corners, the elbows bent, each fist turned 45
# degrees (its palm in and down: roll -45), the blades in towards the middle but not on it; the left, the lead, a
# little further out than the right.
GUARD = tp(15.5, 10.0, -8.5, -20, -45, 0, 0, 0, 1, 1, 1)   # the right, the rear hand
REST_L = tp(17.0, 10.0, -8.5, -20, -45, 0, 0, 0, 1, 1, 1)  # the left, the lead
LOW = tp(6.0, 9.5, -20.0, 0, 0, 0, 0, 0, 0, 0, 0)          # down out of sight

# The housing (the user, 2026-10-29): at rest hidden in the forearm under a hatch in the armour that lies flush with
# the plates beside it (blade_arms.HATCH), the blade hidden in it; drawn, the hatch's front lifts on its hinge behind
# (the opening: the port, blade_arms.HOLE) as the housing rises onto its line, it runs out from under it over the wrist
# and the hand along that line, its back never leaving the port ("coming from the same like hole"), and the blade
# slides out of it. Run out its mouth is 3 units past where it used to be (the user: "about 25% more forward... the
# reach of the blade").
LINE = blade_arms.unit(np.array([1.0, 0.0, blade_arms.SLOPE]))
TRAVEL = blade_arms.MOUTH - (blade_arms.HOLE - 0.4)             # run in, its mouth just inside the port
SINK = 0.55                                                     # how far below its line it lies at rest
POP = 0.8                                                       # its front tipped up while it rises (degrees: more shows through)
HATCH_LIFT = 7.5                                                # the hatch open (degrees: its front up about 0.85, over the housing)
SLIDE = blade_arms.BLADE["x1"] - (blade_arms.MOUTH - 0.6)       # how far the blade runs back to hide in the housing


def hatch_move(P, lift):
    """The hatch's points (built shut, flush), its front lifted about its hinge behind as far as lift (0 shut, 1 open)."""
    h = blade_arms.hatch_hinge()
    a = math.radians(HATCH_LIFT * lift)
    Q = P.copy()
    dx, dz = Q[:, 0] - h[0], Q[:, 2] - h[2]
    Q[:, 0] = h[0] + dx * math.cos(a) - dz * math.sin(a)
    Q[:, 2] = h[2] + dx * math.sin(a) + dz * math.cos(a)
    return Q


def housing_move(P, out, lift):
    """Points of the housing (and the blade in it), as built (run out), moved to where it is: run in along its line by
    the rest of the way, lowered by what it has not yet risen, its front tipped up while it rises (about its hinge,
    its back end, which moves with it)."""
    off = -LINE * TRAVEL * (1 - out) + np.array([0.0, 0.0, -SINK * (1 - lift)])
    h = blade_arms.hinge() + off
    Q = P + off
    a = math.radians(POP * math.sin(math.pi * lift) * (1 - out))
    dx, dz = Q[:, 0] - h[0], Q[:, 2] - h[2]
    Q[:, 0] = h[0] + dx * math.cos(a) - dz * math.sin(a)
    Q[:, 2] = h[2] + dx * math.sin(a) + dz * math.cos(a)
    return Q


def blade_in(P, ext):
    """The blade's points slid back into the housing along its line (ext 1: out as built, 0: all of it inside); what
    would pass its mouth's inside stays there (folded into the housing, out of sight)."""
    mouth = np.array([blade_arms.MOUTH, 0.0, blade_arms.axis_z(blade_arms.MOUTH)])
    along = (P - mouth) @ LINE
    return P + np.outer(np.maximum(along - (1 - ext) * SLIDE, -0.3) - along, LINE)


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def span(t, a, b):
    return ease((t - a) / (b - a))


def keys(t, ks):
    """The pose at t between key poses [(t0, pose0), (t1, pose1), ...], eased in each step."""
    for (t0, p0), (t1, p1) in zip(ks, ks[1:]):
        if t <= t1:
            return p0 + (p1 - p0) * span(t, t0, t1)
    return ks[-1][1]


def pose(base=GUARD, **kw):
    """base with some of its values changed (NAMES)."""
    p = base.copy()
    for k, v in kw.items():
        p[NAMES.index(k)] = v
    return p


def solve(T, s):
    """Pose T's arm in the eye's frame (s: +1 the right arm, -1 the left): the forearm's place and turn as placed takes
    them (the elbow ahead, out, up, pitch, yaw, roll, ext, out, lift), the shoulder's joint, the elbow, the elbow's way
    off the line from the shoulder to the wrist. Out of reach, the arm goes straight at the wrist's place."""
    m = np.array([1.0, -s, 1.0])                 # (its own side's out: the eye's y)
    S = (SHOULDER + T[5:8]) * m
    W = T[0:3] * m
    L1, L2 = blade_arms.UPPER, blade_arms.WRIST
    D = W - S
    u = D / np.linalg.norm(D)
    d = min(max(np.linalg.norm(D), abs(L1 - L2) + 0.05), L1 + L2 - 0.05)
    a = math.radians(T[3]) * s
    pole = POLE * m
    pole = pole * math.cos(a) + np.cross(u, pole) * math.sin(a) + u * (u @ pole) * (1 - math.cos(a))
    perp = norm(pole - (pole @ u) * u)
    along = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
    E = S + u * along + perp * math.sqrt(max(0.0, L1 * L1 - along * along))
    f = norm(S + u * d - E)
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, f[2]))))
    yaw = math.degrees(math.atan2(f[1], f[0])) * s
    return np.array([E[0], -s * E[1], E[2], pitch, yaw, T[4], T[8], T[9], T[10]]), E, S, perp


def upper_axes(E, S, perp, s):
    """The upper arm's axes as columns (built straight back from the elbow, its biceps at +y): along it to the elbow;
    its biceps toward the bend (away from the elbow's point); the third."""
    ex = norm(E - S)
    ey = s * norm(-(perp - (perp @ ex) * ex))
    return np.stack([ex, ey, np.cross(ex, ey)], 1)


def drawn(t, base):
    """Up from below with the housing hidden; it rises onto its line (its front tipping up), runs out of the port over
    the wrist and the hand; the blade slides out (a little past, then home: a jolt as it locks)."""
    p = LOW + (base - LOW) * span(t, 0.0, 0.4)
    p[10] = span(t, 0.26, 0.42)
    p[9] = span(t, 0.42, 0.72)
    p[8] = 1.07 * span(t, 0.72, 0.88) - 0.07 * span(t, 0.88, 1.0)     # (the housing all the way out first: the user)
    p[0] -= 0.5 * math.sin(math.pi * span(t, 0.84, 0.97))
    return p


def put_away(t, base):
    """The blade slides in; the housing runs back into the port and sinks out of sight; the arm goes down."""
    p = base + (LOW - base) * span(t, 0.55, 1.0)
    p[8] = 1.0 - span(t, 0.0, 0.28)
    p[9] = 1.0 - span(t, 0.3, 0.56)
    p[10] = 1.0 - span(t, 0.56, 0.7)
    return p


def breathe(t, base, depth=1.0, phase=0.0):
    a = math.sin(2 * math.pi * t + phase)
    return pose(base, wz=base[2] + 0.3 * depth * a, wx=base[0] + 0.15 * depth * a)


# The idles (the user, 2026-10-30: "not 100% static... fingers flexing... if the arm kind of extends or pulls back a
# little bit, you see the effect on the blade"; then: the hands loosening "into... an open-ish hand", the blades going
# back in as they do, no thumbs popping out; "more like an opening and closing of the hands, slightly... rather than
# like individual fingers and thumbs moving independently... no one closes their fingers tighter into a fist and then
# loosens their thumb"): each 3 s, from the guard and back to it; the whole hand opening and closing as one.
def opened(g):
    """The whole hand opening by g degrees (less than 0) or clenching (more): the fingers together, the thumb with
    them (relaxing away from them as they open, tucking in as they clench)."""
    return dict(g0=g, g1=g, g2=g, g3=g, gt=0.6 * g)      # (slightly: the user; more, they read as one finger pointing)


def held(base):
    """The guard's blade (the tendon's, for the guard's reach: none, all in the housing): what the idles hold (the user:
    no sliding in and out in them; the blades "completely hidden" in the housing, out)."""
    return tendon(base, 1 if base is GUARD else -1)


def regrip(t, base, phase=0.0, depth=1.0):
    """Breathing: the arm drifts out and back, the hand loosening a little and closing again."""
    a = math.sin(2 * math.pi * (t + phase)) - math.sin(2 * math.pi * phase)
    return pose(base, wx=base[0] + 1.1 * depth * a, wz=base[2] + 0.45 * depth * a, et=held(base),
                **opened(-12 * depth * math.sin(math.pi * t) ** 2))


def flex(t, base):
    """The hand eased forward and turned, the fist clenched, then loosened, back."""
    k = math.sin(math.pi * t) ** 2
    g = 6 * math.sin(math.pi * span(t, 0.0, 0.45)) - 12 * math.sin(math.pi * span(t, 0.45, 1.0))
    return pose(base, wx=base[0] + 2.4 * k, wz=base[2] + 0.6 * k, roll=base[4] + 16 * k, et=held(base), **opened(g))


def switch(t, base, w0, w1):
    """The blades' mode switched (CoopMechBlade.CycleMode): they run out to full (w 1 to 0) or back to as far as the
    arm is (0 to 1), the fists clenching as they go."""
    g = 7 * math.sin(math.pi * t)
    return pose(base, tw=w0 + (w1 - w0) * ease(t), g0=g, g1=g, g2=g, g3=g, gt=0.5 * g)


def wave(t, base, phase=0.0):
    """Shaking out: the hand drifting from side to side, opening, the wrist given a few small shakes, closing again."""
    a = math.sin(2 * math.pi * (t + phase)) - math.sin(2 * math.pi * phase)
    o = math.sin(math.pi * span(t, 0.1, 0.9))
    shake = 7 * math.sin(2 * math.pi * 3 * t) * o
    return pose(base, wlat=base[1] + 0.7 * a, wx=base[0] + 0.5 * a, roll=base[4] + shake, et=held(base), **opened(-11 * o))


# A straight punch from the low guard, the whole arm: a dip (the fist down and back a little, turning further onto its
# side), then driven straight out at the crosshair, at the eye's height, the shoulder driving forward and in behind
# it (the body's turn), the elbow opening till the arm is nearly straight (it comes up into sight), the fist
# corkscrewing from its 45 degrees to palm down (and a little past at the impact), the blade past it going in point
# first; settled, held, back to the guard (punch). The other arm stays up in its guard, a little in and up to cover,
# its shoulder back (cover). Never both at once (the user, 2026-10-30). The last, Attack3, a cross (the user: "the final
# punch should be a cross punch... the one in boxing where it's a really long reach"): the rear hand thrown with the
# body's whole turn, the right shoulder driving far forward and in across the body, the arm going out straight at a
# point a little past the middle (CROSS: out of its reach, so straight), the lead hand drawn back and out of its way,
# its shoulder turned away (guarded).
PUNCH_R = pose(wx=25.0, wlat=2.5, wz=-1.0, roll=0, sx=2.0, slat=-1.2, sz=0.3)
PUNCH_L = pose(REST_L, wx=25.0, wlat=2.5, wz=-1.0, roll=0, sx=2.0, slat=-1.2, sz=0.3)
CROSS = pose(wx=28.5, wlat=0.5, wz=-1.5, roll=0, sx=4.5, slat=-3.0, sz=0.4)
IMPACT = 0.33           # when a punch lands (its notify), of its length
COCKED = 0.55           # the housing drawn back in the dip, of its way out
HOUSING_FIRST = 0.4     # the drive's share for the housing to run out, before the blade starts (the user: the housing
                        # "should extend 100% before the blade extends at all")


def punch(t, base, aim):
    """A dip (0-0.12: the tendon's blade snapped in, the housing drawn back: cocked), driven out accelerating all the
    way to a little past the target (IMPACT): the housing out first, then the blade, all the way at the impact (fired);
    settled onto it, held an instant, pulled back to the guard (the blade back to the guard's)."""
    B = pose(base, et=held(base), eh=1.0)
    dip = pose(base, wx=base[0] - 1.5, wz=base[2] - 0.8, roll=base[4] - 8, et=0.0, eh=COCKED)
    past = pose(aim, wx=aim[0] + 1.0, roll=aim[4] + 6, et=1.0, eh=1.0)
    hit = pose(aim, et=1.0, eh=1.0)
    if t < 0.12:
        return B + (dip - B) * ease(t / 0.12)
    if t < IMPACT:
        u = ((t - 0.12) / (IMPACT - 0.12)) ** 1.8
        p = dip + (past - dip) * u
        p[NAMES.index("eh")] = COCKED + (1 - COCKED) * min(1.0, u / HOUSING_FIRST)
        p[NAMES.index("et")] = max(0.0, (u - HOUSING_FIRST) / (1 - HOUSING_FIRST))
        return p
    if t < IMPACT + 0.09:
        return past + (hit - past) * ease((t - IMPACT) / 0.09)
    if t < 0.5:
        return hit
    v = (t - 0.5) / 0.5
    return hit + (B - hit) * (1 - (1 - v) ** 2)


def guarded(t, base):
    """The lead hand as the cross goes out: drawn back and out, its shoulder turned away (its blade clear of the
    cross's); back after."""
    B = pose(base, et=held(base))
    up = pose(B, wx=base[0] - 2.0, wlat=base[1] + 2.5, wz=base[2] + 1.2, sx=-2.0, slat=0.8)
    return keys(t, [(0.0, B), (0.2, up), (0.6, up), (1.0, B)])


def cover(t, base):
    """The other arm in its guard as the punch goes out, a little in and up to cover, its shoulder back with the
    body's turn (its blade out of the punch's way); back after."""
    B = pose(base, et=held(base))
    up = pose(B, wx=base[0] - 1.0, wlat=base[1] + 1.0, wz=base[2] + 0.6, sx=-1.2, slat=0.4)
    return keys(t, [(0.0, B), (0.2, up), (0.6, up), (1.0, B)])


# The sequences the knife's code plays (DeusExWeapon), lasting as the knife's do (its view model's: Select 0.43 s,
# Attack 0.36, Attack2 0.55, Attack3 0.4, Down 0.5; the cross a little longer, 0.5); the punches' notify where they land.
# (name, frames, rate, poses of t in 0-1, notify time)
SEQS = [("Still", 1, 1, lambda t: {"r": GUARD, "l": REST_L}, None),
        ("Select", 21, 30, lambda t: {"r": drawn(t, GUARD), "l": drawn(t, REST_L)}, None),
        ("Down", 18, 30, lambda t: {"r": put_away(t, GUARD), "l": put_away(t, REST_L)}, None),
        ("Idle1", 24, 8, lambda t: {"r": regrip(t, GUARD), "l": regrip(t, REST_L, 0.35)}, None),
        ("Idle2", 24, 8, lambda t: {"r": flex(t, GUARD), "l": regrip(t, REST_L, 0.5, 0.6)}, None),
        ("Idle3", 24, 8, lambda t: {"r": wave(t, GUARD), "l": wave(t, REST_L, 0.25)}, None),
        ("ToFull", 10, 30, lambda t: {"r": switch(t, GUARD, 1, 0), "l": switch(t, REST_L, 1, 0)}, None),
        ("ToTendon", 10, 30, lambda t: {"r": switch(t, GUARD, 0, 1), "l": switch(t, REST_L, 0, 1)}, None),
        ("Attack", 11, 30, lambda t: {"r": punch(t, GUARD, PUNCH_R), "l": cover(t, REST_L)}, IMPACT),
        ("Attack2", 16, 29, lambda t: {"r": cover(t, GUARD), "l": punch(t, REST_L, PUNCH_L)}, IMPACT),
        ("Attack3", 15, 30, lambda t: {"r": punch(t, GUARD, CROSS), "l": guarded(t, REST_L)}, IMPACT)]


def placed(p, s):
    """A pose's arm frame in the eye's: (its axes as columns, the elbow). s: +1 the right arm, -1 the left."""
    x, lat, z, pitch, yaw, roll = p[:6]
    a, b, r = math.radians(pitch), math.radians(yaw) * s, math.radians(roll)
    d = np.array([math.cos(a) * math.cos(b), math.cos(a) * math.sin(b), math.sin(a)])
    up = norm(np.array([0.0, 0, 1]) - d[2] * d)
    inward = s * norm(np.cross(up, d))
    zz = math.cos(r) * up + math.sin(r) * inward
    return np.stack([d, np.cross(zz, d), zz], 1), np.array([x, -s * lat, z])


# The B variant (the user, 2026-10-30, to A/B test: the blade "like a muscle that's attached to like a tendon"): the
# blade out only as far as the arm is: mostly in at the guard (TENDON floor), all the way only at full reach, between
# them as the arm is (the reach from the shoulder to the wrist, of the arm's whole length: r0 to r1).
TENDON = dict(floor=0.0, r0=0.74, r1=0.98)     # (none at the guard's reach, either hand's: at rest the blade is all
                                                # inside the housing, out over the hand: the user, 2026-10-30, "the blades
                                                # are completely hidden outside of the extended housing")


def tendon(T, s):
    """How far out the blade is for pose T's reach (B, the blade views' own: the user chose it, 2026-10-30)."""
    m = np.array([1.0, -s, 1.0])
    r = np.linalg.norm(T[0:3] * m - (SHOULDER + T[5:8]) * m) / (blade_arms.UPPER + blade_arms.WRIST)
    return TENDON["floor"] + (1 - TENDON["floor"]) * min(1.0, max(0.0, (r - TENDON["r0"]) / (TENDON["r1"] - TENDON["r0"])))


def turned(P, at, axis, deg):
    """Points turned deg about the line through at along axis (x, y or z: 0, 1, 2)."""
    a = math.radians(deg)
    i, j = [(1, 2), (2, 0), (0, 1)][axis]
    Q = P.copy()
    u, v = P[:, i] - at[i], P[:, j] - at[j]
    Q[:, i] = at[i] + u * math.cos(a) - v * math.sin(a)
    Q[:, j] = at[j] + u * math.sin(a) + v * math.cos(a)
    return Q


def gripped(Q, masks, fingers, thumb, g, s):
    """The hand's points with its fingers curled g[0..3] and its thumb g[4] degrees more than built (the arm's own
    frame, mirrored for the left: s): each finger at its three joints (less at each: 1, 0.85, 0.7), from the
    fingertip's joint back to the knuckle (each turn carries the segments after it); the thumb turned with them."""
    m = np.array([1.0, s, 1.0])
    for f in range(4):
        if not g[f]:
            continue
        J = [j * m for j in fingers[f]]
        c = (g[f], 0.85 * g[f], 0.7 * g[f])
        for seg in range(3):
            k = masks["f%d%s" % (f, "abc"[seg])]
            for joint in range(seg, -1, -1):
                Q[k] = turned(Q[k], J[joint], 1, -c[joint])
    if g[4]:
        # The thumb with the fingers, about the same line as their knuckles (not swung out sideways: it "popped out").
        T = [t * m for t in thumb]
        for seg in ("ta", "tb"):
            Q[masks[seg]] = turned(Q[masks[seg]], T[0], 1, -0.85 * g[4])
    return Q


def view_mesh(p, b=True):
    """A class's view of its blades: (frames (n, verts, 3) in the view's frame, triangles, skins, sequences). p: the
    finalized blade arm (blade_arms.made); the right arm as built, the left its mirror, each up to the shoulder (solve);
    the blade group slides (b: the B variant's, as far out as the arm is: tendon)."""
    V, G, tris, skins = shared(p)
    blade = np.array([g == "blade" for g in G])
    moving = np.array([g in ("blade", "housing") for g in G])
    hatch = np.array([g == "hatch" for g in G])
    upper = np.array([g == "upper" for g in G])
    hands = {g: np.array([x == g for x in G]) for g in set(G) if g[0] in "ft" and len(g) <= 3}
    sides = (("r", 1, V), ("l", -1, V * np.array([1.0, -1, 1])))
    frames = []
    for name, n, rate, f, _ in SEQS:
        for k in range(n):
            pp = f(k / max(1, n - 1))
            out = []
            for side, s, P in sides:
                P9, E, S, perp = solve(pp[side], s)
                w = pp[side][NAMES.index("tw")]
                if w < 0:
                    w = 1.0 if b else 0.0
                et, eh = pp[side][NAMES.index("et")], pp[side][NAMES.index("eh")]
                e = tendon(pp[side], s) if et < 0 else et       # (the blade by the arm's reach, or set outright:
                P9[6] *= (1 - w) + w * e                         # the idles' held, a punch's cocked and fired;
                P9[7] *= (1 - w) + w * (1.0 if eh < 0 else eh)   # out all the way, w 0, neither)
                Q = P.copy()
                Q = gripped(Q, hands, p.fingers, p.thumb, pp[side][11:16], s)
                Q[blade] = blade_in(Q[blade], P9[6])
                Q[moving] = housing_move(Q[moving], P9[7], P9[8])
                Q[hatch] = hatch_move(Q[hatch], P9[8])
                R, E9 = placed(P9, s)
                X = Q @ R.T + E9
                X[upper] = Q[upper] @ upper_axes(E, S, perp, s).T + E     # (from the shoulder to the elbow)
                out.append(X * np.array([K, -K, K]))
            frames.append(np.concatenate(out))
    # The right arm through one mirror (the view's), the left through two (its own and the view's).
    nv = len(V)
    vtris = [(a, c, b, ua, uc, ub) for a, b, c, ua, ub, uc in tris] + [(a + nv, b + nv, c + nv, ua, ub, uc) for a, b, c, ua, ub, uc in tris]
    return np.array(frames), vtris, skins + skins, seqs()


def shared(p, drop=()):
    """The finalized arm's vertices, each once where position, face and group agree (UVs are per triangle corner in
    a game mesh), their groups, its triangles and their skins; but not the faces of the regions in drop."""
    tr = [r for (pts, r) in p.faces for _ in range(len(pts) - 2)]
    ts = [s for (pts, _), s in zip(p.faces, p.sheets) for _ in range(len(pts) - 2)]
    vg = [g for (pts, _), g in zip(p.faces, p.groups) for _ in pts]
    smooth = getattr(p, "smooth", ())           # regions shaded round: their faces share vertices (blade_arms.SMOOTH)
    V, G, index, tris, skins = [], [], {}, [], []
    for t, r, s in zip(p.tris, tr, ts):
        if r in drop:
            continue
        skins.append(s)
        P = [np.asarray(p.verts[i]) for i in t[:3]]
        n = np.cross(P[1] - P[0], P[2] - P[0])
        n = ("round", r) if r in smooth else tuple(np.round(n / (np.linalg.norm(n) + 1e-12), 2))
        ids = []
        for i in t[:3]:
            key = (tuple(np.round(p.verts[i], 4)), n, vg[i])
            if key not in index:
                index[key] = len(V)
                V.append(np.asarray(p.verts[i], float))
                G.append(vg[i])
            ids.append(index[key])
        tris.append((ids[0], ids[1], ids[2], t[3], t[4], t[5]))
    return np.array(V), G, tris, skins


def seqs():
    out, start = [], 0
    for name, n, rate, _, notify in SEQS:
        out.append((name, start, n, rate, notify))
        start += n
    return out


def build(cls, art, b=True, suffix=""):
    """A class's view mesh (<cls>BladeView) and its skins (<cls>Arm1-3) into the art folder; their import lines
    (the textures', imported before any mesh uses them: the arm cannon's view wears the Mech's too; the mesh's). b:
    the blades out as far as the arm is (tendon: B, the user's choice; not: A, kept in reserve as MechBladeViewA,
    suffix "A"), its skins the same."""
    from mech_bake import save_pcx
    p = blade_arms.made()
    texs = []
    for s in (0, 1, 2):
        name = "%sArm%d" % (cls, s + 1)
        im = blade_arms.bake(p, cls, s, os.path.join(art, "Textures", name + ".png"))
        save_pcx(np.asarray(im, float), os.path.join(art, "Textures", name + ".pcx"))
        texs.append(name)
    frames, tris, skins, _ = view_mesh(p, b)
    from mech_parts import write_a3d, write_d3d
    name = cls + "BladeView" + suffix
    write_d3d(os.path.join(art, "Models", name + "_d.3d"), frames.shape[1], tris, skins)
    write_a3d(os.path.join(art, "Models", name + "_a.3d"), np.rint(frames * 256).astype(np.int16))
    print("%s: %d verts, %d tris, %d frames" % (name, frames.shape[1], len(tris), frames.shape[0]))
    return ["#exec TEXTURE IMPORT NAME=%s FILE=Textures\\%s.pcx GROUP=Skins" % (t, t) for t in texs], uc_lines(name, texs)


def uc_lines(name, texs):
    """The view mesh's import (in the view's frame, 256 raw units to one), the cuts' notifies."""
    total = sum(q[1] for q in SEQS)
    lines = ["#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (name, name, name),
             "#exec MESH ORIGIN MESH=%s X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0" % name,
             "#exec MESH SEQUENCE MESH=%s SEQ=All STARTFRAME=0 NUMFRAMES=%d RATE=30" % (name, total)]
    for seq, start, n, rate, notify in seqs():
        lines.append("#exec MESH SEQUENCE MESH=%s SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (name, seq, start, n, rate))
        if notify is not None:
            lines.append("#exec MESH NOTIFY MESH=%s SEQ=%s TIME=%g FUNCTION=HandToHandAttack" % (name, seq, notify))
    lines.append("#exec MESHMAP SCALE MESHMAP=%s X=0.00390625 Y=0.00390625 Z=0.00390625" % name)
    lines += ["#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=%d TEXTURE=%s" % (name, k, t) for k, t in enumerate(texs)]
    return lines + [""]


# On others' screens the blades slide out in steps (CoopMechParts.Stages): each step's mesh the parts with the blades
# this far out past the wrist.
STAGES = (0.35, 0.7)


def staged(P, e, w, ext):
    """A blade's points (the body's frame) with its part past the wrist ext of the way out, along the forearm."""
    ax = norm(w - e)
    wrist = float(np.linalg.norm(w - e))
    along = (np.asarray(P) - e) @ ax
    return np.asarray(P) + np.outer(np.where(along > wrist, (ext - 1) * (along - wrist), 0.0), ax)


def steel_texture(path, size=256):
    """Brushed steel, a bright edge along one side of each face (a blade's cell is the whole texture)."""
    from mech_bake import save_pcx
    v = np.arange(size)[:, None] / size
    rng = np.random.default_rng(7)
    streaks = rng.normal(0, 1, (1, size)).repeat(size, 0)
    base = 78 + 10 * streaks + 26 * (1 - v)
    edge = np.clip(1 - np.abs(v - 0.03) / 0.04, 0, 1)
    img = np.stack([base * 0.95, base, base * 1.06], -1) * (1 - edge[..., None]) + np.array([225.0, 230, 238]) * edge[..., None]
    save_pcx(np.clip(img, 0, 255), path)
