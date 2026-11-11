//=============================================================================
// CoopMapMemory.
//
// Maps keep their state, as in single-player. The engine would keep each map the
// team leaves (Save\Current) and load that copy on a revisit, but clients can't
// load it (CoopGameInfo deletes it), so a revisited or loaded map starts fresh.
// This puts back what changed: when the team leaves a map, and in every save, it
// notes against the fresh map the placed things gone (killed, taken, broken), the
// bodies with what they carry, things lying around, the things moved, spent
// triggers and the doors changed; on the next visit it does that again before
// anybody joins (CoopMapState: one per map).
//
// Lines, "|" separated:
//   G|<placed actor names, space separated>   gone
//   M|<name>|<location>|<rotation>             moved
//   T|<name>                                   a trigger that went off for good
//   D|<name>|<locked 0/1>|<key frame>|<destroyed 0/1>
//   B|<class>|<location>|<rotation>|<items>|<property=value;...>   a body
//   I|<class>|<location>|<rotation>|<count>    a thing lying around
//   K|<placed name or ->|<class>|<location>|<rotation>|<CoopNest.Remembered>   a kit nest: its kits, the player it's for
//=============================================================================
class CoopMapMemory extends CoopManager;

const MaxPlaced = 2048;

var Actor Placed[2048];        // the fresh map's things that can go or move
var name PlacedName[2048];
var vector PlacedAt[2048];
var rotator PlacedRot[2048];
var byte PlacedArmed[2048];    // a trigger that could still go off
var int NumPlaced;
var DeusExMover Door[256];
var byte DoorLocked[256], DoorKey[256];
var int NumDoors;
var Inventory PlacedItem[512]; // to tell things dropped later from placed ones
var int NumItems;

// What a body is, besides its class and place (by name: every gameplay mode's
// DeusExCarcass has them).
var string BodyProps[16];

function MapStarted()
{
	local CoopGameInfo G;
	local CoopMapState Index;
	local string Map;

	G = CoopGameInfo(Level.Game);
	Map = string(Level.Outer.Name);
	Index = class'CoopMapState'.static.Get( G.Mode, "", false );
	// A new mission: its maps are new, the last mission's are never seen again.
	if ( Index.Maps!="" && Left( Index.Maps, 3 )!=(" " $ Left( Map, 2 )) )
		Forget( G.Mode, false );
	NoteFreshMap();
	if ( Index.Has( Map ) )
	{
		G.BeginSinglePlayerRules();
		Apply( class'CoopMapState'.static.Get( G.Mode, Map, false ) );
		G.EndSinglePlayerRules();
	}
}

function Travelling()
{
	Capture();
}

// ----------------------------------------------------------------------
// The fresh map
// ----------------------------------------------------------------------

function NoteFreshMap()
{
	local Actor A;

	foreach AllActors( class'Actor', A )
	{
		if ( A.bStatic || A.bDeleteMe )
			continue;
		if ( DeusExMover(A)!=None && NumDoors<ArrayCount(Door) )
		{
			Door[NumDoors] = DeusExMover(A);
			DoorLocked[NumDoors] = byte(DeusExMover(A).bLocked);
			DoorKey[NumDoors] = DeusExMover(A).KeyNum;
			NumDoors++;
		}
		else if ( Tracked( A ) && NumPlaced<MaxPlaced )
		{
			Placed[NumPlaced] = A;
			PlacedName[NumPlaced] = A.Name;
			PlacedAt[NumPlaced] = A.Location;
			PlacedRot[NumPlaced] = A.Rotation;
			PlacedArmed[NumPlaced] = byte(Triggers(A)!=None && A.bCollideActors);
			NumPlaced++;
			if ( Inventory(A)!=None && NumItems<ArrayCount(PlacedItem) )
				PlacedItem[NumItems++] = Inventory(A);
		}
	}
}

function bool Tracked( Actor A )
{
	if ( ScriptedPawn(A)!=None || DeusExDecoration(A)!=None || DeusExCarcass(A)!=None
		|| ThrownProjectile(A)!=None || Triggers(A)!=None )
		return true;
	return Inventory(A)!=None && A.Owner==None;
}

// ----------------------------------------------------------------------
// Leaving (and saving): what changed
// ----------------------------------------------------------------------

