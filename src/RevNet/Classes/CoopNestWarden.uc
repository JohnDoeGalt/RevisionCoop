//=============================================================================
// CoopNestWarden.
//
// The Corvane SL-4 Warden (docs/superpowers/specs/2026-11-03-kit-nests-design.md): a
// locker hardened on its own for corridors and security desks, its kit out of the front under
// its roll-up shutter, a bio cell and a console in its sill. Physically secure and tamper
// resistant: its console is the way in. Frobbed with a multitool it's bypassed (it launches
// nothing after); with Electronics at Advanced or better it's turned (as the game's alarm
// panels are hacked): its kit watches and goes for the turner's enemies.
//=============================================================================
class CoopNestWarden extends CoopNest;

var bool bBypassed, bTurned;
var float CloseAt;                  // (the host's) when its shutter comes down
var bool bShown, bShownOpen;        // (each machine's) its shutter as last set
var localized string BypassedText, TurnedText;

simulated function Dress()
{
	if ( bDressed )
		return;
	Super.Dress();
	Parts[0] = AddPart( 0, PartAt[0] );                                     // its shutter, down
}

simulated function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( (!bShown || bShownOpen!=bOpen) && Parts[0]!=None )
	{
		bShown = true;
		bShownOpen = bOpen;
		Parts[0].bHidden = bOpen;                                           // (rolled up into its drum)
	}
	if ( Role==ROLE_Authority && bOpen && Level.TimeSeconds>=CloseAt )
		bOpen = false;
}

function bool LaunchSlot( int i, Actor T )
{
	if ( bBypassed || !Super.LaunchSlot( i, T ) )
		return false;
	bOpen = true;
	CloseAt = Level.TimeSeconds + 2.0;
	return true;
}

// (CoopMapMemory) bypassed or turned, too.
function string Remembered()
{
	return Super.Remembered() $ "|" $ int(bBypassed) $ "|" $ int(bTurned);
}

function Recall( string S )
{
	Super.Recall( S );
	bBypassed = class'CoopSave'.static.Part( S, 3, "|" )=="1";
	bTurned = class'CoopSave'.static.Part( S, 4, "|" )=="1";
}

// A kit coming home: its shutter up for it.
function vector Entry( CoopFPVGuided K )
{
	bOpen = true;
	CloseAt = FMax( CloseAt, Level.TimeSeconds + 1.0 );
	return Super.Entry( K );
}

function Frob( Actor Frobber, Inventory frobWith )
{
	local DeusExPlayer P;
	local Multitool MT;

	P = DeusExPlayer(Frobber);
	MT = Multitool(frobWith);
	if ( P==None || MT==None || bBypassed || bTurned )
	{
		Super.Frob( Frobber, frobWith );
		return;
	}
	MT.UseOnce();
	if ( P.SkillSystem!=None && P.SkillSystem.GetSkillLevel( class'SkillTech' )>=2 )
	{
		bTurned = true;
		Friend = P;
		bWatches = true;
		P.ClientMessage( TurnedText );
	}
	else
	{
		bBypassed = true;
		P.ClientMessage( BypassedText );
	}
}

defaultproperties
{
	ItemName="SL-4 Warden"
	BypassedText="SL-4 Warden bypassed: it launches nothing now."
	TurnedText="SL-4 Warden turned: its kit is yours."
	CollisionRadius=11
	CollisionHeight=16.5
	PrePivot=(Z=-16.5)
	HitPoints=150
	// nest_game: begin
	MeshName="RevNetMech.CorvaneWardenBody"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_4A"
	SkinNames(2)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(3)="RevTexA51.OrangeLight_D"
	SkinNames(4)="RevNetMech.NestPad"
	SkinNames(5)="RevNetMech.NestPlateSl4Warden"
	SkinNames(6)="CoreTexMetal.Galvanzd"
	KitAt(0)=(X=1.000,Y=0.000,Z=24.580)
	KitYaw(0)=0
	nKits=1
	nCells=0
	PartMesh(0)="RevNetMech.CorvaneWardenShutter"
	PartAt(0)=(X=7.700,Y=-0.000,Z=13.100)
	PartSkin(0)="RevTexA51.ClenCntrlPanl_1A"
	nParts=1
	ScaleGlow=0.55
	// nest_game: end
}
