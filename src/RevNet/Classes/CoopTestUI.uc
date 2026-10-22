//=============================================================================
// CoopTestUI.
//
// ?CoopTest=UI (01_NYC_UNATCOIsland): the remote player uses its own screens and
// keys as its player would (CoopPlayerUI.ClientUITest): belt keys and
// NextBeltItem, the inventory screen's Use / Equip / Drop (medkit, bio-cell, tech
// goggles, binoculars), the augmentations screen's bio-cell button, the skills
// screen's Upgrade; then what its HUD shows (hit display, vision, binoculars'
// view, a cloaked teammate, music). The host logs what happened to its things.
//=============================================================================
class CoopTestUI extends CoopTest;

var int Health0, Points0, Cells0, Kits0;
var float Energy0;
var string WeaponName;

function Run( int t )
{
	local Inventory Item;

	switch ( t )
	{
		case 3:
			Things( Remote );
			Give( class'MedKit' );
			Give( class'MedKit' );
			Give( class'BioelectricCell' );
			Give( class'BioelectricCell' );
			Give( class'TechGoggles' );
			Give( class'Binoculars' );
			Give( class'WeaponPistol' );
			Remote.HealthTorso = 40;
			Remote.HealthHead = 40;
			Remote.GenerateTotalHealth();
			Remote.Energy = 10;
			Remote.PutInHand( None );
			GiveAug( Remote, class'AugLight' );
			for ( Item=Remote.Inventory; Item!=None; Item=Item.Inventory )
				if ( DeusExWeapon(Item)!=None && WeaponName=="" )
					WeaponName = string(Item.Class.Name);
			Log( "RevNetTest: host's belt record:" @ Belt(), 'RevNet' );
			Log( "RevNetTest: root windows: client's pawn" @ Remote.rootWindow @ "host's" @ Host.rootWindow @ "| host's belt:" @ HostBelt(), 'RevNet' );
			break;
		case 5:
			Remote.ClientUITest( "belt" );
			break;

		// Belt keys, as the key bindings send them
		case 6:
			Remote.ClientUITest( "key", "1" );
			break;
		case 7:
			InHand( "after belt key 1" );
			Remote.ClientUITest( "key", "2" );
			break;
		case 8:
			InHand( "after belt key 2" );
			Remote.ClientUITest( "console", "NextBeltItem" );
			break;
		case 9:
			InHand( "after NextBeltItem" );
			Remote.ClientUITest( "console", "ShowInventoryWindow" );
			break;

		// The inventory screen
		case 10:
			Health0 = Remote.Health;
			Kits0 = Copies( class'MedKit' );
			Remote.ClientUITest( "inv use", "MedKit" );
			break;
		case 11:
			Log( "RevNetTest: inventory screen Use medkit: health" @ Health0 @ "->" @ Remote.Health @ "medkits" @ Kits0 @ "->" @ Copies( class'MedKit' ), 'RevNet' );
			Energy0 = Remote.Energy;
			Cells0 = Copies( class'BioelectricCell' );
			Remote.ClientUITest( "inv use", "BioelectricCell" );
			break;
		case 12:
			Log( "RevNetTest: inventory screen Use bio-cell: energy" @ int(Energy0) @ "->" @ int(Remote.Energy) @ "cells" @ Cells0 @ "->" @ Copies( class'BioelectricCell' ), 'RevNet' );
			Remote.ClientUITest( "inv equip", WeaponName );
			break;
		case 13:
			InHand( "after Equip" @ WeaponName );
			Remote.ClientUITest( "inv use", "TechGoggles" );
			break;
		case 15:
			Item = Remote.FindInventoryType( class'TechGoggles' );
			Log( "RevNetTest: inventory screen Use tech goggles: active=" $ (Item!=None && ChargedPickup(Item).IsActive()) @ "relevant radius" @ Remote.RelevantRadius, 'RevNet' );
			Remote.ClientUITest( "view" );
			break;
		case 16:
			Remote.ClientUITest( "inv use", "TechGoggles" );
			break;
		case 17:
			Item = Remote.FindInventoryType( class'TechGoggles' );
			Log( "RevNetTest: goggles used again: active=" $ (Item!=None && ChargedPickup(Item).IsActive()), 'RevNet' );
			Remote.ClientUITest( "view" );
			Remote.ClientUITest( "inv use", "Binoculars" );
			break;
		case 19:
			Item = Remote.FindInventoryType( class'Binoculars' );
			Log( "RevNetTest: binoculars used: in hand" @ Remote.inHand @ "active=" $ (Item!=None && Item.bActive) @ "state" @ Item.GetStateName(), 'RevNet' );
			Remote.ClientUITest( "view" );
			break;
		case 20:
			Item = Remote.FindInventoryType( class'Binoculars' );
			if ( Item!=None )
				Item.Activate(); // put away (as the player's next click)
			break;
		case 21:
			Remote.ClientUITest( "view" );
			Remote.ClientUITest( "inv drop", "Binoculars" );
			break;
		case 22:
			Log( "RevNetTest: inventory screen Drop binoculars: still carried=" $ (Remote.FindInventoryType( class'Binoculars' )!=None), 'RevNet' );
			Remote.ClientUITest( "inv belt", "MedKit" );
			break;
		case 23:
			Log( "RevNetTest: host's belt and grid record after the medkit went to belt slot 7, grid 4,5:" @ Belt(), 'RevNet' );
			Remote.ClientUITest( "belt" );
			Remote.ClientUITest( "close" );
			break;

		// The augmentations screen's bio-cell button
		case 24:
			Remote.Energy = 10;
			Remote.ClientUITest( "console", "ShowAugmentationsWindow" );
			break;
		case 25:
			Energy0 = Remote.Energy;
			Cells0 = Copies( class'BioelectricCell' );
			Remote.ClientUITest( "cell" );
			Remote.ClientUITest( "aug", "DeusEx.AugLight" );
			break;
		case 26:
			Log( "RevNetTest: aug screen bio-cell button: energy" @ int(Energy0) @ "->" @ int(Remote.Energy) @ "cells" @ Cells0 @ "->" @ Copies( class'BioelectricCell' ), 'RevNet' );
			Log( "RevNetTest: aug screen Activate light: host's copy active=" $ Remote.AugmentationSystem.FindAugmentation( class'AugLight' ).bIsActive, 'RevNet' );
			Remote.ClientUITest( "close" );
			break;

		// The skills screen's Upgrade
		case 27:
			Remote.SkillPointsAvail = 5000;
			Points0 = Host.SkillPointsAvail;
			Remote.ClientUITest( "console", "ShowSkillsWindow" );
			break;
		case 28:
			SkillLog( "before" );
			Remote.ClientUITest( "skill", "SkillLockpicking" );
			break;
		case 29:
			SkillLog( "after one upgrade" );
			Remote.ClientUITest( "skill", "SkillLockpicking" );
			break;
		case 30:
			SkillLog( "after two upgrades" );
			Remote.ClientUITest( "close" );
			break;

		// The health screen's heal button on the right arm
		case 31:
			Remote.HealthArmRight = 20;
			Remote.HealthLegLeft = 20;
			Remote.GenerateTotalHealth();
			Give( class'MedKit' );
			Remote.ClientUITest( "console", "ShowHealthWindow" );
			break;
		case 32:
			Limbs( "before" );
			Kits0 = Copies( class'MedKit' );
			Remote.ClientUITest( "heal", "2" );
			break;
		case 33:
			Limbs( "after healing the right arm (medkits" @ Kits0 @ "->" @ Copies( class'MedKit' ) $ ")" );
			Remote.ClientUITest( "close" );
			break;

		// The HUD
		case 34:
			Remote.ClientUITest( "hud" );
			HostCloak( true );
			break;
		case 36:
			Log( "RevNetTest: host cloaked: style" @ Host.Style @ "glow" @ Host.ScaleGlow, 'RevNet' );
			Remote.ClientUITest( "look" );
			HostCloak( false );
			break;
		case 37:
			Remote.ClientUITest( "look" );
			Remote.ClientUITest( "music" );
			Log( "RevNetTest: host's music: flag" @ Host.flagBase.GetName('MusicPackageTrack') @ "song" @ Host.Song @ "section" @ Host.SongSection @ "|" @ OggAmbient(), 'RevNet' );
			break;
		case 39:
			Remote.AugmentationSystem.FindAugmentation( class'AugLight' ).Deactivate();
			Remote.RestoreAllHealth();
			Done();
			break;
	}
}