function Capture()
{
	local CoopGameInfo G;
	local CoopMapState S, Index;
	local DeusExCarcass Body;
	local Inventory Item;
	local DeusExMover D;
	local Actor A;
	local CoopNest Nest;
	local string Gone;
	local int i;

	G = CoopGameInfo(Level.Game);
	S = class'CoopMapState'.static.Get( G.Mode, string(Level.Outer.Name), false );
	S.Clear();
	for ( i=0; i<NumPlaced; i++ )
	{
		A = Placed[i];
		// (Placed bodies come back as bodies, B lines: what they carry may have changed.)
		if ( A==None || A.bDeleteMe || DeusExCarcass(A)!=None || (Inventory(A)!=None && A.Owner!=None) || Dying( A ) )
		{
			if ( Dying( A ) )
				S.Add( DyingBodyLine( ScriptedPawn(A) ) );
			Gone = Gone @ PlacedName[i];
			if ( Len(Gone)>400 )
			{
				S.Add( "G|" $ Mid( Gone, 1 ) );
				Gone = "";
			}
		}
		else if ( (DeusExDecoration(A)!=None || Inventory(A)!=None) && (VSize(A.Location - PlacedAt[i])>4 || A.Rotation!=PlacedRot[i]) )
			S.Add( "M|" $ PlacedName[i] $ "|" $ A.Location $ "|" $ A.Rotation );
		else if ( PlacedArmed[i]!=0 && !A.bCollideActors )
			S.Add( "T|" $ PlacedName[i] );
	}
	if ( Gone!="" )
		S.Add( "G|" $ Mid( Gone, 1 ) );
	foreach AllActors( class'DeusExCarcass', Body )
		if ( !Body.bDeleteMe )
			S.Add( BodyLine( Body ) );
	foreach AllActors( class'Inventory', Item )
		if ( Item.Owner==None && !Item.bDeleteMe && !Item.bHidden && !IsPlacedItem( Item ) )
			S.Add( "I|" $ class'CoopSave'.static.ClassStr( Item.Class ) $ "|" $ Item.Location $ "|" $ Item.Rotation $ "|" $ Count( Item ) );
	foreach AllActors( class'CoopNest', Nest )
		if ( !Nest.bDeleteMe )
			S.Add( "K|" $ PlacedNameOf( Nest ) $ "|" $ class'CoopSave'.static.ClassStr( Nest.Class ) $ "|" $ Nest.Location $ "|"
				$ Nest.Rotation $ "|" $ Nest.Remembered() );
	for ( i=0; i<NumDoors; i++ )
	{
		D = Door[i];
		if ( D!=None && (D.bLocked!=bool(DoorLocked[i]) || D.KeyNum!=DoorKey[i] || D.bDestroyed) )
			S.Add( "D|" $ D.Name $ "|" $ int(D.bLocked) $ "|" $ D.KeyNum $ "|" $ int(D.bDestroyed) );
	}
	S.SaveConfig();
	Index = class'CoopMapState'.static.Get( G.Mode, "", false );
	Index.Remember( string(Level.Outer.Name) );
	Index.SaveConfig();
	Log( "RevNet: map memory of" @ Level.Outer.Name $ ":" @ S.NumLines @ "lines", 'RevNet' );
}

// A character killed a moment ago: not yet a body (its death plays out first).
function bool Dying( Actor A )
{
	return ScriptedPawn(A)!=None && !A.bDeleteMe && (Pawn(A).Health<=0 || A.IsInState('Dying'));
}

// The body it is about to leave, with what it carries (as DeusExCarcass.InitFor takes it).
function string DyingBodyLine( ScriptedPawn P )
{
	local Inventory Item;
	local string Items;

	if ( class<DeusExCarcass>(P.CarcassType)==None )
		return "";
	for ( Item=P.Inventory; Item!=None; Item=Item.Inventory )
		if ( Ammo(Item)==None )
			Items = Items $ class'CoopSave'.static.ClassStr( Item.Class ) $ ":" $ Count( Item ) $ ";";
	return "B|" $ class'CoopSave'.static.ClassStr( P.CarcassType ) $ "|" $ (P.Location - vect(0,0,1) * (P.CollisionHeight - 8))
		$ "|" $ P.Rotation $ "|" $ Items $ "|flagName=" $ P.BindName $ ";FamiliarName=" $ P.FamiliarName $ ";bEmitCarcass=True;";
}

