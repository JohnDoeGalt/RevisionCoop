//=============================================================================
// CoopPlayerUI.
//
// A remote player's own screens, belt and HUD.
// One layer of the co-op player (CoopPlayerCore -> CoopPlayerProgress ->
// CoopPlayerDevices -> CoopPlayerTalk -> CoopPlayerUI -> CoopPlayer), each with
// its own replication block, so each can be worked on by itself.
//
// Its windows are on its own machine; the host runs its things:
// - the inventory screen's Use and the augmentations screen's bio-cell button
//   call the item's Activate, which isn't a call to the host (and a client's copy
//   of an item doesn't run it): CoopRootWindow's screens ask the host (ServerUseItem);
// - the health screen sets the body parts on the host, not the total (PopHealth);
// - tech goggles and binoculars, used on the host, set the HUD of the user's root
//   window there (a remote pawn's, never drawn): the client sets its own
//   (AddChargedDisplay, BinocularsView);
// - the map's music is set up on the host (the mission script's flag, the game's
//   ogg tracks): the client asks for it, and its own music code plays it.
//=============================================================================
class CoopPlayerUI extends CoopPlayerTalk;

var int MusicAsks;          // (client) times this map's music was asked for
var float NextMusicAsk;
var bool bBinocularsShown;  // (client) the binoculars' view is shown here

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientMusic, ClientUITest;
	reliable if ( Role<ROLE_Authority )
		ServerUseItem, ServerAskMusic, ServerUIReply;
}

// ----------------------------------------------------------------------
// Using an item from a screen (CoopScreenInventory, CoopScreenAugs).
// ----------------------------------------------------------------------

function ServerUseItem( Inventory Item )
{
	if ( Item!=None && Item.Owner==Self && !bDowned )
		UseItem( Item );
}

// The health screen's heal (a client's call): the total follows the parts here
// too (the screen updates it only on its own machine).
function PopHealth( float H0, float H1, float H2, float H3, float H4, float H5 )
{
	Super.PopHealth( H0, H1, H2, H3, H4, H5 );
	GenerateTotalHealth();
}

// ----------------------------------------------------------------------
// Tech goggles' vision (TechGoggles.UpdateHUDDisplay and ChargedPickupEnd, on
// the host, reach only the host's HUD): the wearer's machine sets it, as they do.
// The host calls these on the wearer's machine as the goggles go on and off.
// ----------------------------------------------------------------------

function AddChargedDisplay( ChargedPickup Item )
{
	Super.AddChargedDisplay( Item );
	if ( Level.NetMode==NM_Client && TechGoggles(Item)!=None )
		GogglesVision( TechGoggles(Item), true );
}

function RemoveChargedDisplay( ChargedPickup Item )
{
	Super.RemoveChargedDisplay( Item );
	if ( Level.NetMode==NM_Client && TechGoggles(Item)!=None )
		GogglesVision( TechGoggles(Item), false );
}

simulated function GogglesVision( TechGoggles G, bool bOn )
{
	local AugmentationDisplayWindow Win;
	local ENetRole OldRole;

	if ( DeusExRootWindow(rootWindow)==None || DeusExRootWindow(rootWindow).hud==None )
		return;
	Win = DeusExRootWindow(rootWindow).hud.augDisplay;
	if ( bOn )
	{
		// The mode's own code (they differ) on this copy, given authority for the
		// call (as CoopPlayerDevices.UseDevice); its active flag isn't sent here.
		OldRole = G.Role;
		G.Role = ROLE_Authority;
		G.bIsActive = true;
		G.UpdateHUDDisplay( Self );
		G.Role = OldRole;
	}
	else
	{
		// (ChargedPickupEnd's part for the HUD; the rest of it is the host's.)
		G.bIsActive = false;
		if ( --Win.activeCount<=0 )
		{
			Win.activeCount = 0;
			Win.bVisionActive = false;
			Win.visionBlinder = None;
		}
		else if ( AugmentationSystem!=None && AugmentationSystem.GetClassLevel( class'AugVision' )>=0 )
		{
			// The vision aug alone.
			Win.visionLevel = AugmentationSystem.GetClassLevel( class'AugVision' );
			Win.visionLevelValue = AugmentationSystem.GetAugLevelValue( class'AugVision' );
		}
	}
}

// ----------------------------------------------------------------------
// Binoculars' view (Binoculars.RefreshScopeDisplay, on the host): shown here
// while the ones in hand are active (bActive comes from the host).
// ----------------------------------------------------------------------

event PlayerInput( float DeltaTime )
{
	Super.PlayerInput( DeltaTime );
	if ( Level.NetMode==NM_Client )
		BinocularsView();
}

