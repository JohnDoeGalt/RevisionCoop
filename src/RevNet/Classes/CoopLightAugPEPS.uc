//=============================================================================
// CoopLightAugPEPS.
//
// Arms: P.E.P.S., the pneumatic energy pulse system (experimental in Mankind
// Divided): one press sends a pressure wave ahead (a 60 degree cone) that knocks
// hostiles down and throws them and loose things back; at level 3 it knocks them
// out. Farther with each level.
//=============================================================================
class CoopLightAugPEPS extends CoopLightAug;

var float Range[4];

function bool Fire()
{
	local ScriptedPawn SP;
	local DeusExDecoration D;
	local vector From, Dir, Away;
	local float Cone;
	local int n;

	From = Eye();
	Dir = vector(Player.ViewRotation);
	Cone = Cos( 30 * Pi / 180 );
	foreach Player.RadiusActors( class'ScriptedPawn', SP, Range[CurrentLevel], From )
		if ( Hostile( SP, Player ) && Normal(SP.Location - From) dot Dir>Cone && Player.FastTrace( SP.Location, From ) )
		{
			Away = Normal(SP.Location - From + vect(0,0,40));
			if ( CurrentLevel>=2 )
				SP.TakeDamage( 40, Player, SP.Location - Away * SP.CollisionRadius, Away * 60000, 'KnockedOut' );
			else
				SP.TakeDamage( 10, Player, SP.Location - Away * SP.CollisionRadius, Away * 60000, 'Stunned' );
			n++;
		}
	foreach Player.RadiusActors( class'DeusExDecoration', D, Range[CurrentLevel], From )
		if ( D.bPushable && D.Physics!=PHYS_None && Normal(D.Location - From) dot Dir>Cone && Player.FastTrace( D.Location, From ) )
		{
			D.SetPhysics( PHYS_Falling );
			D.Velocity = Normal(D.Location - From + vect(0,0,40)) * 700;
			n++;
		}
	Blast( From + Dir * 64, 0 );
	Log( "RevNet: P.E.P.S. hit" @ n, 'RevNet' );
	return true;
}

defaultproperties
{
	bPassive=False
	Key=8
	Shot=20
	Range(0)=420
	Range(1)=525
	Range(2)=630
	Range(3)=735
	TreeName="Arms"
	AugmentationName="P.E.P.S."
	Description="A pneumatic pulse from the forearm that knocks people off their feet and sends loose things flying. 20 energy a use."
	LevelText(0)="Knocks down within 8 m."
	LevelText(1)="Within 10 m."
	LevelText(2)="Knocks out, within 12 m."
	LevelText(3)="Within 14 m."
	Icon=Texture'DeusExUI.UserInterface.AugIconMuscle'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconMuscle_Small'
}
