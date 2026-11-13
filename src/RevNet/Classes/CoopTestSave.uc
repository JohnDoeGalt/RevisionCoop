//=============================================================================
// CoopTestSave.
//
// ?CoopTest=Save: the host saves (CoopSave) with a client in the game, things
// change, the host quick-loads: the team is back on the saved map (fresh) with
// the saved flag, credits, items and both players' augmentations.
//=============================================================================
class CoopTestSave extends CoopTest;

var config vector BoatAt; // the police boat's place at the save
var config int Stage; // 0 fresh, 1 saved, 2 loading, 3 done (in the test ini: a new map has a new test actor)

function Run( int t )
{
	local Inventory Kit;
	local DataVaultImage Img;
	local int n;

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
		// An image the host has (Paul's map: a load put it back lying in the world, a "cube").
		Img = Spawn( class'Image01_LibertyIsland', Host );
		Img.GiveTo( Host );
		Img.SetBase( Host );
		Host.AddImage( Img );
		Log( "RevNetTest: augs saved: client" @ Augs( Remote ) @ "| host" @ Augs( Host ), 'RevNet' );
		Boat( "at the save" );
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
		// Something the client picks up after the save: a load takes it away.
		Kit = Spawn( class'WeaponCrowbar',,, Remote.Location );
		Remote.FrobTarget = Kit;
		Remote.HandleItemPickup( Kit );
		Log( "RevNetTest: client picked up after the save: crowbar=" $ (Remote.FindInventoryType(class'WeaponCrowbar')!=None), 'RevNet' );
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
		Boat( "after the load" );
		Log( "RevNetTest: after load: augs: client" @ Augs( Remote ) @ "| host" @ Augs( Host ), 'RevNet' );
		n = 0;
		foreach AllActors( class'DataVaultImage', Img )
			if ( Img.Owner==None || Img.IsInState('Pickup') )
			{
				n++;
				Log( "RevNetTest: after load an image lies in the world:" @ Img @ Img.GetStateName() @ "owner=" $ Img.Owner @ "at" @ Img.Location, 'RevNet' );
			}
		Check( "no image lying in the world after the load (" $ n $ ")", n==0 );
		n = 0;
		for ( Img=Host.FirstImage; Img!=None; Img=Img.NextImage )
			if ( Img.IsA('Image01_LibertyIsland') )
				n++;
		Check( "host has the saved image once (" $ n $ ")", n==1 );
		Check( "client lost what it picked up after the save", Remote.FindInventoryType(class'WeaponCrowbar')==None );
		Done();
	}
}

// The police boat by the dock (playtest: "the boat near the start floats in the air when reloading").
function Boat( string When )
{
	local Actor A;

	foreach AllActors( class'Actor', A )
		if ( A.IsA('NYPoliceBoat') )
		{
			if ( When=="at the save" )
				BoatAt = A.Location;
			else
				Check( "the boat is back where it was saved (" $ int(VSize(A.Location - BoatAt)) @ "units off)", VSize(A.Location - BoatAt)<8 );
			Log( "RevNetTest: boat" @ When $ ":" @ A.Name @ "at" @ A.Location @ "physics" @ GetEnum( enum'EPhysics', A.Physics ) @ "target" @ A.Target @ "state" @ A.GetStateName(), 'RevNet' );
		}
}

function Check( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
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