simulated function BinocularsView()
{
	local DeusExRootWindow Root;
	local bool bOn;

	Root = DeusExRootWindow(rootWindow);
	bOn = Binoculars(inHand)!=None && inHand.bActive;
	if ( Root==None || Root.scopeView==None || bOn==bBinocularsShown )
		return;
	bBinocularsShown = bOn;
	if ( bOn )
		Root.scopeView.ActivateView( 20, true, false );
	else
		Root.scopeView.DeactivateView();
}

// ----------------------------------------------------------------------
// Music: the host's map sets its music up for the host's player (the mission
// script's MusicPackageTrack flag, the game's ogg tracks in the Entry level's
// music manager); a client asks for the same (its player ticks only there) and
// its own UpdateDynamicMusic and ogg manager play it, with its own settings.
// ponytail: combat and conversation music need the characters' states, which a
// client doesn't have: the client stays on the ambient track.
// ----------------------------------------------------------------------

function UpdateDynamicMusic( float DeltaTime )
{
	if ( Level.NetMode==NM_Client && MusicAsks<6 && Level.TimeSeconds>=NextMusicAsk )
	{
		MusicAsks++; // (the host may not have set it up yet)
		NextMusicAsk = Level.TimeSeconds + 5;
		ServerAskMusic();
	}
	Super.UpdateDynamicMusic( DeltaTime );
}

function ServerAskMusic()
{
	local DXOggMusicManager M;
	local name Track;

	Track = DeusExPlayer(GetPlayerPawn()).flagBase.GetName( 'MusicPackageTrack' );
	if ( Track=='' || Track=='None' )
		return;
	foreach GetEntryLevel().AllActors( class'DXOggMusicManager', M )
		break;
	if ( M!=None )
		ClientMusic( string(Track), M.MusicInfo.AmbientIntroOggFile, M.MusicInfo.AmbientOggFile, M.MusicInfo.CombatIntroOggFile, M.MusicInfo.CombatOggFile,
			M.MusicInfo.ConversationIntroOggFile, M.MusicInfo.ConversationOggFile, M.MusicInfo.OutroOggFile, M.MusicInfo.DeathOggFile );
}

// A music file's or track's plain name (e.g. 01_UNATCOIsland_Ambient.ogg): letters, digits, _ . -,
// no folders, 64 at most.
static function bool MusicName( string S )
{
	local int i;

	if ( Len(S)>64 || InStr( S, ".." )>=0 )
		return false;
	for ( i=0; i<Len(S); i++ )
		if ( InStr( "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-", Mid( S, i, 1 ) )<0 )
			return false;
	return true;
}

simulated function ClientMusic( string Track, string AmbientIntro, string Ambient, string CombatIntro, string Combat,
	string ConIntro, string Con, string Outro, string Death )
{
	local DXOggMusicManager M;

	if ( DeusExRootWindow(rootWindow)==None || flagBase==None )
		return;
	// (File names from the host, to DXOgg's decoder: plain names only.)
	if ( !MusicName( AmbientIntro ) || !MusicName( Ambient ) || !MusicName( CombatIntro ) || !MusicName( Combat ) || !MusicName( ConIntro )
		|| !MusicName( Con ) || !MusicName( Outro ) || !MusicName( Death ) || !MusicName( Track ) )
		return;
	MusicAsks = 99;
	flagBase.SetName( 'MusicPackageTrack', DeusExRootWindow(rootWindow).StringToName( Track ) );
	foreach GetEntryLevel().AllActors( class'DXOggMusicManager', M )
		M.SetTracksManual( AmbientIntro, Ambient, CombatIntro, Combat, ConIntro, Con, Outro, Death );
	Log( "RevNet: this map's music:" @ Track @ Ambient, 'RevNet' );
	Super.UpdateDynamicMusic( 5 );
}

// ----------------------------------------------------------------------
// Test harness (CoopTestUI): the client drives its own screens, belt and keys
// as its player would, and tells the host what it shows.
// ----------------------------------------------------------------------

