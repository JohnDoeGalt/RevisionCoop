//=============================================================================
// CoopSave.
//
// A co-op saved game, one per gameplay mode: section "[<Mode> CoopSave]" of
// RevNetSave.ini (the launcher's "continue" reads SavedMap there). The save
// format comes from HXFix's co-op save (cranebeaker's deus-ex-coop, MIT, see
// src/relay/LICENSE-hxcoop).
//
// A saved level can't be served to clients (they only have the map's own
// package, a saved one crashes them), so a save is a checkpoint: the host's
// flags, goals, notes, nanokeys and images, and every player's state by name.
// Loading opens the saved map fresh and puts them back (CoopGameInfo); mission
// scripts set the map up from the flags, as on any arrival.
//
// Ported from HXFix's HXFixSaveWorld and HXFixSavePlayers (deus-ex-coop,
// Copyright (c) 2026 cranebeaker and contributors, MIT License) to Revision's
// own classes.
//
// World lines are "|" separated, free text last:
//   Flag: <b/y/i/f/n/v/r>|<name>|<expiration>|<value>
//   Goal: <name>|<primary 0/1>|<completed 0/1>|<text>
//   Note: <tag>|<user note 0/1>|<text>
//   Key:  <id>|<description>
// Player lines are "<player>,<kind>,<fields>": C core stats, S skill, A aug,
// M ammo, P pickup, W weapon (with its mods), K class (a Mech's salvage). Text
// escapes \, CR and LF.
//=============================================================================
class CoopSave extends Object
	config(RevNetSave)
	perobjectconfig;

const MaxFlags = 2048;
const MaxGoals = 128;
const MaxNotes = 256;
const MaxKeys = 128;
const MaxImages = 64;
const MaxPlayers = 16;
const MaxLines = 1200;
const TextPart = 400;   // characters of text per saved line (escaped at most twice as long)

var config string SavedMap;      // empty: no saved game
var config int NumFlags;
var config string Flag[2048];
var config int NumGoals;
var config string Goal[128];
var config int NumNotes;
var config string NoteLine[256];
var config int NumKeys;
var config string Key[128];
var config string Image[64];
var config int NumPlayers;
var config string PlayerName[16];
var config int NumLines;
var config string Line[1200];
var config string CustomDifficulty; // the game's custom difficulty (CoopCustomDifficulty), "": none

// The save of a gameplay mode (CoopGameInfo.Mode).
static function CoopSave Get( string Mode )
{
	if ( Mode=="" )
		Mode = "Revision";
	return new(None, class'CoopRules'.static.NameOf(Mode)) class'CoopSave';
}

// ----------------------------------------------------------------------
// Text
// ----------------------------------------------------------------------

static function string Part( string S, int N, string Sep )
{
	local int i;

	while ( N-->0 )
	{
		i = InStr( S, Sep );
		if ( i<0 )
			return "";
		S = Mid( S, i+1 );
	}
	i = InStr( S, Sep );
	if ( i>=0 )
		return Left( S, i );
	return S;
}

// Everything after the first N separators.
static function string Rest( string S, int N, string Sep )
{
	local int i;

	while ( N-->0 )
	{
		i = InStr( S, Sep );
		if ( i<0 )
			return "";
		S = Mid( S, i+1 );
	}
	return S;
}

static function string Escape( string S )
{
	local string Out, C;
	local int i;

	for ( i=0; i<Len(S); i++ )
	{
		C = Mid( S, i, 1 );
		if ( C=="\\" )
			Out = Out $ "\\\\";
		else if ( C==Chr(13) )
			Out = Out $ "\\r";
		else if ( C==Chr(10) )
			Out = Out $ "\\n";
		else
			Out = Out $ C;
	}
	return Out;
}

static function string Unescape( string S )
{
	local string Out, C;
	local int i;

	for ( i=0; i<Len(S); i++ )
	{
		C = Mid( S, i, 1 );
		if ( C=="\\" && i+1<Len(S) )
		{
			i++;
			C = Mid( S, i, 1 );
			if ( C=="r" )
				C = Chr(13);
			else if ( C=="n" )
				C = Chr(10);
		}
		Out = Out $ C;
	}
	return Out;
}

static function string ClassStr( class<Object> C )
{
	if ( C==None )
		return "";
	return string(C.Outer.Name) $ "." $ string(C.Name);
}

