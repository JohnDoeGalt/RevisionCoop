//=============================================================================
// CoopTestTwin.
//
// ?CoopTest=Twin (run_net_live.ps1 -Clients 2 -SameName -ClientGap 25): a player
// comes back while its old self is still in the game (a crashed game started again
// before the host noticed): the old one goes, the new one has its things
// (CoopGameInfo.DropOldSelf), and there is one of it. The first is stalled first (ClientTest
// "stall": no more moves), as a crashed game is: a live teammate's name is never taken over.
//=============================================================================
class CoopTestTwin extends CoopTest;

var string First; // the first Tester1's pawn (a reference to it goes with it)

function Run( int t )
{
	local Inventory Kit;
	local Pawn P;
	local int n;

	if ( First=="" && t==5 )
	{
		First = string(Remote);
		Remote.Credits = 999;
		Kit = Spawn( class'MedKit',,, Remote.Location );
		Remote.FrobTarget = Kit;
		Remote.HandleItemPickup( Kit );
		Log( "RevNetTest: the first Tester1 (" $ Remote $ "): credits" @ Remote.Credits @ "medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None), 'RevNet' );
		// As a crashed game: no more moves from it (a teammate's name is only taken over from a
		// game gone quiet: CoopGameInfo.NameTaken, DropOldSelf).
		Remote.ClientTest( "stall" );
	}
	else if ( First!="" && string(Remote)!=First && t==5 )
	{
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( PlayerPawn(P)!=None && P.PlayerReplicationInfo.PlayerName=="Tester1" )
				n++;
		Log( "RevNetTest: the second Tester1 (" $ Remote $ "): credits" @ Remote.Credits @ "medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None)
			@ "| Tester1s in the game" @ n, 'RevNet' );
		Done();
	}
}