function Give( class<Inventory> C )
{
	local Inventory Item;

	Item = Spawn( C,,, Remote.Location );
	Remote.FrobTarget = Item; // as the client's frob sets it
	if ( !Remote.HandleItemPickup( Item ) )
		Log( "RevNetTest: the client didn't take" @ C.Name, 'RevNet' );
}

function int Copies( class<Inventory> C )
{
	local Inventory Item;

	Item = Remote.FindInventoryType( C );
	if ( DeusExPickup(Item)!=None )
		return DeusExPickup(Item).NumCopies;
	return int(Item!=None);
}

// What the host has recorded of the client's belt (the items' own record).
function string Belt()
{
	local Inventory Item;
	local string S;

	for ( Item=Remote.Inventory; Item!=None; Item=Item.Inventory )
		S = S @ Item.Class.Name $ "@" $ Item.beltPos $ "/" $ Item.bInObjectBelt $ "(" $ Item.invPosX $ "," $ Item.invPosY $ ")";
	return S;
}

function string HostBelt()
{
	local int i;
	local string S;

	for ( i=0; i<10; i++ )
		if ( DeusExRootWindow(Host.rootWindow).hud.belt.GetObjectFromBelt( i )!=None )
			S = S @ i $ "=" $ DeusExRootWindow(Host.rootWindow).hud.belt.GetObjectFromBelt( i );
	return S;
}

