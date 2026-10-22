//=============================================================================
// CoopTestSave.
//
// ?CoopTest=Save: the host saves (CoopSave) with a client in the game, things
// change, the host quick-loads: the team is back on the saved map (fresh) with
// the saved flag, credits and items.
//=============================================================================
class CoopTestSave extends CoopTest;

var config int Stage; // 0 fresh, 1 saved, 2 loading, 3 done (in the test ini: a new map has a new test actor)

function Run( int t )
{
	local Inventory Kit;

	if ( Stage==0 && t==5 )
	{
		// The map as saved: this one gone (CoopMapMemory), UNATCOTroop1 removed after the save comes back.
		if ( FindNPC('Terrorist5')!=None )
			FindNPC('Terrorist5').Destroy();
		Host.flagBase.SetBool( 'RevNetSaveTest', true, true, 0 );
		Remote.Credits = 777;
		Kit = Spawn( class'MedKit',,, Remote.Location );
		Remote.FrobTarget = Kit;
		Remote.HandleItemPickup( Kit );
		SetStage( 1 );
		CoopGameInfo(Level.Game).SaveCoopGame( true );
		Log( "RevNetTest: saved: flag=true client credits=777 client medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None), 'RevNet' );
	}
	else if ( Stage==1 && t==9 )
	{
		// What the load must undo.
		Host.flagBase.SetBool( 'RevNetSaveTest', false, true, 0 );
		Remote.Credits = 1;
		Kit = Remote.FindInventoryType( class'MedKit' );
		if ( Kit!=None )
			Kit.Destroy();
		if ( FindNPC('UNATCOTroop1')!=None )
			FindNPC('UNATCOTroop1').Destroy();
		SetStage( 2 );
		Log( "RevNetTest: changed, loading", 'RevNet' );
		CoopGameInfo(Level.Game).LoadCoopGame();
	}
	else if ( Stage==2 && t==8 )
	{
		SetStage( 3 );
		Log( "RevNetTest: after load on" @ Level.Outer.Name $ ": flag=" $ Host.flagBase.GetBool('RevNetSaveTest') @ "client credits=" $ Remote.Credits @ "client medkit=" $ (Remote.FindInventoryType(class'MedKit')!=None) @ "client items" @ Things( Remote ), 'RevNet' );
		Log( "RevNetTest: after load: removed before the save still gone=" $ (FindNPC('Terrorist5')==None) @ "removed after the save back=" $ (FindNPC('UNATCOTroop1')!=None), 'RevNet' );
		Done();
	}
}

function ScriptedPawn FindNPC( name N )
{
	local ScriptedPawn P;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Name==N )
			return P;
	return None;
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
