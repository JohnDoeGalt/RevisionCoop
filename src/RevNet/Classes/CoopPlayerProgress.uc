//=============================================================================
// CoopPlayerProgress.
//
// Shared progress: notes, goals, images, nanokeys and credits for every player.
// One layer of the co-op player (CoopPlayerCore -> CoopPlayerProgress ->
// CoopPlayerDevices -> CoopPlayerTalk -> CoopPlayer), each with its own
// replication block, so each can be worked on by itself.
//
// Single-player gives progress to one player (the host's in mission scripts, the
// reader, the one talking, the one who picked it up); the overrides here tell
// CoopProgress, which gives it to every player at its next tick (the caller sets a
// note's tag and a goal's text after adding it). Notes it finds itself (KnownNote):
// AddNote differs between modes. Every player has it on the host
// (it travels and saves with them) and on their client (the persona screens). Credits
// stay each player's own; the client is told its amount.
//=============================================================================
class CoopPlayerProgress extends CoopPlayerCore;

var CoopProgress Progress;  // host: shares what this player gets (set when it joins)
var DeusExNote KnownNote;   // host: this player's newest note CoopProgress has seen
var int CreditsSent;        // host: the credits this player's client was told
// Host: the full lists this player's client still has to get after joining (StartSync).
var NanoKeyInfo SyncKey;
var DataVaultImage SyncImage;
var DeusExGoal SyncGoal;
var DeusExNote SyncNote;
var float SyncBudget;       // bytes
var string PartText;        // client: the first parts of a long text (SendLong)

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientText, ClientPutNote, ClientPutGoal, ClientRemoveGoal, ClientPutImage, ClientPutKey,
		ClientCredits, ClientTell, ClientProgressReport;
}

// ----------------------------------------------------------------------
// What single-player code calls. A remote player's pawn on the host has no
// screen (the single-player versions use it for the log sound): its client shows
// the message and plays the sound when CoopProgress sends it.
// (Not AddNote: Revision's has a source parameter, Vanilla's not, and an override
// must match the one mode it was built against. CoopProgress.FindNotes.)
// ----------------------------------------------------------------------

function DeusExGoal AddGoal( name goalName, bool bPrimaryGoal )
{
	local DeusExGoal Goal;

	if ( rootWindow!=None )
		Goal = Super.AddGoal( goalName, bPrimaryGoal );
	else
	{
		Goal = FindGoal( goalName );
		if ( Goal==None )
		{
			Goal = InsertGoal( goalName, false );
			Goal.SetPrimaryGoal( bPrimaryGoal );
		}
	}
	if ( Progress!=None )
		Progress.GoalChanged( Self, goalName );
	return Goal;
}

exec function GoalCompleted( name goalName )
{
	if ( rootWindow!=None )
		Super.GoalCompleted( goalName );
	else if ( FindGoal( goalName )!=None )
		FindGoal( goalName ).SetCompleted();
	if ( Progress!=None )
		Progress.GoalChanged( Self, goalName );
}

// Also ResetGoals (a mission's start) and DeleteAllGoals.
function bool DeleteGoal( DeusExGoal goalToDelete )
{
	if ( !Super.DeleteGoal( goalToDelete ) )
		return false;
	if ( Progress!=None )
		Progress.GoalChanged( Self, goalToDelete.goalName );
	return true;
}

function bool AddImage( DataVaultImage newImage )
{
	local class<DataVaultImage> ImageClass;

	if ( newImage!=None )
		ImageClass = newImage.Class;
	if ( !Super.AddImage( newImage ) )
		return false;
	if ( Progress!=None )
		Progress.ImageAdded( Self, ImageClass );
	return true;
}

// (Deathmatch sends the key to the picker's client too, but not under single-player
// rules (searching a body): CoopProgress sends it.)
function PickupNanoKey( NanoKey newKey )
{
	Super.PickupNanoKey( newKey );
	if ( Progress!=None )
		Progress.KeyAdded( Self, newKey.KeyID );
}

function SkillPointsAdd( int numPoints )
{
	Super.SkillPointsAdd( numPoints );
	if ( Progress!=None && numPoints>0 )
		Progress.PointsAdded( Self, numPoints );
}

// Revision's collectables count for the team (CoopProgress.Collectable).
function DoFrob( Actor Frobber, Inventory frobWith )
{
	if ( Progress!=None && DXCollectable(FrobTarget)!=None && Progress.Collectable( DXCollectable(FrobTarget), Self ) )
		return;
	Super.DoFrob( Frobber, frobWith );
}

// ----------------------------------------------------------------------
// Progress another player made, on this player: on the host (CoopProgress) and on
// its client (the Client* calls). bLive: as it happens, newest first, with the
// message and sound where this player has a screen; else quietly at the end of the
// list (a full list arrives newest first).
// ----------------------------------------------------------------------