function bool IsPlacedItem( Inventory Item )
{
	local int i;

	for ( i=0; i<NumItems; i++ )
		if ( PlacedItem[i]==Item )
			return true;
	return false;
}

// Ammo's rounds, a weapon's ammo, a pickup's copies.
static function int Count( Inventory Item )
{
	if ( Ammo(Item)!=None )
		return Ammo(Item).AmmoAmount;
	if ( DeusExWeapon(Item)!=None )
	{
		if ( DeusExWeapon(Item).AmmoType!=None && DeusExWeapon(Item).AmmoType.Owner==Item.Owner )
			return DeusExWeapon(Item).AmmoType.AmmoAmount;
		return DeusExWeapon(Item).PickupAmmoCount;
	}
	if ( DeusExPickup(Item)!=None )
		return DeusExPickup(Item).NumCopies;
	return 1;
}

function string BodyLine( DeusExCarcass Body )
{
	local Inventory Item;
	local string Items, Props, V;
	local int i;

	for ( Item=Body.Inventory; Item!=None; Item=Item.Inventory )
		if ( Ammo(Item)==None ) // a weapon's ammo comes with it
			Items = Items $ class'CoopSave'.static.ClassStr( Item.Class ) $ ":" $ Count( Item ) $ ";";
	// (A saved line stays short: the config writer overruns its buffer on a long one.)
	for ( i=0; i<ArrayCount(BodyProps) && BodyProps[i]!=""; i++ )
	{
		V = Body.GetPropertyText( BodyProps[i] );
		if ( InStr( V, "|" )<0 && InStr( V, ";" )<0 && Len(Items) + Len(Props) + Len(V) < 600 )
			Props = Props $ BodyProps[i] $ "=" $ V $ ";";
	}
	return "B|" $ class'CoopSave'.static.ClassStr( Body.Class ) $ "|" $ Body.Location $ "|" $ Body.Rotation $ "|" $ Items $ "|" $ Props;
}

// ----------------------------------------------------------------------
// Arriving: as it was left
// ----------------------------------------------------------------------

function Apply( CoopMapState S )
{
	local string L, Kind, Names, N;
	local Actor A;
	local DeusExMover D;
	local int i, Space;

	for ( i=0; i<S.NumLines; i++ )
	{
		L = S.Line[i];
		Kind = class'CoopSave'.static.Part( L, 0, "|" );
		if ( Kind=="G" )
		{
			Names = class'CoopSave'.static.Rest( L, 1, "|" ) $ " ";
			while ( Names!="" )
			{
				Space = InStr( Names, " " );
				N = Left( Names, Space );
				Names = Mid( Names, Space+1 );
				A = FindPlaced( N );
				if ( A!=None )
					A.Destroy();
			}
		}
		else if ( Kind=="M" )
		{
			A = FindPlaced( class'CoopSave'.static.Part( L, 1, "|" ) );
			if ( A!=None )
			{
				A.SetLocation( vector(class'CoopSave'.static.Part( L, 2, "|" )) );
				A.SetRotation( rotator(class'CoopSave'.static.Part( L, 3, "|" )) );
			}
		}
		else if ( Kind=="T" )
		{
			A = FindPlaced( class'CoopSave'.static.Part( L, 1, "|" ) );
			if ( A!=None )
				A.SetCollision( false );
		}
		else if ( Kind=="D" )
		{
			D = FindDoor( class'CoopSave'.static.Part( L, 1, "|" ) );
			if ( D!=None )
				SetDoor( D, class'CoopSave'.static.Part( L, 2, "|" )=="1", int(class'CoopSave'.static.Part( L, 3, "|" )), class'CoopSave'.static.Part( L, 4, "|" )=="1" );
		}
		else if ( Kind=="B" )
			SpawnBody( L );
		else if ( Kind=="I" )
			SpawnThing( L );
		else if ( Kind=="K" )
			RecallNest( L );
	}
	Log( "RevNet: map memory put back on" @ Level.Outer.Name $ ":" @ S.NumLines @ "lines", 'RevNet' );
}

// A's name in the fresh map, or "-" (spawned since).
function string PlacedNameOf( Actor A )
{
	local int i;

	for ( i=0; i<NumPlaced; i++ )
		if ( Placed[i]==A )
			return string(PlacedName[i]);
	return "-";
}