static function class<Object> LoadClassStr( string S )
{
	if ( S=="" )
		return None;
	return class<Object>( DynamicLoadObject( S, class'Class', true ) );
}

// ----------------------------------------------------------------------
// World (the host's: the story is the host's)
// ----------------------------------------------------------------------

function AddFlag( string S )
{
	if ( NumFlags<MaxFlags )
		Flag[NumFlags++] = S;
	else
		Log( "RevNet: save flag table full, dropping" @ S, 'RevNet' );
}

function SaveWorld( DeusExPlayer Host )
{
	local FlagBase FB;
	local DeusExGoal G;
	local DeusExNote N;
	local NanoKeyInfo K;
	local DataVaultImage Img;
	local int It, i;
	local name FN;
	local vector V;
	local rotator R;
	local string T;

	FB = Host.flagBase;
	SavedMap = string(Host.Level.Outer.Name);
	CustomDifficulty = class'CoopCustomDifficulty'.static.Saved();

	for ( i=0; i<MaxFlags; i++ )
		Flag[i] = "";
	NumFlags = 0;
	It = FB.CreateIterator( FLAG_Bool );
	while ( FB.GetNextFlagName( It, FN ) )
		AddFlag( "b|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Bool ) $ "|" $ int(FB.GetBool( FN )) );
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Byte );
	while ( FB.GetNextFlagName( It, FN ) )
		AddFlag( "y|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Byte ) $ "|" $ FB.GetByte( FN ) );
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Int );
	while ( FB.GetNextFlagName( It, FN ) )
		AddFlag( "i|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Int ) $ "|" $ FB.GetInt( FN ) );
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Float );
	while ( FB.GetNextFlagName( It, FN ) )
		AddFlag( "f|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Float ) $ "|" $ FB.GetFloat( FN ) );
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Name );
	while ( FB.GetNextFlagName( It, FN ) )
		AddFlag( "n|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Name ) $ "|" $ FB.GetName( FN ) );
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Vector );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		V = FB.GetVector( FN );
		AddFlag( "v|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Vector ) $ "|" $ V.X $ "|" $ V.Y $ "|" $ V.Z );
	}
	FB.DestroyIterator( It );
	It = FB.CreateIterator( FLAG_Rotator );
	while ( FB.GetNextFlagName( It, FN ) )
	{
		R = FB.GetRotator( FN );
		AddFlag( "r|" $ FN $ "|" $ FB.GetExpiration( FN, FLAG_Rotator ) $ "|" $ R.Pitch $ "|" $ R.Yaw $ "|" $ R.Roll );
	}
	FB.DestroyIterator( It );

	// Lists newest first, as the player keeps them.
	for ( i=0; i<MaxGoals; i++ )
		Goal[i] = "";
	NumGoals = 0;
	for ( G=Host.FirstGoal; G!=None && NumGoals<MaxGoals; G=G.next )
		Goal[NumGoals++] = G.goalName $ "|" $ int(G.bPrimaryGoal) $ "|" $ int(G.bCompleted) $ "|" $ Escape( Left( G.text, TextPart ) );
	for ( i=0; i<MaxNotes; i++ )
		NoteLine[i] = "";
	NumNotes = 0;
	for ( N=Host.FirstNote; N!=None && NumNotes<MaxNotes; N=N.next )
	{
		// A long note (a datacube's) over several lines, "+|" the rest: the config writer
		// overruns its buffer on a long line and the game crashes (measured, 2400 characters).
		T = N.text;
		NoteLine[NumNotes++] = N.textTag $ "|" $ int(N.bUserNote) $ "|" $ Escape( Left( T, TextPart ) );
		T = Mid( T, TextPart );
		while ( T!="" && NumNotes<MaxNotes )
		{
			NoteLine[NumNotes++] = "+|" $ Escape( Left( T, TextPart ) );
			T = Mid( T, TextPart );
		}
	}
	for ( i=0; i<MaxKeys; i++ )
		Key[i] = "";
	NumKeys = 0;
	for ( K=Host.KeyList; K!=None && NumKeys<MaxKeys; K=K.NextKey )
		Key[NumKeys++] = K.KeyID $ "|" $ Escape( K.Description );
	for ( i=0; i<MaxImages; i++ )
		Image[i] = "";
	i = 0;
	for ( Img=Host.FirstImage; Img!=None && i<MaxImages; Img=Img.NextImage )
		Image[i++] = ClassStr( Img.Class );
}