simulated function ClientUITest( string Command, optional string Arg )
{
	local DeusExRootWindow Root;
	local PersonaScreenInventory InvWin;
	local PersonaScreenSkills SkillWin;
	local PersonaScreenHealth HealthWin;
	local PersonaScreenAugmentations AugWin;
	local Inventory Item;
	local Window W;
	local DeusExPlayer P;
	local DXOggMusicManager M;
	local int i;
	local string S;

	Root = DeusExRootWindow(rootWindow);
	if ( Command=="belt" )
	{
		for ( i=0; i<10; i++ )
			if ( Root.hud.belt.GetObjectFromBelt( i )!=None )
				S = S @ i $ "=" $ Root.hud.belt.GetObjectFromBelt( i ).Class.Name;
		for ( Item=Inventory; Item!=None; Item=Item.Inventory )
			if ( Item.bInObjectBelt )
				S = S @ "|" @ Item.Class.Name $ "@" $ Item.beltPos;
		ServerUIReply( "belt:" $ S );
		S = "";
		for ( Item=Inventory; Item!=None; Item=Item.Inventory )
			S = S @ Item.Class.Name $ "(" $ Item.invPosX $ "," $ Item.invPosY $ ")";
		ServerUIReply( "grid:" $ S ); // (a call's string over ~400 characters is dropped)
	}
	else if ( Command=="key" )
	{
		// A belt key, as its binding does.
		S = string(Root.hud.belt.GetObjectFromBelt( int(Arg) ));
		ConsoleCommand( "ActivateBelt" @ int(Arg) );
		ServerUIReply( "pressed belt key" @ Arg @ "| the slot holds" @ S );
	}
	else if ( Command=="console" && (Arg=="ShowInventoryWindow" || Arg=="ShowSkillsWindow" || Arg=="ShowHealthWindow"
		|| Arg=="ShowAugmentationsWindow" || Arg=="NextBeltItem") )
	{
		// A key's command. Only these: any host can call this on a client, and a console
		// command can change (and save) the client's settings.
		ConsoleCommand( Arg );
		ServerUIReply( Arg @ "| top window" @ Root.GetTopWindow() @ "in hand" @ inHand @ "pending" @ inHandPending @ ClientInHandPending );
	}
	else if ( Command=="close" )
	{
		Root.ClearWindowStack();
		ServerUIReply( "closed, top" @ Root.GetTopWindow() );
	}
	else if ( Command=="page" )
	{
		// The heavy Mech's page button (CoopScreenMechInventory).
		if ( CoopScreenMechInventory(Root.GetTopWindow())==None )
		{
			ServerUIReply( "page | no Mech inventory screen:" @ Root.GetTopWindow() );
			return;
		}
		CoopScreenMechInventory(Root.GetTopWindow()).TurnPage();
		ServerUIReply( "page turned" );
	}
	else if ( Command=="shown" )
	{
		// The inventory screen's item buttons: those shown, and how many are hidden.
		InvWin = PersonaScreenInventory(Root.GetTopWindow());
		if ( InvWin==None )
		{
			ServerUIReply( "shown | no inventory screen:" @ Root.GetTopWindow() );
			return;
		}
		for ( W=InvWin.winItems.GetTopChild(); W!=None; W=W.GetLowerSibling() )
			if ( PersonaInventoryItemButton(W)!=None && Inventory(W.GetClientObject())!=None )
			{
				if ( W.IsVisible() )
					S = S @ Inventory(W.GetClientObject()).Class.Name;
				else
					i++;
			}
		ServerUIReply( "shown:" $ S @ "| hidden" @ i @ "| screen" @ InvWin.Class.Name );
	}
	else if ( Left( Command, 4 )=="inv " )
	{
		// The inventory screen's buttons on an item: inv use|drop|equip <class>.
		InvWin = PersonaScreenInventory(Root.GetTopWindow());
		Item = Carried( Arg );
		if ( InvWin==None || Item==None )
		{
			ServerUIReply( Command @ Arg @ "| no screen or item:" @ Root.GetTopWindow() @ Item );
			return;
		}
		InvWin.SelectInventoryItem( Item );
		if ( Command=="inv use" )
			InvWin.UseSelectedItem();
		else if ( Command=="inv drop" )
			InvWin.DropSelectedItem();
		else if ( Command=="inv equip" )
			InvWin.EquipSelectedItem();
		else if ( Command=="inv belt" )
		{
			InvWin.invBelt.AddObject( Item, 7 ); // dropped on belt slot 7
			InvWin.MoveItemButton( PersonaInventoryItemButton(InvWin.selectedItem), 4, 5 ); // and on the grid's last cell
		}
		ServerUIReply( Command @ Item @ "| screen" @ InvWin.Class.Name @ "selected" @ InvWin.selectedItem @ "health" @ Health @ "energy" @ int(Energy) );
	}
	else if ( Command=="cell" )
	{
		// The augmentations screen's bio-cell button.
		if ( PersonaScreenAugmentations(Root.GetTopWindow())!=None )
			PersonaScreenAugmentations(Root.GetTopWindow()).UseCell();
		ServerUIReply( "bio-cell button on" @ Root.GetTopWindow() @ "energy" @ int(Energy) );
	}
	else if ( Command=="aug" )
	{
		// The augmentations screen: select an aug, press Activate.
		AugWin = PersonaScreenAugmentations(Root.GetTopWindow());
		if ( AugWin!=None && AugmentationSystem!=None )
			AugWin.selectedAug = AugmentationSystem.FindAugmentation( class<Augmentation>(DynamicLoadObject( Arg, class'Class' )) );
		if ( AugWin==None || AugWin.selectedAug==None )
		{
			ServerUIReply( "no aug screen or aug" @ Arg @ Root.GetTopWindow() );
			return;
		}
		AugWin.ActivateAugmentation();
		ServerUIReply( "aug button" @ AugWin.selectedAug.Class.Name @ "| client active=" $ AugWin.selectedAug.bIsActive );
	}
	else if ( Command=="skill" )
	{
		// The skills screen: select a skill, press Upgrade.
		SkillWin = PersonaScreenSkills(Root.GetTopWindow());
		for ( i=0; SkillWin!=None && i<ArrayCount(SkillWin.skillButtons); i++ )
			if ( SkillWin.skillButtons[i]!=None && string(SkillWin.skillButtons[i].GetSkill().Class.Name)~=Arg )
			{
				SkillWin.SelectSkillButton( SkillWin.skillButtons[i] );
				S = "cost shown" @ SkillWin.selectedSkill.GetCost() @ "upgrade enabled=" $ SkillWin.btnUpgrade.IsSensitive();
				SkillWin.UpgradeSkill();
				ServerUIReply( "upgraded" @ Arg @ S @ "| client level" @ SkillWin.selectedSkill.CurrentLevel @ "points" @ SkillPointsAvail );
				return;
			}
		ServerUIReply( "no skills screen or skill" @ Arg @ Root.GetTopWindow() );
	}
	else if ( Command=="heal" )
	{
		// The health screen: a body part's heal button.
		HealthWin = PersonaScreenHealth(Root.GetTopWindow());
		if ( HealthWin==None )
		{
			ServerUIReply( "no health screen:" @ Root.GetTopWindow() );
			return;
		}
		HealthWin.ButtonActivated( HealthWin.regionWindows[int(Arg)].btnHeal );
		ServerUIReply( "healed part" @ Arg @ "on" @ HealthWin.Class.Name @ "| the screen shows" @ int(HealthWin.playerHealth[0]) @ int(HealthWin.playerHealth[1])
			@ int(HealthWin.playerHealth[2]) @ int(HealthWin.playerHealth[3]) @ int(HealthWin.playerHealth[4]) @ int(HealthWin.playerHealth[5]) );
	}
	else if ( Command=="hud" )
	{
		for ( W=Root.hud.hit.GetTopChild(); W!=None; W=W.GetLowerSibling() )
			i++;
		ServerUIReply( "hit display: children" @ i @ "energy bar=" $ (Root.hud.hit.winEnergy!=None) @ "breath bar=" $ (Root.hud.hit.winBreath!=None)
			@ "visible=" $ Root.hud.hit.IsVisible() @ "player=" $ (Root.hud.hit.player==Self) @ "| belt player=" $ (Root.hud.belt.player==Self)
			@ "| active items" @ Root.hud.activeItems.IsVisible() );
	}
	else if ( Command=="view" )
		ServerUIReply( "vision active=" $ Root.hud.augDisplay.bVisionActive @ "level" @ Root.hud.augDisplay.visionLevel @ "count" @ Root.hud.augDisplay.activeCount
			@ "| scope view shown=" $ Root.scopeView.bViewVisible @ "fov" @ int(DesiredFOV) @ "| in hand" @ inHand @ "active=" $ (inHand!=None && inHand.bActive) );
	else if ( Command=="look" )
	{
		// The other players as this machine draws them (a cloak's look).
		foreach AllActors( class'DeusExPlayer', P )
			if ( P!=Self )
				S = S @ P.PlayerReplicationInfo.PlayerName @ "style" @ P.Style @ "glow" @ P.ScaleGlow;
		ServerUIReply( "others look:" $ S );
	}
	else if ( Command=="music" )
	{
		foreach GetEntryLevel().AllActors( class'DXOggMusicManager', M )
			break;
		ServerUIReply( "music: ogg ambient" @ M.MusicInfo.AmbientOggFile @ "mode" @ M.musicMode @ "| flag" @ flagBase.GetName('MusicPackageTrack')
			@ "| song" @ Song @ "section" @ SongSection @ "| level info" @ GetLevelInfo() );
	}
}

// One of this player's things, by class name.
simulated function Inventory Carried( string ClassName )
{
	local Inventory Item;

	for ( Item=Inventory; Item!=None; Item=Item.Inventory )
		if ( string(Item.Class.Name)~=ClassName )
			return Item;
	return None;
}

function ServerUIReply( string Reply )
{
	if ( CoopGameInfo(Level.Game)==None || CoopGameInfo(Level.Game).Test==None )
		return;                                 // (only while a test runs)
	Log( "RevNetTest: reply from" @ PlayerReplicationInfo.PlayerName $ ":" @ Reply, 'RevNet' );
}