// A kit nest as it was left (a K line): a placed one found by its name, else spawned again; its kits, no more.
function RecallNest( string L )
{
	local CoopNest Nest;
	local class<CoopNest> C;

	Nest = CoopNest(FindPlaced( class'CoopSave'.static.Part( L, 1, "|" ) ));
	if ( Nest==None )
	{
		C = class<CoopNest>( class'CoopSave'.static.LoadClassStr( class'CoopSave'.static.Part( L, 2, "|" ) ) );
		if ( C==None )
			return;
		Nest = Spawn( C,,, vector(class'CoopSave'.static.Part( L, 3, "|" )), rotator(class'CoopSave'.static.Part( L, 4, "|" )) );
		if ( Nest==None )
			return;
	}
	Nest.Recall( class'CoopSave'.static.Rest( L, 5, "|" ) );
}

function Actor FindPlaced( string N )
{
	local int i;

	for ( i=0; i<NumPlaced; i++ )
		if ( Placed[i]!=None && string(PlacedName[i])==N )
			return Placed[i];
	return None;
}

function DeusExMover FindDoor( string N )
{
	local int i;

	for ( i=0; i<NumDoors; i++ )
		if ( Door[i]!=None && string(Door[i].Name)==N )
			return Door[i];
	return None;
}

// A door as it was left (BlowItUp's end state for a broken one, without the blast).
function SetDoor( DeusExMover D, bool bLocked, int Key, bool bDestroyed )
{
	D.bLocked = bLocked;
	if ( bDestroyed )
	{
		D.RemoteRole = ROLE_DumbProxy;
		D.SetLocation( D.Location + vect(0,0,20000) );
		D.SetCollision( false, false, false );
		D.bDestroyed = true;
	}
	else if ( Key!=D.KeyNum )
		D.InterpolateTo( Key, 0.01 );
}

function SpawnBody( string L )
{
	local class<DeusExCarcass> C;
	local DeusExCarcass Body;
	local Inventory Item, Next;
	local string Items, Entry, Props;
	local int i;

	C = class<DeusExCarcass>( class'CoopSave'.static.LoadClassStr( class'CoopSave'.static.Part( L, 1, "|" ) ) );
	if ( C==None )
		return;
	Body = Spawn( C,,, vector(class'CoopSave'.static.Part( L, 2, "|" )), rotator(class'CoopSave'.static.Part( L, 3, "|" )) );
	if ( Body==None )
		Body = Spawn( C,,, vector(class'CoopSave'.static.Part( L, 2, "|" )) + vect(0,0,16), rotator(class'CoopSave'.static.Part( L, 3, "|" )) );
	if ( Body==None )
		return;
	// Only what it carried: not the class's own starting things.
	for ( Item=Body.Inventory; Item!=None; Item=Next )
	{
		Next = Item.Inventory;
		Item.Destroy();
	}
	Body.Inventory = None;
	Items = class'CoopSave'.static.Part( L, 4, "|" );
	while ( Items!="" )
	{
		i = InStr( Items, ";" );
		if ( i<0 )
			break;
		Entry = Left( Items, i );
		Items = Mid( Items, i+1 );
		GiveBody( Body, class'CoopSave'.static.Part( Entry, 0, ":" ), int(class'CoopSave'.static.Part( Entry, 1, ":" )) );
	}
	Props = class'CoopSave'.static.Rest( L, 5, "|" );
	while ( Props!="" )
	{
		i = InStr( Props, ";" );
		if ( i<0 )
			break;
		Entry = Left( Props, i );
		Props = Mid( Props, i+1 );
		Body.SetPropertyText( class'CoopSave'.static.Part( Entry, 0, "=" ), class'CoopSave'.static.Rest( Entry, 1, "=" ) );
	}
}

