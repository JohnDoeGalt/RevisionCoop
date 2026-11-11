//=============================================================================
// CoopMechAugBurst.
//
// Arsenal: active protection, as on a tank (the user's design). While it is on,
// launchers round the chassis fire a 20 mm charge at a rocket or a grenade
// coming in, setting it off out of reach of its own blast (shredding it when it
// is already too close for that), and a blast in a narrow cone (30 degrees)
// toward an enemy that comes close. Each shot spends one 20 mm round (the
// assault rifle's grenades), not energy; then the launcher reloads. It finds
// projectiles as the nano Aggressive Defense System does (AugDefense). Players,
// and characters not hostile to the Mech, are never hit. (It was the Shrapnel
// Burst: the class keeps its name, so saves keep its level.)
//=============================================================================
class CoopMechAugBurst extends CoopMechAug;

var float Intercept[4];   // how far out it fires at a projectile coming in
var float Close[4];       // how close an enemy gets before it fires the cone
var float Cooldown[4];    // the launcher's reload between shots
var float ReadyAt, WarnedAt;
var localized string ArmedText, NoAmmoText;

function Activate()
{
	local Ammo A;

	if ( !bHasIt )
		return;
	Super.Activate();
	if ( bIsActive && Player!=None )
	{
		A = Ammo(Player.FindInventoryType( class'Ammo20mm' ));
		if ( A!=None )
			Player.ClientMessage( Sprintf( ArmedText, A.AmmoAmount ) );
		else
			Player.ClientMessage( NoAmmoText );
	}
}

function Deactivate()
{
	Super.Deactivate();
	SetTimer( 0.05, false );
}

state Active
{
	function Timer()
	{
		Scan();
	}
Begin:
	SetTimer( 0.05, true );
}

// One look round: a projectile coming in first (the nearest), else the nearest
// hostile character close by; one shot at it if the launcher is loaded.
function Scan()
{
	local Pawn P;
	local DeusExProjectile Proj, Shot;
	local ScriptedPawn SP, Foe;
	local float D, Best;
	local Ammo A;

	P = Player;
	if ( P==None || P.Health<=0 || (CoopPlayerCore(P)!=None && CoopPlayerCore(P).bDowned) || Level.TimeSeconds<ReadyAt )
		return;
	Best = Intercept[CurrentLevel];
	foreach P.RadiusActors( class'DeusExProjectile', Proj, Intercept[CurrentLevel] )
		if ( Incoming( Proj, P ) )
		{
			D = VSize(Proj.Location - P.Location);
			if ( D<Best )
			{
				Best = D;
				Shot = Proj;
			}
		}
	if ( Shot==None )
	{
		Best = Close[CurrentLevel];
		foreach P.RadiusActors( class'ScriptedPawn', SP, Close[CurrentLevel] )
			if ( SP.Health>0 && !SP.bDeleteMe && SP.GetPawnAllianceType( P )==ALLIANCE_Hostile && FastTrace( SP.Location, P.Location ) )
			{
				D = VSize(SP.Location - P.Location);
				if ( D<Best )
				{
					Best = D;
					Foe = SP;
				}
			}
		if ( Foe==None )
			return;
	}
	A = Ammo(P.FindInventoryType( class'Ammo20mm' ));
	if ( A==None || A.AmmoAmount<=0 )
	{
		if ( Level.TimeSeconds>WarnedAt )
		{
			P.ClientMessage( NoAmmoText );
			WarnedAt = Level.TimeSeconds + 6;
		}
		return;
	}
	A.UseAmmo( 1 );
	ReadyAt = Level.TimeSeconds + Cooldown[CurrentLevel];
	if ( Shot!=None )
		Intercepted( Shot, P );
	else
		Cone( Foe, P );
}

// A projectile worth a shot: one that explodes, moving toward the Mech, not the
// team's own, not a friendly character's, in sight (as AugDefense judges them).
function bool Incoming( DeusExProjectile Proj, Pawn P )
{
	local Pawn Ally;

	if ( Proj.bDeleteMe || !Proj.bExplodes || Proj.bIgnoresNanoDefense || Proj.bStuck || VSize(Proj.Velocity)<100 )
		return false;
	if ( PlayerPawn(Proj.Owner)!=None || PlayerPawn(Proj.Instigator)!=None )
		return false;
	if ( ScriptedPawn(Proj.Owner)!=None && ScriptedPawn(Proj.Owner).GetPawnAllianceType( P )!=ALLIANCE_Hostile )
		return false;
	if ( Toward( Proj, P ) )
		return true;
	for ( Ally=Level.PawnList; Ally!=None; Ally=Ally.NextPawn )     // (an ally within a few metres is covered too)
		if ( Ally!=P && PlayerPawn(Ally)!=None && Ally.Health>0 && VSize(Ally.Location - P.Location)<=160 && Toward( Proj, Ally ) )
			return true;
	return false;
}

// Proj heading at T, in sight.
function bool Toward( DeusExProjectile Proj, Pawn T )
{
	return Normal(Proj.Velocity) Dot Normal(T.Location - Proj.Location) > 0.6 && FastTrace( Proj.Location, T.Location );
}