function InHand( string When )
{
	Log( "RevNetTest: host: client's hand" @ When $ ":" @ Remote.inHand @ "pending" @ Remote.inHandPending, 'RevNet' );
}

function Limbs( string When )
{
	Log( "RevNetTest: host: client's health" @ When $ ": head" @ Remote.HealthHead @ "torso" @ Remote.HealthTorso @ "right arm" @ Remote.HealthArmRight
		@ "left arm" @ Remote.HealthArmLeft @ "right leg" @ Remote.HealthLegRight @ "left leg" @ Remote.HealthLegLeft @ "| health" @ Remote.Health, 'RevNet' );
}

function SkillLog( string When )
{
	local Skill S;

	S = Remote.SkillSystem.GetSkillFromClass( class'SkillLockpicking' );
	Log( "RevNetTest: host: client's lockpicking" @ When $ ": level" @ S.CurrentLevel @ "points" @ Remote.SkillPointsAvail @ "| host's points" @ Points0 @ "->" @ Host.SkillPointsAvail, 'RevNet' );
}

// As a medical bot installs one (CoopTestAugs.Give).
function Augmentation GiveAug( CoopPlayer P, class<Augmentation> C )
{
	local Augmentation A;
	local CoopGameInfo G;

	A = P.AugmentationSystem.FindAugmentation( C );
	if ( A!=None && A.bHasIt )
		return A;
	G = CoopGameInfo(Level.Game);
	G.BeginSinglePlayerRules();
	A = P.AugmentationSystem.GivePlayerAugmentation( C );
	G.EndSinglePlayerRules();
	return A;
}

// The host's cloak, for the client's view of it.
function HostCloak( bool bOn )
{
	local Augmentation A;

	A = GiveAug( Host, class'AugCloak' );
	if ( A==None )
		return;
	Host.Energy = Host.EnergyMax;
	if ( bOn )
		A.Activate();
	else
		A.Deactivate();
}

function string OggAmbient()
{
	local DXOggMusicManager M;

	foreach Host.GetEntryLevel().AllActors( class'DXOggMusicManager', M )
		return "ogg ambient" @ M.MusicInfo.AmbientOggFile @ "mode" @ M.musicMode;
	return "no ogg manager";
}