simulated function PutNote( string Text, bool bUser, name Tag, string Package, string Source, bool bShow, bool bLive )
{
	local DeusExNote Note;

	for ( Note=FirstNote; Note!=None; Note=Note.next )
		if ( Note.text==Text || (Tag!='' && Note.textTag==Tag && Note.TextPackage==Package) )
			return;
	if ( bLive )
	{
		// (A remote player's client shows it from its own ClientPutNote.)
		Note = AddNote( Text, bUser, bShow && rootWindow!=None );
		// Shared already: not a new one for CoopProgress (unless others came first).
		if ( KnownNote==Note.next )
			KnownNote = Note;
	}
	else
	{
		Note = new(Self) class'DeusExNote';
		Note.text = Text;
		Note.SetUserNote( bUser );
		if ( FirstNote==None )
			FirstNote = Note;
		else
			LastNote.next = Note;
		LastNote = Note;
	}
	// Revision's notes have a source (the notes screen sorts by it), Vanilla's not:
	// by name, which does nothing where there is none.
	if ( Source!="" )
		Note.SetPropertyText( "textSource", Source );
	Note.SetTextTag( Tag, Package );
}

simulated function PutGoal( name GoalName, string Text, bool bPrimary, bool bDone, bool bLive )
{
	local DeusExGoal Goal;

	Goal = FindGoal( GoalName );
	if ( Goal==None )
	{
		if ( bLive )
			Goal = AddGoal( GoalName, bPrimary );
		else
			Goal = InsertGoal( GoalName, true );
	}
	Goal.SetText( Text );
	Goal.SetPrimaryGoal( bPrimary );
	if ( bDone && !Goal.IsCompleted() )
	{
		if ( bLive )
			GoalCompleted( GoalName );
		else
			Goal.SetCompleted();
	}
}

// AddGoal's list handling, without its message (bLast: at the end).
simulated function DeusExGoal InsertGoal( name GoalName, bool bLast )
{
	local DeusExGoal Goal;

	Goal = new(Self) class'DeusExGoal';
	Goal.SetName( GoalName );
	if ( FirstGoal==None )
	{
		FirstGoal = Goal;
		LastGoal = Goal;
	}
	else if ( bLast )
	{
		LastGoal.next = Goal;
		LastGoal = Goal;
	}
	else
	{
		Goal.next = FirstGoal;
		FirstGoal = Goal;
	}
	return Goal;
}

simulated function RemoveGoal( name GoalName )
{
	if ( FindGoal( GoalName )!=None )
		DeleteGoal( FindGoal( GoalName ) );
}

simulated function PutImage( class<DataVaultImage> ImageClass, bool bLive )
{
	local DataVaultImage Image, Last;

	for ( Image=FirstImage; Image!=None; Image=Image.nextImage )
	{
		if ( Image.Class==ImageClass )
			return;
		Last = Image;
	}
	Image = Spawn( ImageClass, Self );
	if ( Image==None )
	{
		Log( "RevNet: no room for image" @ ImageClass, 'RevNet' );
		return;
	}
	if ( Level.NetMode==NM_Client )
	{
		// Only for the Images screen (the host's copy is the one that's carried).
		Image.BecomeItem();
		Image.SetPhysics( PHYS_None );
		Image.SetBase( Self );
	}
	else
	{
		// Carried, as a datacube gives it (it travels with the player).
		Image.GiveTo( Self );
		Image.SetBase( Self );
	}
	if ( bLive || Last==None )
		AddImage( Image );
	else
	{
		Last.nextImage = Image;
		Image.prevImage = Last;
	}
}

// NanoKeyRing.GiveKey, without needing the key ring here yet (a client gets it later).
simulated function PutKey( name KeyID, string Description )
{
	local NanoKeyInfo Key;

	for ( Key=KeyList; Key!=None; Key=Key.NextKey )
		if ( Key.KeyID==KeyID )
			return;
	Key = CreateNanoKeyInfo();
	Key.KeyID = KeyID;
	Key.Description = Description;
	Key.NextKey = KeyList;
	KeyList = Key;
}

// Host: a text for one of the Client* calls below. A call carries about 400 characters
// of strings (measured: longer ones never arrive, datacube notes are longer): the
// first parts of a longer one go ahead, the call carries the rest.
function string SendLong( string S )
{
	while ( Len(S)>300 )
	{
		ClientText( Left( S, 300 ) );
		S = Mid( S, 300 );
	}
	return S;
}

simulated function ClientText( string Part )
{
	PartText = PartText $ Part;
}

simulated function ClientPutNote( string Text, bool bUser, name Tag, string Package, string Source, bool bShow, bool bLive )
{
	PutNote( PartText $ Text, bUser, Tag, Package, Source, bShow, bLive );
	PartText = "";
}

simulated function ClientPutGoal( name GoalName, string Text, bool bPrimary, bool bDone, bool bLive )
{
	PutGoal( GoalName, PartText $ Text, bPrimary, bDone, bLive );
	PartText = "";
}

simulated function ClientRemoveGoal( name GoalName )
{
	RemoveGoal( GoalName );
}

