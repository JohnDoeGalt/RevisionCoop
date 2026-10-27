//=============================================================================
// CoopLightAugRemote.
//
// Cranium: Remote Hacking (experimental in Mankind Divided). One press knocks out
// the device nearest the crosshair with a remote EMP, as an EMP grenade would:
// cameras at level 1, turrets from level 2, robots from level 3 (Security
// Domination); level 4 reaches twice as far.
//=============================================================================
class CoopLightAugRemote extends CoopLightAug;

var float Range[4];

function bool Fire()
{
	local Actor A, Best;
	local vector From, Dir;
	local float d, BestDot;
	local int Dmg;

	From = Eye();
	Dir = vector(Player.ViewRotation);
	BestDot = Cos( 6 * Pi / 180 );
	foreach Player.RadiusActors( class'Actor', A, Range[CurrentLevel], From )
	{
		if ( !(A.IsA('SecurityCamera') || (CurrentLevel>=1 && A.IsA('AutoTurret')) || (CurrentLevel>=2 && Robot(A)!=None && Hostile( Pawn(A), Player ))) )
			continue;
		d = Normal(A.Location - From) dot Dir;
		if ( d>BestDot && Player.FastTrace( A.Location, From ) )
		{
			Best = A;
			BestDot = d;
		}
	}
	if ( Best==None )
	{
		Player.ClientMessage( Fill( NoTargetText, AugmentationName ) );
		return false;
	}
	Dmg = 100;
	if ( Robot(Best)!=None )
		Dmg = Max( 100, Robot(Best).EMPHitPoints );     // shut down outright
	Best.TakeDamage( Dmg, Player, Best.Location, vect(0,0,0), 'EMP' );
	Best.PlaySound( Sound'DeusExSounds.Weapons.EMPZap', SLOT_None,,, 1280 );
	Log( "RevNet: remote hack on" @ Best, 'RevNet' );
	return true;
}

defaultproperties
{
	bPassive=False
	Key=4
	Shot=10
	Range(0)=1050
	Range(1)=1050
	Range(2)=1050
	Range(3)=2100
	TreeName="Cranium"
	AugmentationName="Remote Hacking"
	Description="A wireless intrusion suite: the device under the crosshair is knocked out by a remote pulse. 10 energy a use."
	LevelText(0)="Security cameras within 20 m."
	LevelText(1)="Turrets too."
	LevelText(2)="Robots too (Security Domination)."
	LevelText(3)="Within 40 m."
	Icon=Texture'DeusExUI.UserInterface.AugIconEMP'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconEMP_Small'
}
