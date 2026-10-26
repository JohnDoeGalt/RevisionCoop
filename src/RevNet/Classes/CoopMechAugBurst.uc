//=============================================================================
// CoopMechAugBurst.
//
// Arsenal: a burst of shrapnel from the Mech's body that hits everything around
// it (not the team), then has to recharge. A one-shot: never left on.
//=============================================================================
class CoopMechAugBurst extends CoopMechAug;

var float Radius[4], Cooldown[4];
var float EnergyCost;
var float ReadyAt;
var localized string RechargingText, NoEnergyText;

function Activate()
{
	local Pawn P;
	local CoopPlayerCore C;
	local Actor A;
	local float Dist, Dmg;
	local vector Dir;
	local int Hit;

	P = Player;
	if ( !bHasIt || P==None || P.Health<=0 || (CoopPlayerCore(P)!=None && CoopPlayerCore(P).bDowned) )
		return;
	if ( Level.TimeSeconds<ReadyAt )
	{
		P.ClientMessage( Sprintf( RechargingText, int(ReadyAt - Level.TimeSeconds) + 1 ) );
		return;
	}
	if ( Player.Energy<EnergyCost )
	{
		P.ClientMessage( NoEnergyText );
		return;
	}
	Player.Energy -= EnergyCost;
	ReadyAt = Level.TimeSeconds + Cooldown[CurrentLevel];
	foreach P.RadiusActors( class'Actor', A, Radius[CurrentLevel] )
	{
		if ( A==P || PlayerPawn(A)!=None || A.bDeleteMe || (ScriptedPawn(A)==None && DeusExDecoration(A)==None)
			|| !FastTrace( A.Location, P.Location ) )
			continue;
		Dist = VSize(A.Location - P.Location);
		Dmg = LevelValues[CurrentLevel] * (1.0 - 0.5 * Dist / Radius[CurrentLevel]);
		Dir = Normal(A.Location - P.Location + vect(0,0,32));
		A.TakeDamage( int(Dmg), P, A.Location - Dir * A.CollisionRadius, Dir * Dmg * 400, 'Exploded' );
		Hit++;
	}
	Spawn( class'ExplosionMedium',,, P.Location );
	Spawn( class'SphereEffect',,, P.Location ).Size = Radius[CurrentLevel] / 32.0;
	foreach AllActors( class'CoopPlayerCore', C )
		if ( NetConnection(C.Player)!=None )
			C.ClientBlast( P.Location, Radius[CurrentLevel] / 32.0 );
	P.PlaySound( Sound'DeusExSounds.Generic.MediumExplosion1', SLOT_None, 2.0,, Radius[CurrentLevel] * 4 );
	P.AISendEvent( 'LoudNoise', EAITYPE_Audio, 2.0, Radius[CurrentLevel] * 4 );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "shrapnel burst level" @ CurrentLevel + 1 @ "hit" @ Hit, 'RevNet' );
}

defaultproperties
{
	bPassive=False
	Key=5
	Requires=Class'CoopMechAugBlades'
	RequiresLevel=1
	EnergyCost=25
	LevelValues(0)=40
	LevelValues(1)=60
	LevelValues(2)=80
	LevelValues(3)=100
	Radius(0)=320
	Radius(1)=384
	Radius(2)=448
	Radius(3)=512
	Cooldown(0)=20
	Cooldown(1)=16
	Cooldown(2)=12
	Cooldown(3)=8
	TreeName="Arsenal"
	AugmentationName="Shrapnel Burst"
	Description="Charges packed into the chassis blow a ring of shrapnel out all around the Mech. 25 energy; then it has to recharge."
	LevelText(0)="40 damage up to 20 feet; recharges in 20 s."
	LevelText(1)="60 damage, 24 feet; 16 s."
	LevelText(2)="80 damage, 28 feet; 12 s."
	LevelText(3)="100 damage, 32 feet; 8 s."
	RechargingText="Shrapnel Burst: recharging (%d s)."
	NoEnergyText="Shrapnel Burst: not enough energy."
	Icon=Texture'DeusExUI.UserInterface.AugIconDefense'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDefense_Small'
}
