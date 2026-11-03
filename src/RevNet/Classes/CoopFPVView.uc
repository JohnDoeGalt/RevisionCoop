//=============================================================================
// CoopFPVView.
//
// The FPV drone's gun-cam overlay (the user, 2026-10-30: "like gun cams from Apache gunships, or
// those drone cameras from drone strike videos", the picture in colour, "the little boxes that it
// puts around targets"): over the drone's own view (Revision's bAltSpyDroneView), on its pilot's
// machine (CoopFPV.OpenView). The screen's corners, a cross open in the middle with a gate round it,
// a heading tape; the hostiles in sight and range boxed, the one the fire button would send the
// swarm's next at locked (red), those the sent drones are after marked with their number (amber);
// the mode, the swarm left, a running clock, battery, height, speed, heading and range. What it
// knows of the targets the host tells it (CoopFPV.Look).
//=============================================================================
class CoopFPVView extends Window;

var CoopFPV Drone;
var float Born;
var Color Ink, Lock, Mark;
var string Gears[3];         // the drone's speeds, as the readout names them (CoopFPV.Gear)

// A bar with a shadow down and right of it (readable over bright and dark alike).
function Bar( GC gc, float x, float y, float w, float h, Color C )
{
	gc.SetTileColorRGB( 0, 0, 0 );
	gc.DrawPattern( x + 1, y + 1, w, h, 0, 0, Texture'Solid' );
	gc.SetTileColor( C );
	gc.DrawPattern( x, y, w, h, 0, 0, Texture'Solid' );
}

// Text at x, y (bRight: ending at x), with its shadow.
function Say( GC gc, float x, float y, string S, Color C, optional bool bRight )
{
	local float w, h;

	gc.SetFont( Font'FontFixedWidthSmall' );
	gc.GetTextExtent( 0, w, h, S );
	if ( bRight )
		x -= w;
	gc.SetTextColorRGB( 0, 0, 0 );
	gc.DrawText( x + 1, y + 1, w, h, S );
	gc.SetTextColor( C );
	gc.DrawText( x, y, w, h, S );
}

// The four corners of a box, each L long, t thick.
function Corners( GC gc, float x1, float y1, float x2, float y2, float L, float t, Color C )
{
	L = FMin( L, FMin( x2 - x1, y2 - y1 ) / 2 );
	Bar( gc, x1, y1, L, t, C );
	Bar( gc, x1, y1, t, L, C );
	Bar( gc, x2 - L, y1, L, t, C );
	Bar( gc, x2 - t, y1, t, L, C );
	Bar( gc, x1, y2 - t, L, t, C );
	Bar( gc, x1, y2 - L, t, L, C );
	Bar( gc, x2 - L, y2 - t, L, t, C );
	Bar( gc, x2 - t, y2 - L, t, L, C );
}

// The smallest box on screen round A's collision (as the targeting aug's), padded; false: not in view.
function bool Framed( Actor A, float Pad, out float x1, out float y1, out float x2, out float y2 )
{
	local vector v;
	local float x, y;
	local int i, j, k;
	local bool bAny;

	for ( i=-1; i<=1; i+=2 )
		for ( j=-1; j<=1; j+=2 )
			for ( k=-1; k<=1; k+=2 )
			{
				v = A.Location;
				v.X += i * A.CollisionRadius;
				v.Y += j * A.CollisionRadius;
				v.Z += k * A.CollisionHeight;
				if ( !ConvertVectorToCoordinates( v, x, y ) )
					continue;
				if ( !bAny )
				{
					x1 = x; x2 = x; y1 = y; y2 = y;
					bAny = true;
				}
				x1 = FMin( x1, x ); x2 = FMax( x2, x );
				y1 = FMin( y1, y ); y2 = FMax( y2, y );
			}
	if ( !bAny )
		return false;
	x1 -= Pad; y1 -= Pad; x2 += Pad; y2 += Pad;
	return x2>0 && y2>0 && x1<width && y1<height;
}

function int Meters( float Units )
{
	return int(Units / 52.5 + 0.5);
}

function string Three( int n )
{
	return Right( "00" $ n, 3 );
}

function string Stamp( float T )
{
	local int m, s;

	m = int(T / 60);
	s = int(T - m * 60);
	return Right( "0" $ m, 2 ) $ ":" $ Right( "0" $ s, 2 ) $ "." $ int((T - int(T)) * 10);
}