// Before the mission script reads the flags (its first timer).
function LoadWorld( DeusExPlayer Host )
{
	local FlagBase FB;
	local DeusExGoal G, LastGoal;
	local DeusExNote N, LastNote;
	local DataVaultImage Img;
	local class<Object> C;
	local string S;
	local int i, Exp;
	local name FN;
	local vector V;
	local rotator R;

	FB = Host.flagBase;
	FB.DeleteAllFlags();
	for ( i=0; i<NumFlags; i++ )
	{
		S = Flag[i];
		FN = Host.rootWindow.StringToName( Part( S, 1, "|" ) );
		Exp = int( Part( S, 2, "|" ) );
		switch ( Part( S, 0, "|" ) )
		{
			case "b": FB.SetBool( FN, Part( S, 3, "|" )=="1", true, Exp ); break;
			case "y": FB.SetByte( FN, byte( Part( S, 3, "|" ) ), true, Exp ); break;
			case "i": FB.SetInt( FN, int( Part( S, 3, "|" ) ), true, Exp ); break;
			case "f": FB.SetFloat( FN, float( Part( S, 3, "|" ) ), true, Exp ); break;
			case "n": FB.SetName( FN, Host.rootWindow.StringToName( Part( S, 3, "|" ) ), true, Exp ); break;
			case "v":
				V.X = float( Part( S, 3, "|" ) );
				V.Y = float( Part( S, 4, "|" ) );
				V.Z = float( Part( S, 5, "|" ) );
				FB.SetVector( FN, V, true, Exp );
				break;
			case "r":
				R.Pitch = int( Part( S, 3, "|" ) );
				R.Yaw = int( Part( S, 4, "|" ) );
				R.Roll = int( Part( S, 5, "|" ) );
				FB.SetRotator( FN, R, true, Exp );
				break;
		}
	}

	// Stored newest first: appended in that order.
	Host.FirstGoal = None;
	for ( i=0; i<NumGoals; i++ )
	{
		S = Goal[i];
		G = new(Host) class'DeusExGoal';
		G.goalName = Host.rootWindow.StringToName( Part( S, 0, "|" ) );
		G.bPrimaryGoal = Part( S, 1, "|" )=="1";
		G.bCompleted = Part( S, 2, "|" )=="1";
		G.text = Unescape( Rest( S, 3, "|" ) );
		if ( LastGoal==None )
			Host.FirstGoal = G;
		else
			LastGoal.next = G;
		LastGoal = G;
	}
	Host.FirstNote = None;
	for ( i=0; i<NumNotes; i++ )
	{
		S = NoteLine[i];
		if ( Left( S, 2 )=="+|" )
		{
			if ( LastNote!=None )
				LastNote.text = LastNote.text $ Unescape( Mid( S, 2 ) );
			continue;
		}
		N = new(Host) class'DeusExNote';
		N.text = Unescape( Rest( S, 2, "|" ) );
		N.bUserNote = Part( S, 1, "|" )=="1";
		if ( Part( S, 0, "|" )!="" && Part( S, 0, "|" )!="None" )
			N.textTag = Host.rootWindow.StringToName( Part( S, 0, "|" ) );
		if ( LastNote==None )
			Host.FirstNote = N;
		else
			LastNote.next = N;
		LastNote = N;
	}
	// GiveKey and AddImage put new ones first: oldest first.
	if ( Host.KeyRing!=None )
	{
		Host.KeyList = None;
		for ( i=NumKeys-1; i>=0; i-- )
			Host.KeyRing.GiveKey( Host.rootWindow.StringToName( Part( Key[i], 0, "|" ) ), Unescape( Rest( Key[i], 1, "|" ) ) );
	}
	Host.FirstImage = None;
	for ( i=MaxImages-1; i>=0; i-- )
	{
		C = LoadClassStr( Image[i] );
		if ( class<DataVaultImage>(C)==None )
			continue;
		Img = Host.Spawn( class<DataVaultImage>(C), Host );
		if ( Img!=None )
		{
			// Carried, as a datacube gives it: not given, it lay at the host's feet in its
			// pickup state, a "cube" named Image01_LibertyIsland (playtest 2026-11-13).
			Img.GiveTo( Host );
			Img.SetBase( Host );
			Host.AddImage( Img );
		}
	}
	Log( "RevNet: loaded saved game on" @ SavedMap @ "-" @ NumFlags @ "flags," @ NumGoals @ "goals," @ NumNotes @ "notes," @ NumKeys @ "keys", 'RevNet' );
}

