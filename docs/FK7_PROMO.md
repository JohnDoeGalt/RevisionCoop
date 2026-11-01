# FK-7 Fly Kit: the in-setting promo (script)

The user, 2026-10-30: "an in-setting defense promo video using a text generated woman's voice ... like one of those
defense contractors (think boeing) promo videos ... focused on affordability and have it mention UNATCO as a customer
reference ... it should talk about all the features again like it's an in setting promo video by the manufacturer";
then "filled with military industrial complex lingo, like modular, mission-based... Affordable precision", "organic
support", "the technologies involved... our patented blah blah blah system... the adhesive". Script by a Fable agent
from docs/FLY_KITS.md and the FPV Drones row of docs/MECH_CLASS.md. Voices: VoxCPM2, the user's picks: A
(warm American corporate) narrates, B (crisp British) is Maj. Halloran, each cloned from its approved take so every line
is the same voice. Footage: the fly-kit preview (`tools/flykit.py motion`) and the swarm on Liberty Island
(`tools/flykit_swarm.py`), NSF terrorists as the targets (UNATCO's open enemy in 2052; MJ12 is secret then).

## Manufacturer and its technologies

**Corvane Ordnance** (fictional mid-tier 2050s munitions house). Brand line: **Affordable precision.** Tagline:
**"Precision you already own."**

- **ThresholdBond(TM)** pads: voltage-switchable adhesion, the bond confined to the first molecular layers, the current
  never leaves the pad, no current or heat at the fuze, reversed to release; patented.
- **TwinVector(TM)** propulsion: two independently vectored ducted fans (hover, 1000 deg/s snap turns, the dash).
- **TriGear(TM)** flight profiles: 26 / 47 / 100 mph, selected in flight.
- **BareFrame(TM)** reconnaissance mode: an empty kit flies as a recon drone.
- **Shepherd(TM)** swarm control: a man-in-the-loop lead flown through its nose camera, up to four kits in formation,
  one press per kit per target, the lead goes in last.
- **TallySight(TM)** targeting overlay: boxes hostiles, locks the nearest (red, with range), marks each kit's target
  D1-D4 (amber).

## Voice-over

About 260 words, 10 sections, about 100 seconds. VO 1 = the narrator; VO 2 = Maj. Halloran (S8). For the voice:
numbers spelled as spoken; "F-K Seven", "G-E-P", "E-M-P"; UNATCO written "You-nat-co" (the screen keeps UNATCO); brand
names hyphenated (Span-Cradle, Threshold-Bond, Twin-Vector, Tri-Gear, Bare-Frame, Tally-Sight), CamelCase on screen;
no (TM) spoken; "attrit-able" if the engine stumbles.

**S1. Hook** (6 s). Wide opening hover, the kit alone; the title card on the last beat.
VO 1: "Your stockpile is full of precision weapons. They just can't fly yet."
Text: title card "FK-7 FLY KIT" / "CORVANE ORDNANCE · AFFORDABLE PRECISION".

**S2. What it is** (11 s). The kit clamped on a LAM, slow turntable.
VO 1: "Corvane Ordnance presents the F-K Seven Fly Kit. Hand-sized, modular, stockpile-agnostic: it mates to the munition
already in the pack, and flies it in. No new warhead. No new logistics tail."
Text: lower third "FK-7 FLY KIT · LOT 52-0318 · MFD 03/2052"; card "18 x 31 CM · MODULAR · STOCKPILE-AGNOSTIC".

**S3. Payloads** (10 s). The kit with each payload in turn, cut on each name.
VO 1: "Mission-configurable across seven certified payloads: lightweight attack munitions, G-E-P rockets, high explosive
or white phosphorus, twenty-millimeter grenades, gas, E-M-P, scramble. Every effect is the munition's own."
Text: card "PAYLOADS: 7 · MISSION-CONFIGURABLE" (LAM / GEP HE / GEP WP / 20 MM HE / GAS / EMP / SCRAMBLE); fine print
"Not rated for the LAW."

**S4. The bond** (10 s). The pads close up on a casing, the status light steady as the bond takes. (The clamp itself
is not talked about: the user, 2026-10-30, "we don't need to talk about the clamp"; its adhesive stays.)
VO 1: "Our patented Threshold-Bond interface holds by voltage-switchable adhesion: a current that never leaves the pad,
bonding only the first molecular layers. No current or heat at the fuze. Reversed, it releases."
Text: card "ThresholdBond(TM) VOLTAGE-SWITCHABLE ADHESION · PAT. 2049-77410 · NO CURRENT, NO HEAT AT THE FUZE".

**S5. Flight** (11 s). Hover, the snap turns, the forward dash, the 100 mph fly-past.
VO 1: "Twin-Vector propulsion: two independently vectored ducted fans. Stable hover. Snap turns at one thousand degrees
a second. Tri-Gear profiles, selected in flight: twenty-six, forty-seven, one hundred miles an hour."
Text: cards "TwinVector(TM) INDEPENDENT THRUST VECTORING · 1000 DEG/S" (on the turns), "TriGear(TM): 26 / 47 / 100
MPH" (on the fly-past).

**S6. Power and recon** (8 s). An empty kit hovering, then tilting off to scout.
VO 1: "Each kit draws seconds of the operator's bioelectric reserve. Unloaded, it flies Bare-Frame reconnaissance.
Attritable. Never dead weight."
Text: cards "BareFrame(TM) RECON MODE · ENDURANCE 25 S FLAT OUT / 60 S AS LEAD", "ATTRITABLE · SCALABLE · FORCE
MULTIPLIER".

**S7. Swarm and targeting** (17 s). The swarm in formation over Liberty Island, forward, turning, stopping; the lead's
gun-cam view: NSF terrorists boxed, the nearest locked in red with its range, D1 to D4 in amber as each kit is sent;
strikes; on "completes the mission itself" the feed cuts to static.
VO 1: "Shepherd swarm control: a man-in-the-loop lead flown through its nose camera, up to four kits in formation.
Tally-Sight boxes every hostile, locks the nearest, and marks each kit's target. Sensor to shooter: one press, one kit,
one target. Swarm spent, the lead completes the mission itself."
Text: cards "Shepherd(TM) SWARM CONTROL · LEAD + UP TO 4 · FLIES WITH WHAT YOU HAVE · ONE SWARM = THREE KITS' CHARGE",
"TallySight(TM): BOX · LOCK (RED, RANGE) · MARK D1-D4 (AMBER)".

**S8. Customer reference** (11 s). Test-range strikes, then the officer's lower third over a steady hover.
VO 1: "Fielded with You-nat-co since twenty fifty-one. Major Ingrid Halloran, You-nat-co Tactical Support."
VO 2 (Maj. Halloran): "The ordnance was already in our armory. Now precision support is organic to the team. No call up
the chain."
Text: lower third "MAJ. INGRID HALLORAN · UNATCO TACTICAL SUPPORT"; card "IN SERVICE WITH UNATCO SINCE 2051 · ORGANIC
PRECISION SUPPORT".

**S9. The bottom line** (7 s). Capability cards stacking over a slow turntable.
VO 1: "Lot pricing from three hundred ninety credits. One part number. One afternoon's training. Lower cost per effect.
Affordable precision."
Text: cards "UNIT COST: FROM 390 CR (LOT PRICING)", "ONE PART NUMBER · ONE AFTERNOON OF TRAINING", "LOWER COST PER
EFFECT · REDUCED LOGISTICS TAIL · OPEN ARCHITECTURE".

**S10. Close** (5 s). End card over the fly-past going away; fade to black.
VO 1: "The F-K Seven Fly Kit. Corvane Ordnance. Precision you already own."
Text: end card "CORVANE ORDNANCE · AFFORDABLE PRECISION" / "Precision you already own."; fine print "FK-7 Fly Kit.
Export subject to licence. Corvane Ordnance accepts no liability for payloads outside the certified list."