// A charge at a projectile: it goes off where it is when the Mech is out of
// reach of its blast, else the charge shreds it without its blast.
function Intercepted( DeusExProjectile Proj, Pawn P )
{
	local vector Dir;
	local float D;
	local string How;

	D = VSize(Proj.Location - P.Location);
	Dir = Normal(Proj.Location - P.Location);
	Launch( P, Dir );
	if ( D>Proj.blastRadius + P.CollisionRadius + 16 )
	{
		How = "set off";
		Proj.bAggressiveExploded = true;     // (clients set it off too; the kill is the Mech's)
		Proj.AggressiveExplodedOwner = P;
		Proj.Explode( Proj.Location, -Dir );
	}
	else
	{
		How = "shredded";
		Blast( Proj.Location, 0.6 );
		P.PlaySound( Sound'DeusExSounds.Generic.SmallExplosion1', SLOT_None, 2.0,, 2048 );
		Proj.Destroy();
	}
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "active protection:" @ How @ Proj.Class.Name @ "at" @ int(D), 'RevNet' );
}

// A blast in a 30 degree cone toward an enemy that came close: hostile
// characters and things in it (each counted in when any of it is in the cone).
function Cone( ScriptedPawn Foe, Pawn P )
{
	local vector Dir, To;
	local Actor A;
	local float Reach, D, Dmg;
	local int Hit;

	Dir = Normal(Foe.Location - P.Location);
	Reach = Close[CurrentLevel] + 96;
	Launch( P, Dir );
	foreach P.RadiusActors( class'Actor', A, Reach )
	{
		if ( A==P || A.bDeleteMe || PlayerPawn(A)!=None )
			continue;
		if ( ScriptedPawn(A)!=None )
		{
			if ( ScriptedPawn(A).GetPawnAllianceType( P )!=ALLIANCE_Hostile )
				continue;
		}
		else if ( DeusExDecoration(A)==None )
			continue;
		To = A.Location - P.Location;
		D = FMax( VSize(To), 1 );
		if ( Normal(To) Dot Dir < Cos( 0.2618 + Atan( A.CollisionRadius / D ) ) || !FastTrace( A.Location, P.Location ) )
			continue;
		Dmg = LevelValues[CurrentLevel] * (1.0 - 0.4 * D / Reach);
		A.TakeDamage( int(Dmg), P, A.Location - Normal(To) * A.CollisionRadius, Normal(To) * Dmg * 300, 'Exploded' );
		Hit++;
	}
	Blast( P.Location + Dir * Reach * 0.55, Reach / 96.0 );
	P.PlaySound( Sound'DeusExSounds.Generic.MediumExplosion1', SLOT_None, 2.0,, 2048 );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "active protection: cone at" @ Foe.Name @ "hit" @ Hit, 'RevNet' );
}

// The launch: a flash at the chassis on the side it fires, the report, heard by the AI.
function Launch( Pawn P, vector Dir )
{
	Blast( P.Location + Dir * (P.CollisionRadius + 16) + vect(0,0,16), 0.4 );
	P.PlaySound( Sound'DeusExSounds.Weapons.AssaultGunFire20mm', SLOT_None, 2.0,, 2048 );
	P.AISendEvent( 'LoudNoise', EAITYPE_Audio, 2.0, 1536 );
}

// An explosion effect here and on every client (the host's own effects don't
// reach them: CoopPlayerCore.ClientBlast).
function Blast( vector At, float Size )
{
	local CoopPlayerCore C;

	if ( Size<1 )
		Spawn( class'ExplosionSmall',,, At );
	else
		Spawn( class'ExplosionMedium',,, At );
	Spawn( class'SphereEffect',,, At ).Size = Size;
	foreach AllActors( class'CoopPlayerCore', C )
		if ( NetConnection(C.Player)!=None )
			C.ClientBlast( At, Size );
}

defaultproperties
{
	bPassive=False
	Key=5
	Requires=Class'CoopMechAugBlades'
	RequiresLevel=1
	LevelValues(0)=40
	LevelValues(1)=60
	LevelValues(2)=80
	LevelValues(3)=100
	Intercept(0)=480
	Intercept(1)=560
	Intercept(2)=640
	Intercept(3)=720
	Close(0)=192
	Close(1)=224
	Close(2)=256
	Close(3)=288
	Cooldown(0)=3
	Cooldown(1)=2.5
	Cooldown(2)=2
	Cooldown(3)=1.5
	TreeName="Arsenal"
	AugmentationName="Active Protection"
	Description="Launchers round the chassis, as on a tank: while it is on, they fire a 20 mm charge at a rocket or a grenade coming in, setting it off before it arrives, and a blast in a narrow cone at an enemy that comes close. Each shot uses one 20 mm round (the assault rifle's grenades), not energy."
	LevelText(0)="Fires at rockets and grenades within 30 feet, and a 40-damage cone at enemies within 12 feet; reloads in 3 s."
	LevelText(1)="Rockets within 35 feet; 60 damage, enemies within 14 feet; 2.5 s."
	LevelText(2)="Rockets within 40 feet; 80 damage, enemies within 16 feet; 2 s."
	LevelText(3)="Rockets within 45 feet; 100 damage, enemies within 18 feet; 1.5 s."
	ArmedText="Active Protection on: %d 20 mm rounds."
	NoAmmoText="Active Protection: no 20 mm rounds."
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	Icon=Texture'DeusExUI.UserInterface.AugIconDefense'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDefense_Small'
}