// ----------------------------------------------------------------------
// Players (by name)
// ----------------------------------------------------------------------

function AddLine( int P, string S )
{
	if ( NumLines<MaxLines )
		Line[NumLines++] = P $ "," $ S;
	else
		Log( "RevNet: save line table full, dropping" @ S, 'RevNet' );
}

function int FindPlayer( string Name )
{
	local int i;

	for ( i=0; i<NumPlayers; i++ )
		if ( PlayerName[i]~=Escape( Name ) )   // (kept escaped, as every text here)
			return i;
	return -1;
}

// Removes player P's record, renumbering the ones after it.
function DropPlayer( int P )
{
	local int i, n, Idx;
	local string S;

	for ( i=0; i<NumLines; i++ )
	{
		S = Line[i];
		Idx = int( Part( S, 0, "," ) );
		if ( Idx==P )
			continue;
		if ( Idx>P )
			S = (Idx - 1) $ Mid( S, InStr( S, "," ) );
		Line[n++] = S;
	}
	for ( i=n; i<NumLines; i++ )
		Line[i] = "";
	NumLines = n;
	for ( i=P; i<NumPlayers-1; i++ )
		PlayerName[i] = PlayerName[i+1];
	PlayerName[--NumPlayers] = "";
}

// Player From's record in Other, as this one's (one of the same name replaced).
function CopyPlayer( CoopSave Other, int From )
{
	local int i, Idx;

	for ( i=0; i<NumPlayers; i++ )
		if ( PlayerName[i]~=Other.PlayerName[From] )
		{
			DropPlayer( i );
			break;
		}
	if ( NumPlayers>=MaxPlayers )
		return;
	Idx = NumPlayers++;
	PlayerName[Idx] = Other.PlayerName[From];
	for ( i=0; i<Other.NumLines; i++ )
		if ( int( Part( Other.Line[i], 0, "," ) )==From )
			AddLine( Idx, Mid( Other.Line[i], InStr( Other.Line[i], "," ) + 1 ) );
}

// No player records (a new game: a player joining it starts fresh, not with what
// they had in the last one).
function ClearPlayers()
{
	while ( NumPlayers>0 )
		DropPlayer( NumPlayers-1 );
}

// Every player in the game now; records of players who are away stay.
function SavePlayers( LevelInfo L )
{
	local Pawn P;

	for ( P=L.PawnList; P!=None; P=P.NextPawn )
		if ( DeusExPlayer(P)!=None && !P.bDeleteMe && PlayerPawn(P).Player!=None && P.Health>0 )
			SavePlayer( DeusExPlayer(P) );
}

