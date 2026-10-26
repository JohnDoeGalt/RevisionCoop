//=============================================================================
// CoopTestSave.
//
// ?CoopTest=Save: the host saves (CoopSave) with a client in the game, things
// change, the host quick-loads: the team is back on the saved map (fresh) with
// the saved flag, credits, items and both players' augmentations.
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
		GiveAug( Remote, "DeusEx.AugSpeed", 2 );
		GiveAug( Host, "DeusEx.AugCombat", 1 );
		Log( "RevNetTest: augs saved: client" @ Augs( Remote ) @ "| host" @ Augs( Host ), 'RevNet' );
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
		GiveAug( Remote, "DeusEx.AugSpeed", 0 );
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
		Log( "RevNetTest: after load: augs: client" @ Augs( Remote ) @ "| host" @ Augs( Host ), 'RevNet' );
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

// An aug (by name) at a level.
function GiveAug( Pawn P, string ClassName, int Level )
{
	local Augmentation Aug;

	Aug = DeusExPlayer(P).AugmentationSystem.GivePlayerAugmentation( class<Augmentation>( DynamicLoadObject( ClassName, class'Class' ) ) );
	if ( Aug!=None )
		Aug.CurrentLevel = Level;
}

// The augs a player has, with their levels.
function string Augs( Pawn P )
{
	local Augmentation Aug;
	local string S;
	local int n;

	for ( Aug=class'CoopRules'.static.FirstAug( P ); Aug!=None && n<256; Aug=Aug.next )
	{
		n++;
		if ( Aug.bHasIt )
			S = S @ Aug.Class.Name $ ":" $ Aug.CurrentLevel;
	}
	return S @ "(" $ n $ ")";
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
