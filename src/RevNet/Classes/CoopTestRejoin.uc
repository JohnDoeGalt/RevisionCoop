//=============================================================================
// CoopTestRejoin.
//
// ?CoopTest=Rejoin: a client with credits, a medkit and its light on drops out and
// comes back (the engine's "reconnect"): it gets its things back
// (CoopGameInfo.Rejoined), not a new character's; its old augmentations go with it
// (CoopGameInfo.PlayerLeaving), and the host's rain stays the host's
// (CoopClient.KeepWeather) through its coming and going.
//=============================================================================
class CoopTestRejoin extends CoopTest;

var int Stage;

function Run( int t )
{
	local Inventory Kit;
	local Augmentation Aug;

	if ( Stage==0 && t==5 )
	{
		Remote.Credits = 999;
		Kit = Spawn( class'MedKit',,, Remote.Location );
		Remote.FrobTarget = Kit;
		Remote.HandleItemPickup( Kit );
		Log( "RevNetTest: before leaving: credits" @ Remote.Credits @ "medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None), 'RevNet' );
		for ( Aug=Remote.AugmentationSystem.FirstAug; Aug!=None; Aug=Aug.next )
			if ( Aug.IsA('AugLight') && Aug.bHasIt && !Aug.bIsActive )
				Aug.Activate();
		Stage = 1;
	}
	else if ( Stage==1 && t==7 )
	{
		Log( "RevNetTest: before leaving:" @ Leftovers() @ "| weather:" @ Weather(), 'RevNet' );
		Stage = 2;
		Log( "RevNetTest: the client drops out and reconnects", 'RevNet' );
		Remote.ClientTest( "reconnect" );
	}
	else if ( Stage==2 && t==5 ) // (t counts from the client's return)
	{
		Log( "RevNetTest: after coming back: credits" @ Remote.Credits @ "medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None) @ "things" @ Things( Remote ), 'RevNet' );
		Log( "RevNetTest: after coming back:" @ Leftovers() @ "| weather:" @ Weather(), 'RevNet' );
		Done();
	}
}

// Augmentations and light beams with no player, of all there are.
function string Leftovers()
{
	local Augmentation Aug;
	local Beam B;
	local int Augs, Orphans, Beams, OrphanBeams;

	foreach AllActors( class'Augmentation', Aug )
	{
		Augs++;
		if ( Aug.Player==None || Aug.Player.bDeleteMe )
			Orphans++;
	}
	foreach AllActors( class'Beam', B )
	{
		Beams++;
		if ( B.Owner==None )
			OrphanBeams++;
	}
	return "augmentations" @ Augs @ "with no player" @ Orphans @ "| light beams" @ Beams @ "with no owner" @ OrphanBeams;
}

// Who the host's rain and its sound follow.
function string Weather()
{
	local Precipitator P;
	local FollowingSound S;
	local string L;

	foreach AllActors( class'Precipitator', P )
		if ( !P.IsA('PrecipitationNode') )
			L = L @ "rain on=" $ P.bOn @ "around" @ Who( P.Target );
	foreach AllActors( class'FollowingSound', S )
		L = L @ "| sound" @ S.GetStateName() @ "with" @ Who( S.Owner );
	return L;
}

function string Who( Actor A )
{
	if ( A==None )
		return "nobody";
	if ( A==Host )
		return "host";
	if ( A==Remote )
		return "client";
	return string(A.Name);
}
