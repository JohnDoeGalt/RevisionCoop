//=============================================================================
// CoopLightAugTesla.
//
// Arms: Tesla (experimental in Mankind Divided): one press sends stun darts at
// the hostiles nearest the crosshair, one at level 1 up to four at level 4,
// farther with each level. People are stunned, robots shorted.
//=============================================================================
class CoopLightAugTesla extends CoopLightAug;

var float Range[4];

function bool Fire()
{
	local int i;

	Aim( Range[CurrentLevel], 25, CurrentLevel + 1 );
	if ( NumHit==0 )
	{
		Player.ClientMessage( Fill( NoTargetText, AugmentationName ) );
		return false;
	}
	for ( i=0; i<NumHit; i++ )
	{
		if ( Robot(Hit[i])!=None )
			Hit[i].TakeDamage( 60, Player, Hit[i].Location, vect(0,0,0), 'EMP' );
		else
			Hit[i].TakeDamage( 20, Player, Hit[i].Location, vect(0,0,0), 'Stunned' );
		Hit[i].PlaySound( Sound'DeusExSounds.Weapons.ProdFire', SLOT_None,,, 1024 );
	}
	Log( "RevNet: Tesla stunned" @ NumHit, 'RevNet' );
	return true;
}

defaultproperties
{
	bPassive=False
	Key=6
	Shot=15
	Range(0)=630
	Range(1)=1050
	Range(2)=1575
	Range(3)=2360
	TreeName="Arms"
	AugmentationName="Tesla"
	Description="Stun darts fired from the forearm, arcing to the targets nearest the crosshair. 15 energy a use."
	LevelText(0)="One target within 12 m."
	LevelText(1)="Two within 20 m."
	LevelText(2)="Three within 30 m."
	LevelText(3)="Four within 45 m."
	Icon=Texture'DeusExUI.UserInterface.AugIconEMP'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconEMP_Small'
}