function SavePlayer( DeusExPlayer P )
{
	local int Idx, n;
	local Skill Sk;
	local Augmentation Aug;
	local Inventory Inv;
	local DeusExWeapon W;
	local string Name, Belt;

	Name = P.PlayerReplicationInfo.PlayerName;
	Idx = FindPlayer( Name );
	if ( Idx>=0 )
		DropPlayer( Idx );
	if ( NumPlayers>=MaxPlayers )
		return;
	Idx = NumPlayers++;
	PlayerName[Idx] = Escape( Name );

	AddLine( Idx, "C," $ P.Health $ "," $ P.HealthHead $ "," $ P.HealthTorso $ "," $ P.HealthLegLeft $ "," $ P.HealthLegRight
		$ "," $ P.HealthArmLeft $ "," $ P.HealthArmRight $ "," $ P.Energy $ "," $ P.EnergyMax $ "," $ P.Credits
		$ "," $ P.SkillPointsAvail $ "," $ P.SkillPointsTotal );
	if ( P.SkillSystem!=None )
		for ( Sk=P.SkillSystem.FirstSkill; Sk!=None && n<64; Sk=Sk.next )
		{
			n++;
			AddLine( Idx, "S," $ ClassStr( Sk.Class ) $ "," $ Sk.CurrentLevel );
		}
	n = 0;
	if ( P.AugmentationSystem!=None )
		for ( Aug=class'CoopRules'.static.FirstAug( P ); Aug!=None && n<256; Aug=Aug.next ) // (HR's list: ~150)
		{
			n++;
			if ( Aug.bHasIt )
				AddLine( Idx, "A," $ ClassStr( Aug.Class ) $ "," $ Aug.CurrentLevel $ "," $ Aug.HotKeyNum );
		}
	if ( CoopMechPlayer(P)!=None )
		AddLine( Idx, "K,Mech," $ CoopMechPlayer(P).Salvage ); // (its modules are A lines)
	n = 0;
	for ( Inv=P.Inventory; Inv!=None && n<512; Inv=Inv.Inventory )
	{
		n++;
		// Keys are the team's (world); images are the host's list.
		if ( Inv.bDeleteMe || Inv.IsA('NanoKeyRing') || Inv.IsA('NanoKey') || Inv.IsA('DataVaultImage') )
			continue;
		if ( Inv.bInObjectBelt )
			Belt = string(Inv.beltPos);
		else
			Belt = "-1";
		W = DeusExWeapon(Inv);
		if ( W!=None )
			AddLine( Idx, "W," $ ClassStr( W.Class ) $ "," $ Belt $ "," $ ClassStr( W.AmmoName ) $ "," $ W.ClipCount
				$ "," $ W.ReloadCount $ "," $ W.AccurateRange $ "," $ W.BaseAccuracy $ "," $ W.ReloadTime $ "," $ W.recoilStrength
				$ "," $ W.ModBaseAccuracy $ "," $ W.ModReloadCount $ "," $ W.ModAccurateRange $ "," $ W.ModReloadTime $ "," $ W.ModRecoilStrength
				$ "," $ int(W.bHasScope) $ "," $ int(W.bHasLaser) $ "," $ int(W.bHasSilencer) );
		else if ( Ammo(Inv)!=None )
			AddLine( Idx, "M," $ ClassStr( Inv.Class ) $ "," $ Belt $ "," $ Ammo(Inv).AmmoAmount );
		else if ( DeusExPickup(Inv)!=None )
			AddLine( Idx, "P," $ ClassStr( Inv.Class ) $ "," $ Belt $ "," $ DeusExPickup(Inv).NumCopies $ "," $ Inv.Charge );
		else
			Log( "RevNet: save skips item" @ Inv.Class, 'RevNet' );
	}
}