simulated function ClientPutImage( class<DataVaultImage> ImageClass, bool bLive )
{
	PutImage( ImageClass, bLive );
}

simulated function ClientPutKey( name KeyID, string Description )
{
	PutKey( KeyID, Description );
}

simulated function ClientCredits( int Amount )
{
	Credits = Amount;
}

// A message in this player's log, with the log's sound (the host's player: right here).
simulated function ClientTell( string Msg, optional Sound LogSound )
{
	if ( Msg!="" )
		ClientMessage( Msg );
	if ( LogSound!=None && DeusExRootWindow(rootWindow)!=None && DeusExRootWindow(rootWindow).hud!=None && DeusExRootWindow(rootWindow).hud.msgLog!=None )
		DeusExRootWindow(rootWindow).hud.msgLog.PlayLogSound( LogSound );
}

// ----------------------------------------------------------------------
// Host, every tick (CoopProgress): this client's credits, and the rest of the
// full lists it gets after joining, at most SyncRate bytes a second (a burst
// would overflow the connection's reliable buffer and hold up the game's traffic).
// ponytail: a fixed rate (6000 of a 20000 net speed); measure the client's if
// slow links matter.
// ----------------------------------------------------------------------

function StartSync()
{
	SyncKey = KeyList;
	SyncImage = FirstImage;
	SyncGoal = FirstGoal;
	SyncNote = FirstNote;
}

function SyncClient( float DeltaTime )
{
	local float SyncRate;

	if ( Credits!=CreditsSent )
	{
		CreditsSent = Credits;
		ClientCredits( Credits );
	}
	SyncRate = 6000;
	SyncBudget = FMin( SyncBudget + DeltaTime * SyncRate, SyncRate );
	while ( SyncBudget>0 )
	{
		if ( SyncKey!=None )
		{
			ClientPutKey( SyncKey.KeyID, SyncKey.Description );
			SyncKey = SyncKey.NextKey;
		}
		else if ( SyncImage!=None )
		{
			ClientPutImage( SyncImage.Class, false );
			SyncImage = SyncImage.nextImage;
		}
		else if ( SyncGoal!=None )
		{
			ClientPutGoal( SyncGoal.goalName, SendLong( SyncGoal.text ), SyncGoal.bPrimaryGoal, SyncGoal.bCompleted, false );
			SyncBudget -= Len( SyncGoal.text );
			SyncGoal = SyncGoal.next;
		}
		else if ( SyncNote!=None )
		{
			if ( !SyncNote.bUserNote )
			{
				ClientPutNote( SendLong( SyncNote.text ), false, SyncNote.textTag, SyncNote.TextPackage, SyncNote.GetPropertyText("textSource"), false, false );
				SyncBudget -= Len( SyncNote.text );
			}
			SyncNote = SyncNote.next;
		}
		else
			break;
		SyncBudget -= 64;
	}
}

// ----------------------------------------------------------------------
// Tests (CoopTestProgress): what this player has, here and on its client.
// ----------------------------------------------------------------------

simulated function string ProgressSummary( name GoalName, name KeyID )
{
	local DeusExNote Note;
	local DeusExGoal Goal;
	local DataVaultImage Image;
	local NanoKeyInfo Key;
	local int Notes, Longest, Goals, Images, Keys;
	local string S;

	for ( Note=FirstNote; Note!=None; Note=Note.next )
	{
		Notes++;
		Longest = Max( Longest, Len( Note.text ) );
	}
	for ( Goal=FirstGoal; Goal!=None; Goal=Goal.next )
		Goals++;
	for ( Image=FirstImage; Image!=None; Image=Image.nextImage )
		Images++;
	for ( Key=KeyList; Key!=None; Key=Key.NextKey )
	{
		Keys++;
		if ( Key.KeyID==KeyID )
			S = " (" $ Key.Description $ ")";
	}
	S = "notes=" $ Notes @ "longest=" $ Longest @ "goals=" $ Goals @ "keys=" $ Keys $ S @ "images=" $ Images;
	if ( FirstNote!=None )
		S = S @ "newest note=[" $ Left( FirstNote.text, 40 ) $ "]" @ FirstNote.textTag;
	if ( FirstImage!=None )
		S = S @ "newest image=" $ FirstImage.Class.Name;
	Goal = FindGoal( GoalName );
	if ( Goal!=None )
		S = S @ GoalName $ "=[" $ Goal.text $ "] done=" $ Goal.bCompleted;
	else
		S = S @ GoalName $ "=none";
	return S @ "credits=" $ Credits @ "skill points=" $ SkillPointsAvail $ "/" $ SkillPointsTotal;
}

simulated function ClientProgressReport( name GoalName, name KeyID )
{
	Log( "RevNetTest: client progress (netmode" @ Level.NetMode $ "):" @ ProgressSummary( GoalName, KeyID ), 'RevNet' );
}

defaultproperties
{
	CreditsSent=-1
}