// As DeusExCarcass.PostBeginPlay gives a body its things.
function GiveBody( DeusExCarcass Body, string ClassName, int N )
{
	local class<Inventory> C;
	local Inventory Item;
	local DeusExWeapon W;
	local class<Ammo> AmmoClass;

	C = class<Inventory>( class'CoopSave'.static.LoadClassStr( ClassName ) );
	if ( C==None )
		return;
	Item = Spawn( C, Body );
	if ( Item==None )
		return;
	Item.bHidden = true;
	Item.SetPhysics( PHYS_None );
	Body.AddInventory( Item );
	W = DeusExWeapon(Item);
	if ( W!=None )
	{
		W.PickupAmmoCount = N;
		if ( W.AmmoNames[0]!=None && W.AmmoNames[0]!=class'AmmoNone' )
			AmmoClass = W.AmmoNames[0];
		else if ( W.AmmoName!=None && W.AmmoName!=class'AmmoNone' )
			AmmoClass = W.AmmoName;
		if ( AmmoClass!=None )
		{
			W.AmmoType = Spawn( AmmoClass, Body );
			W.AmmoType.AmmoAmount = N;
			W.AmmoType.bHidden = true;
			W.AmmoType.SetPhysics( PHYS_None );
			Body.AddInventory( W.AmmoType );
		}
	}
	else if ( DeusExPickup(Item)!=None )
		DeusExPickup(Item).NumCopies = N;
}

function SpawnThing( string L )
{
	local class<Inventory> C;
	local Inventory Item;
	local int N;

	C = class<Inventory>( class'CoopSave'.static.LoadClassStr( class'CoopSave'.static.Part( L, 1, "|" ) ) );
	if ( C==None )
		return;
	Item = Spawn( C,,, vector(class'CoopSave'.static.Part( L, 2, "|" )), rotator(class'CoopSave'.static.Part( L, 3, "|" )) );
	if ( Item==None )
		return;
	N = int(class'CoopSave'.static.Part( L, 4, "|" ));
	if ( Ammo(Item)!=None )
		Ammo(Item).AmmoAmount = N;
	else if ( DeusExWeapon(Item)!=None )
		DeusExWeapon(Item).PickupAmmoCount = N;
	else if ( DeusExPickup(Item)!=None )
		DeusExPickup(Item).NumCopies = N;
}

// ----------------------------------------------------------------------
// The sets (static: CoopGameInfo calls them between maps)
// ----------------------------------------------------------------------

// Clears a set (the playing one, or the save's).
static function Forget( string Mode, bool bSaved )
{
	local CoopMapState Index, S;
	local string Maps, Map;
	local int i;

	Index = class'CoopMapState'.static.Get( Mode, "", bSaved );
	Maps = Mid( Index.Maps, 1 );
	while ( Maps!="" )
	{
		i = InStr( Maps, " " );
		if ( i<0 )
			break;
		Map = Left( Maps, i );
		Maps = Mid( Maps, i+1 );
		S = class'CoopMapState'.static.Get( Mode, Map, bSaved );
		S.Clear();
		S.SaveConfig();
	}
	Index.Maps = "";
	Index.SaveConfig();
}

// The playing set into the save (bToSave), or the save's back into play.
static function CopySet( string Mode, bool bToSave )
{
	local CoopMapState From, Into, Index;
	local string Maps, Map;
	local int i;

	Forget( Mode, bToSave );
	Index = class'CoopMapState'.static.Get( Mode, "", !bToSave );
	Maps = Mid( Index.Maps, 1 );
	while ( Maps!="" )
	{
		i = InStr( Maps, " " );
		if ( i<0 )
			break;
		Map = Left( Maps, i );
		Maps = Mid( Maps, i+1 );
		From = class'CoopMapState'.static.Get( Mode, Map, !bToSave );
		Into = class'CoopMapState'.static.Get( Mode, Map, bToSave );
		Into.CopyFrom( From );
		Into.SaveConfig();
	}
	Into = class'CoopMapState'.static.Get( Mode, "", bToSave );
	Into.Maps = Index.Maps;
	Into.SaveConfig();
}

defaultproperties
{
	BodyProps(0)="Mesh"
	BodyProps(1)="bNotDead"
	BodyProps(2)="bEmitCarcass"
	BodyProps(3)="KillerBindName"
	BodyProps(4)="KillerAlliance"
	BodyProps(5)="Alliance"
	BodyProps(6)="CumulativeDamage"
	BodyProps(7)="itemName"
	BodyProps(8)="FamiliarName"
	BodyProps(9)="realFamiliarName"
	BodyProps(10)="flagName"
	BodyProps(11)="wasFemale"
	BodyProps(12)="wasImportant"
	BodyProps(13)="Tag"
	BodyProps(14)="bBleedHead"
	BodyProps(15)="CarcassName"
}