// Replaces a player's state with the record of their name; false without one.
function bool LoadPlayer( DeusExPlayer P )
{
	local int Idx, i, n, NumItems, Belts[64];
	local string S, Kind;
	local Inventory Items[64], Inv, Next;
	local Skill Sk;
	local Augmentation Aug;
	local class<Object> C;

	Idx = FindPlayer( P.PlayerReplicationInfo.PlayerName );
	if ( Idx<0 )
		return false;

	// What a new player starts with goes (the key ring stays: keys are the team's).
	P.SetInHandPending( None );
	P.SetInHand( None );
	P.ClearBelt();
	for ( Inv=P.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		if ( !Inv.IsA('NanoKeyRing') && !Inv.IsA('DataVaultImage') )
		{
			P.DeleteInventory( Inv );
			Inv.Destroy();
		}
	}
	if ( P.AugmentationSystem!=None )
		for ( Aug=class'CoopRules'.static.FirstAug( P ); Aug!=None && n<256; Aug=Aug.next )
		{
			n++;
			if ( Aug.bHasIt )
			{
				if ( Aug.bIsActive && !Aug.bAlwaysActive )
					Aug.Deactivate();
				Aug.bIsActive = false;
				Aug.bHasIt = false;
				Aug.bBoosted = false;
				Aug.HotKeyNum = 0;
				// (HR's own locations 7-10 lie past the AugLocs RevNet is built with: left. A
				// Mech's modules take no slot.)
				if ( CoopMechAug(Aug)==None && Aug.AugmentationLocation<ArrayCount(P.AugmentationSystem.AugLocs)
					&& P.AugmentationSystem.AugLocs[Aug.AugmentationLocation].AugCount>0 )
					P.AugmentationSystem.AugLocs[Aug.AugmentationLocation].AugCount--;
			}
			Aug.CurrentLevel = 0;
		}

	// A Mech's modules are there to be given their levels (HR makes them later).
	if ( CoopMechPlayer(P)!=None )
		CoopMechPlayer(P).EnsureModules();

	// Ammo before the weapons that load it.
	for ( i=0; i<NumLines; i++ )
	{
		S = Line[i];
		if ( int( Part( S, 0, "," ) )!=Idx )
			continue;
		Kind = Part( S, 1, "," );
		if ( Kind=="C" )
			LoadCore( P, S );
		else if ( Kind=="S" )
		{
			C = LoadClassStr( Part( S, 2, "," ) );
			Sk = None;
			if ( C!=None && P.SkillSystem!=None )
				Sk = P.SkillSystem.GetSkillFromClass( C );
			if ( Sk!=None )
				Sk.CurrentLevel = int( Part( S, 3, "," ) );
		}
		else if ( Kind=="A" )
		{
			C = LoadClassStr( Part( S, 2, "," ) );
			Aug = None;
			// A Mech's module: its own (the manager's install rules are the nano augs'; HR's
			// refuses it); a nano player's record has none to give.
			if ( class<CoopMechAug>(C)!=None )
			{
				Aug = class'CoopMechAug'.static.Find( P, class<CoopMechAug>(C) );
				if ( Aug!=None )
					Aug.bHasIt = true;
				else if ( CoopMechPlayer(P)!=None && CoopMechPlayer(P).ModIndex( class<CoopMechAug>(C) )>=0 )
				{
					// Not made yet (HR): when it is (EnsureModules).
					CoopMechPlayer(P).PendingLevels[CoopMechPlayer(P).ModIndex( class<CoopMechAug>(C) )] = int( Part( S, 3, "," ) ) + 1;
					CoopMechPlayer(P).PendingKeys[CoopMechPlayer(P).ModIndex( class<CoopMechAug>(C) )] = Max( 0, int( Part( S, 4, "," ) ) );
				}
			}
			else if ( class<Augmentation>(C)!=None && P.AugmentationSystem!=None )
				Aug = P.AugmentationSystem.GivePlayerAugmentation( class<Augmentation>(C) );
			if ( Aug!=None )
			{
				Aug.CurrentLevel = int( Part( S, 3, "," ) );
				Aug.HotKeyNum = int( Part( S, 4, "," ) );
			}
		}
		else if ( Kind=="K" && CoopMechPlayer(P)!=None )
			CoopMechPlayer(P).Salvage = int( Part( S, 3, "," ) );
		else if ( Kind=="M" && NumItems<64 )
		{
			Items[NumItems] = GiveAmmo( P, S );
			Belts[NumItems++] = int( Part( S, 3, "," ) );
		}
	}
	for ( i=0; i<NumLines; i++ )
	{
		S = Line[i];
		if ( int( Part( S, 0, "," ) )!=Idx )
			continue;
		Kind = Part( S, 1, "," );
		if ( NumItems>=64 )
			break;
		if ( Kind=="P" )
			Items[NumItems] = GivePickup( P, S );
		else if ( Kind=="W" )
			Items[NumItems] = GiveWeapon( P, S );
		else
			continue;
		Belts[NumItems++] = int( Part( S, 3, "," ) );
	}

	// The belt as it was (the host's HUD; a client's belt follows the items).
	for ( i=0; i<NumItems; i++ )
		if ( Items[i]!=None && !Items[i].bDeleteMe )
		{
			P.FindInventorySlot( Items[i] );
			if ( Belts[i]>=0 )
			{
				Items[i].bInObjectBelt = true;
				Items[i].beltPos = Belts[i];
				P.AddObjectToBelt( Items[i], Belts[i], true );
			}
		}
	// The first weapon put on the belt comes out of this with its belt slot holding it
	// but its own flags cleared (seen in CoopTestMech): the item says it isn't on the belt
	// (the client's belt shows nothing there, the next save drops it). The slot's word wins.
	for ( i=0; i<NumItems; i++ )
		if ( Items[i]!=None && !Items[i].bDeleteMe && Belts[i]>=0 && !Items[i].bInObjectBelt
			&& DeusExRootWindow(P.rootWindow)!=None && DeusExRootWindow(P.rootWindow).hud.belt.GetObjectFromBelt( Belts[i] )==Items[i] )
		{
			Items[i].bInObjectBelt = true;
			Items[i].beltPos = Belts[i];
			Log( "RevNet: restore put" @ Items[i].Class.Name @ "back on belt slot" @ Belts[i], 'RevNet' );
		}
	if ( CoopMechPlayer(P)!=None )
		CoopMechPlayer(P).GiveArsenal(); // (a record from a nano game has none)
	if ( P.AugmentationSystem!=None )
		P.AugmentationSystem.RefreshAugDisplay();
	Log( "RevNet: restored" @ P.PlayerReplicationInfo.PlayerName @ "from the saved game," @ NumItems @ "items", 'RevNet' );
	return true;
}