event DrawWindow( GC gc )
{
	local DeusExPlayer P;
	local float s, t, cx, cy, x, x1, y1, x2, y2, Head, Rel;
	local int i, k;
	local Actor A;
	local bool bMarked;
	local vector HitLoc, HitNormal, From;
	local rotator R;

	P = DeusExPlayer(GetPlayerPawn());
	if ( P==None || Drone==None || Drone.bDeleteMe || !P.bSpyDroneActive || P.aDrone!=Drone )
		return;
	if ( Human(P)!=None && !Human(P).bAltSpyDroneView )
		return;                                     // (the drone's view in the small window: nothing to lay over)
	s = height / 720.0;
	t = FMax( 1, int(s + 0.5) );
	cx = int(width / 2);
	cy = int(height / 2);
	From = Drone.Location;
	R = P.ViewRotation;
	gc.SetStyle( DSTY_Normal );

	// The screen's corners; the cross open in the middle, a dot, the gate round it.
	Corners( gc, 26 * s, 26 * s, width - 26 * s, height - 26 * s, 46 * s, t, Ink );
	Bar( gc, cx - 39 * s, cy, 30 * s, t, Ink );
	Bar( gc, cx + 9 * s, cy, 30 * s, t, Ink );
	Bar( gc, cx, cy - 39 * s, t, 30 * s, Ink );
	Bar( gc, cx, cy + 9 * s, t, 30 * s, Ink );
	Bar( gc, cx - t, cy - t, 3 * t, 3 * t, Ink );
	Corners( gc, cx - 64 * s, cy - 48 * s, cx + 64 * s, cy + 48 * s, 14 * s, t, Ink );

	// The heading tape: a tick each 10 degrees, a number each 30, 45 degrees either side; a caret under it.
	Head = (R.Yaw & 65535) * 360.0 / 65536.0;
	for ( k=int(Head / 10) * 10 - 50; k<=Head + 50; k+=10 )
	{
		Rel = k - Head;
		if ( Abs( Rel )>45 )
			continue;
		x = cx + Rel * 5 * s;
		if ( k % 30==0 )
		{
			Bar( gc, x, 62 * s, t, 10 * s, Ink );
			Say( gc, x - 9 * s, 48 * s, Three( (k + 360) % 360 ), Ink );
		}
		else
			Bar( gc, x, 66 * s, t, 6 * s, Ink );
	}
	Bar( gc, cx - 4 * s, 76 * s, 8 * s + t, t, Ink );
	Bar( gc, cx, 76 * s, t, 6 * s, Ink );

	// The hostiles in sight: boxed; those the sent drones are after: their number; the lock: red.
	for ( i=0; i<ArrayCount(Drone.Seen); i++ )
	{
		A = Drone.Seen[i];
		if ( A==None || A.bDeleteMe || A==Drone.LockOn || !Framed( A, 4 * s, x1, y1, x2, y2 ) )
			continue;
		bMarked = false;
		for ( k=0; k<ArrayCount(Drone.Marked); k++ )
			bMarked = bMarked || Drone.Marked[k]==A;
		if ( !bMarked )
			Corners( gc, x1, y1, x2, y2, 9 * s, t, Ink );
	}
	for ( k=0; k<ArrayCount(Drone.Marked); k++ )
	{
		A = Drone.Marked[k];
		if ( A==None || A.bDeleteMe || !Framed( A, 4 * s, x1, y1, x2, y2 ) )
			continue;
		Corners( gc, x1, y1, x2, y2, 9 * s, t, Mark );
		Say( gc, x1, y1 - 14 * s, "D" $ (k + 1), Mark );
	}
	A = Drone.LockOn;
	if ( A!=None && !A.bDeleteMe && Framed( A, 7 * s, x1, y1, x2, y2 ) )
	{
		Corners( gc, x1, y1, x2, y2, 14 * s, t + 1, Lock );
		Bar( gc, (x1 + x2) / 2 - t, (y1 + y2) / 2 - t, 3 * t, 3 * t, Lock );
		Say( gc, x1, y1 - 14 * s, "LOCK" @ Meters( VSize(A.Location - From) ) $ "M", Lock );
	}

	// The readouts.
	if ( Drone.bLead )
	{
		Say( gc, 40 * s, 88 * s, "FPV-LEAD", Ink );
		Say( gc, 40 * s, 102 * s, "SWARM" @ Drone.Ready, Ink );
	}
	else
		Say( gc, 40 * s, 88 * s, "FPV-RACER", Ink );
	Say( gc, width - 40 * s, 88 * s, "T+" $ Stamp( P.Level.TimeSeconds - Born ), Ink, true );
	if ( int(P.Level.TimeSeconds * 2) % 2==0 )
		Bar( gc, width - 74 * s, 104 * s, 6 * s, 6 * s, Lock );
	Say( gc, width - 40 * s, 102 * s, "REC", Ink, true );
	if ( P.Trace( HitLoc, HitNormal, From - vect(0,0,8000), From, false )==None )
		HitLoc = From - vect(0,0,8000);
	Say( gc, 40 * s, height - 132 * s, "LOAD" @ Caps( class'CoopMechAugDrones'.static.KindName( Drone.Kind ) ), Ink );
	Say( gc, 40 * s, height - 118 * s, "GEAR" @ Gears[Min( Drone.Gear, 2 )], Ink );
	Say( gc, 40 * s, height - 104 * s, "BAT" @ Drone.Charge $ "%", Ink );
	Say( gc, 40 * s, height - 90 * s, "ALT" @ Meters( From.Z - HitLoc.Z ) $ "M", Ink );
	Say( gc, 40 * s, height - 76 * s, "SPD" @ Meters( VSize(Drone.Velocity) ) $ "M/S", Ink );
	if ( P.Trace( HitLoc, HitNormal, From + vector(R) * 6000, From, true )==None )
		HitLoc = From + vector(R) * 6000;
	Say( gc, width - 40 * s, height - 90 * s, "HDG" @ Three( int(Head + 0.5) % 360 ), Ink, true );
	Say( gc, width - 40 * s, height - 76 * s, "RNG" @ Meters( VSize(HitLoc - From) ) $ "M", Ink, true );
	if ( Drone.LockOn!=None )
		Say( gc, cx - 30 * s, cy + 58 * s, "TGT LOCK", Lock );
	else if ( Drone.Ready>0 )
		Say( gc, cx - 16 * s, cy + 58 * s, "SCAN", Ink );
}

defaultproperties
{
	Ink=(R=225,G=240,B=225)
	Lock=(R=255,G=72,B=48)
	Mark=(R=255,G=190,B=64)
	Gears(0)="SLOW"
	Gears(1)="MED"
	Gears(2)="FAST"
}
