//=============================================================================
// CoopLightAugTyphoon.
//
// Torso: the Typhoon explosive system (Mankind Divided's): one press fires a ring
// of explosive rounds from the torso. Hostiles within reach and in sight take
// LevelValues damage; players and characters not hostile are never hit.
//=============================================================================
class CoopLightAugTyphoon extends CoopLightAug;

var float Range[4];

function bool Fire()
{
	local ScriptedPawn SP;
	local vector From, Dir;
	local int i, n;

	From = Player.Location;
	foreach Player.RadiusActors( class'ScriptedPawn', SP, Range[CurrentLevel], From )
		if ( Hostile( SP, Player ) && Player.FastTrace( SP.Location, From ) )
		{
			Dir = Normal(SP.Location - From + vect(0,0,32));
			SP.TakeDamage( LevelValues[CurrentLevel], Player, SP.Location - Dir * SP.CollisionRadius, Dir * 30000, 'Exploded' );
			n++;
		}
	for ( i=0; i<6; i++ )
		Blast( From + vector(rot(0,1,0) * (i * 10923)) * 96, 0 );
	Player.PlaySound( Sound'DeusExSounds.Generic.MediumExplosion1', SLOT_None, 2.0,, 2048 );
	Log( "RevNet: Typhoon hit" @ n, 'RevNet' );
	return true;
}

defaultproperties
{
	bPassive=False
	Key=9
	Shot=25
	LevelValues(0)=60
	LevelValues(1)=80
	LevelValues(2)=100
	LevelValues(3)=130
	Range(0)=420
	Range(1)=470
	Range(2)=525
	Range(3)=630
	TreeName="Torso & Skin"
	AugmentationName="Typhoon"
	Description="Launchers under the skin of the torso fire a ring of explosive rounds at everyone hostile around. 25 energy a use."
	LevelText(0)="60 damage within 8 m."
	LevelText(1)="80 within 9 m."
	LevelText(2)="100 within 10 m."
	LevelText(3)="130 within 12 m."
	Icon=Texture'DeusExUI.UserInterface.AugIconDefense'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDefense_Small'
}