function LoadCore( DeusExPlayer P, string S )
{
	P.Health = int( Part( S, 2, "," ) );
	P.HealthHead = int( Part( S, 3, "," ) );
	P.HealthTorso = int( Part( S, 4, "," ) );
	P.HealthLegLeft = int( Part( S, 5, "," ) );
	P.HealthLegRight = int( Part( S, 6, "," ) );
	P.HealthArmLeft = int( Part( S, 7, "," ) );
	P.HealthArmRight = int( Part( S, 8, "," ) );
	P.Energy = float( Part( S, 9, "," ) );
	P.EnergyMax = float( Part( S, 10, "," ) );
	P.Credits = int( Part( S, 11, "," ) );
	P.SkillPointsAvail = int( Part( S, 12, "," ) );
	P.SkillPointsTotal = int( Part( S, 13, "," ) );
}

function Inventory GiveAmmo( DeusExPlayer P, string S )
{
	local class<Object> C;
	local Ammo A;

	C = LoadClassStr( Part( S, 2, "," ) );
	if ( class<Ammo>(C)==None )
		return None;
	A = Ammo( P.FindInventoryType( class<Ammo>(C) ) );
	if ( A==None )
	{
		A = P.Spawn( class<Ammo>(C), P );
		if ( A==None )
			return None;
		A.GiveTo( P );
	}
	A.AmmoAmount = int( Part( S, 4, "," ) );
	return A;
}

function Inventory GivePickup( DeusExPlayer P, string S )
{
	local class<Object> C;
	local Inventory Inv;

	C = LoadClassStr( Part( S, 2, "," ) );
	if ( class<DeusExPickup>(C)==None )
		return None;
	Inv = P.Spawn( class<Inventory>(C), P );
	if ( Inv==None )
		return None;
	DeusExPickup(Inv).NumCopies = int( Part( S, 4, "," ) );
	Inv.Charge = int( Part( S, 5, "," ) );
	Inv.bHeldItem = true;
	Inv.GiveTo( P );
	return Inv;
}

function Inventory GiveWeapon( DeusExPlayer P, string S )
{
	local class<Object> C;
	local DeusExWeapon W;

	C = LoadClassStr( Part( S, 2, "," ) );
	if ( class<DeusExWeapon>(C)==None )
		return None;
	if ( (C==class'CoopMechBlade' || C==class'CoopMechCannon') && CoopMechPlayer(P)==None )
		return None; // the Mech's body (a player who was one last time)
	W = P.Spawn( class<DeusExWeapon>(C), P );
	if ( W==None )
		return None;
	if ( Part( S, 4, "," )!="" )
		W.AmmoName = class<Ammo>( LoadClassStr( Part( S, 4, "," ) ) );
	W.ClipCount = int( Part( S, 5, "," ) );
	W.ReloadCount = int( Part( S, 6, "," ) );
	W.AccurateRange = int( Part( S, 7, "," ) );
	W.BaseAccuracy = float( Part( S, 8, "," ) );
	W.ReloadTime = float( Part( S, 9, "," ) );
	W.recoilStrength = float( Part( S, 10, "," ) );
	W.ModBaseAccuracy = float( Part( S, 11, "," ) );
	W.ModReloadCount = float( Part( S, 12, "," ) );
	W.ModAccurateRange = float( Part( S, 13, "," ) );
	W.ModReloadTime = float( Part( S, 14, "," ) );
	W.ModRecoilStrength = float( Part( S, 15, "," ) );
	W.bHasScope = Part( S, 16, "," )=="1";
	W.bHasLaser = Part( S, 17, "," )=="1";
	W.bHasSilencer = Part( S, 18, "," )=="1";
	// The ammo is in the inventory already: no pickup ammo on top.
	W.PickupAmmoCount = 0;
	W.AmmoType = None;
	if ( W.AmmoName!=None )
		W.AmmoType = Ammo( P.FindInventoryType( W.AmmoName ) );
	W.bHeldItem = true;
	W.Instigator = P;
	W.GiveTo( P );
	W.TravelPostAccept();
	return W;
}
