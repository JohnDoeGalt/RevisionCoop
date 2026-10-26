//=============================================================================
// CoopTestAugSave.
//
// ?CoopTest=AugSave: a nano player's augmentations and their levels come back with it
// after it drops out and reconnects (CoopSave.LoadPlayer), in every mode (HR's own aug
// manager: CoopRules.FirstAug).
//=============================================================================
class CoopTestAugSave extends CoopTest;

var int Stage;

function Run( int t )
{
	local Augmentation Aug;
	local class<Augmentation> C;

	if ( Stage==0 && t==5 )
	{
		C = class<Augmentation>( DynamicLoadObject( "DeusEx.AugSpeed", class'Class' ) );
		Aug = Remote.AugmentationSystem.GivePlayerAugmentation( C );
		if ( Aug!=None )
			Aug.CurrentLevel = 2;
		C = class<Augmentation>( DynamicLoadObject( "DeusEx.AugBallistic", class'Class' ) );
		Aug = Remote.AugmentationSystem.GivePlayerAugmentation( C );
		if ( Aug!=None )
			Aug.CurrentLevel = 1;
		Log( "RevNetTest: augs before leaving:" @ Augs(), 'RevNet' );
		Stage = 1;
	}
	else if ( Stage==1 && t==7 )
	{
		Stage = 2;
		Log( "RevNetTest: the client drops out and reconnects", 'RevNet' );
		Remote.ClientTest( "reconnect" );
	}
	else if ( Stage==2 && t==2 ) // (t counts from the client's return)
		Log( "RevNetTest: augs right after coming back:" @ Augs(), 'RevNet' );
	else if ( Stage==2 && t==6 )
	{
		Log( "RevNetTest: augs after coming back:" @ Augs(), 'RevNet' );
		Done();
	}
}

// The augs the client has, with their levels.
function string Augs()
{
	local Augmentation Aug;
	local string S;
	local int n;

	for ( Aug=class'CoopRules'.static.FirstAug( Remote ); Aug!=None && n<256; Aug=Aug.next )
	{
		n++;
		if ( Aug.bHasIt )
			S = S @ Aug.Class.Name $ ":" $ Aug.CurrentLevel;
	}
	return S @ "(" $ n @ "in the list)";
}
