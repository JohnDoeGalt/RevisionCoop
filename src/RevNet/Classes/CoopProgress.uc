//=============================================================================
// CoopProgress.
//
// Host side of shared progress (CoopPlayerProgress): notes, goals, images,
// nanokeys and credits for every player.
//
// What a player gets (CoopPlayerProgress tells it here) is shared at the next
// tick, once the caller has finished with it (a note's tag and a goal's text are
// set after it's added) and outside single-player rules (where client calls would
// run here). It is read from the player who got it then: a goal it no longer has
// was deleted. Each player gets it on the host and on their client.
//
// The host's player is the team's progress (the story's: mission scripts give it
// theirs): a player who joins or arrives after travel gets what it has.
//=============================================================================
class CoopProgress extends CoopManager;

// What players got, to share.
var CoopPlayerProgress From[128];
var byte Kind[128];     // 0 note, 1 goal, 2 image, 3 key, 4 skill points
var Object What[128];   // the note, the image's class
var name Named[128];    // the goal, the key
var int Num[128];       // the note shown in the log, the skill points
var int Queued;
var bool bSharing;      // what players get from here is shared already

// ----------------------------------------------------------------------
// From the players (CoopPlayerProgress).
// ----------------------------------------------------------------------

function NoteAdded( CoopPlayerProgress P, DeusExNote Note, bool bShowInLog )
{
	Queue( P, 0, Note, '', int(bShowInLog) );
}

function GoalChanged( CoopPlayerProgress P, name GoalName )
{
	Queue( P, 1, None, GoalName, 0 );
}

function ImageAdded( CoopPlayerProgress P, class<DataVaultImage> ImageClass )
{
	Queue( P, 2, ImageClass, '', 0 );
}

function KeyAdded( CoopPlayerProgress P, name KeyID )
{
	Queue( P, 3, None, KeyID, 0 );
}

function PointsAdded( CoopPlayerProgress P, int Points )
{
	Queue( P, 4, None, '', Points );
}

function Queue( CoopPlayerProgress P, byte K, Object O, name N, int i )
{
	if ( bSharing )
		return;
	if ( Queued==ArrayCount(From) )
		Share();
	From[Queued] = P;
	Kind[Queued] = K;
	What[Queued] = O;
	Named[Queued] = N;
	Num[Queued] = i;
	Queued++;
}

// A player's new notes: AddNote puts them at the top of its list, above the one
// seen last (KnownNote). (Not an AddNote override: Revision's has a source
// parameter, Vanilla's not, and an override only fits the mode it was built
// against.) Single-player's are shown in the log, but for a typed one (the
// player's own) and the console's NoteAdd.
function FindNotes()
{
	local Pawn P;
	local CoopPlayerProgress Player;
	local DeusExNote Note;
	local int n, i;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		Player = CoopPlayerProgress(P);
		if ( Player==None || Player.Progress==None )
			continue;
		n = 0;
		for ( Note=Player.FirstNote; Note!=None && Note!=Player.KnownNote; Note=Note.next )
			n++;
		// Oldest first, as they came (the list is newest first).
		// ponytail: a walk per note; a handful a tick.
		for ( n=n-1; n>=0; n-- )
		{
			Note = Player.FirstNote;
			for ( i=0; i<n; i++ )
				Note = Note.next;
			if ( !Note.bUserNote )
				NoteAdded( Player, Note, true );
		}
		Player.KnownNote = Player.FirstNote;
	}
}

event Tick( float DeltaTime )
{
	local Pawn P;

	FindNotes();
	if ( Queued>0 )
		Share();
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( CoopPlayerProgress(P)!=None && NetConnection(PlayerPawn(P).Player)!=None )
			CoopPlayerProgress(P).SyncClient( DeltaTime );
}

// Before the players' things travel.
function Travelling()
{
	FindNotes();
	Share();
}

// ----------------------------------------------------------------------
// Sharing
// ----------------------------------------------------------------------

function Share()
{
	local int i;

	bSharing = true;
	for ( i=0; i<Queued; i++ )
		if ( From[i]!=None && !From[i].bDeleteMe )
			switch ( Kind[i] )
			{
				case 0: ShareNote( From[i], DeusExNote(What[i]), Num[i]!=0 ); break;
				case 1: ShareGoal( From[i], Named[i] ); break;
				case 2: ShareImage( From[i], class<DataVaultImage>(What[i]) ); break;
				case 3: ShareKey( From[i], Named[i] ); break;
				case 4: SharePoints( From[i], Num[i] ); break;
			}
	// (Not kept: a leaver's note goes with it, CoopGameInfo.PlayerGone.)
	for ( i=0; i<Queued; i++ )
		What[i] = None;
	Queued = 0;
	bSharing = false;
}

// A leaver's things are about to go (CoopGameInfo.PlayerGone): none of them waits here.
function PlayerGone( CoopPlayerProgress Leaver )
{
	local int i;

	for ( i=0; i<Queued; i++ )
		if ( From[i]==Leaver )
			What[i] = None;
}

// (textSource by name: Revision's notes have one, Vanilla's not.)
function ShareNote( CoopPlayerProgress From, DeusExNote Note, bool bShowInLog )
{
	local Pawn P;
	local CoopPlayerProgress To;
	local string Source;

	if ( Note==None )
		return;
	Source = Note.GetPropertyText( "textSource" );
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		if ( To!=From )
			To.PutNote( Note.text, false, Note.textTag, Note.TextPackage, Source, bShowInLog, true );
		if ( NetConnection(To.Player)==None )
			continue;
		if ( To!=From )
			To.ClientPutNote( To.SendLong( Note.text ), false, Note.textTag, Note.TextPackage, Source, bShowInLog, true );
		else
		{
			// Its AddNote on the host sent the message already, but has no screen
			// for the log sound.
			To.ClientPutNote( To.SendLong( Note.text ), false, Note.textTag, Note.TextPackage, Source, false, true );
			if ( bShowInLog )
				To.ClientTell( "", Sound'DeusExSounds.UserInterface.LogNoteAdded' );
		}
	}
}

function ShareGoal( CoopPlayerProgress From, name GoalName )
{
	local Pawn P;
	local CoopPlayerProgress To;
	local DeusExGoal Goal;

	Goal = From.FindGoal( GoalName );
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		if ( Goal==None )
		{
			if ( To!=From )
				To.RemoveGoal( GoalName );
			if ( NetConnection(To.Player)!=None )
				To.ClientRemoveGoal( GoalName );
		}
		else
		{
			if ( To!=From )
				To.PutGoal( GoalName, Goal.text, Goal.bPrimaryGoal, Goal.bCompleted, true );
			if ( NetConnection(To.Player)!=None )
				To.ClientPutGoal( GoalName, To.SendLong( Goal.text ), Goal.bPrimaryGoal, Goal.bCompleted, true );
		}
	}
}

function ShareImage( CoopPlayerProgress From, class<DataVaultImage> ImageClass )
{
	local Pawn P;
	local CoopPlayerProgress To;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		if ( To!=From )
		{
			To.PutImage( ImageClass, true );
			To.ClientTell( Sprintf( class'InformationDevices'.default.AddedToDatavaultLabel, ImageClass.default.imageDescription ) );
		}
		if ( NetConnection(To.Player)!=None )
			To.ClientPutImage( ImageClass, true );
	}
}

function ShareKey( CoopPlayerProgress From, name KeyID )
{
	local Pawn P;
	local CoopPlayerProgress To;
	local NanoKeyInfo Key;

	for ( Key=From.KeyList; Key!=None; Key=Key.NextKey )
		if ( Key.KeyID==KeyID )
			break;
	if ( Key==None )
		return;
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		if ( To!=From )
		{
			To.PutKey( KeyID, Key.Description );
			To.ClientTell( Sprintf( To.AddedNanoKey, Key.Description ) );
		}
		if ( NetConnection(To.Player)!=None )
			To.ClientPutKey( KeyID, Key.Description );
	}
}

// Each player gets what single-player gives its one player.
function SharePoints( CoopPlayerProgress From, int Points )
{
	local Pawn P;
	local CoopPlayerProgress To;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		if ( To!=From )
			To.SkillPointsAdd( Points );
		if ( NetConnection(To.Player)!=None )
			To.ClientTell( Sprintf( To.SkillPointsAward, Points ), Sound'DeusExSounds.UserInterface.LogSkillPoints' );
	}
}

// ----------------------------------------------------------------------
// A player joins (or arrives after travel): what the host's player has that it
// missed (the mission's start resets goals, a new player has nothing), then the
// full lists to its client, which starts with none.
// ----------------------------------------------------------------------

function PlayerJoined( CoopPlayer P )
{
	local CoopPlayerProgress Host;
	local DeusExGoal Goal, Next;
	local DeusExNote Note;
	local DataVaultImage Image;
	local NanoKeyInfo Key;

	P.Progress = Self;
	Host = CoopPlayerProgress(GetPlayerPawn());
	if ( Host!=None && Host!=P )
	{
		bSharing = true;
		for ( Goal=P.FirstGoal; Goal!=None; Goal=Next )
		{
			Next = Goal.next;
			if ( Host.FindGoal( Goal.goalName )==None )
				P.DeleteGoal( Goal );
		}
		for ( Goal=Host.FirstGoal; Goal!=None; Goal=Goal.next )
			P.PutGoal( Goal.goalName, Goal.text, Goal.bPrimaryGoal, Goal.bCompleted, false );
		for ( Note=Host.FirstNote; Note!=None; Note=Note.next )
			if ( !Note.bUserNote )
				P.PutNote( Note.text, false, Note.textTag, Note.TextPackage, Note.GetPropertyText("textSource"), false, false );
		for ( Image=Host.FirstImage; Image!=None; Image=Image.nextImage )
			P.PutImage( Image.Class, false );
		for ( Key=Host.KeyList; Key!=None; Key=Key.NextKey )
			P.PutKey( Key.KeyID, Key.Description );
		bSharing = false;
	}
	// What it brought (travel, the save) the others have had.
	P.KnownNote = P.FirstNote;
	if ( NetConnection(P.Player)!=None )
		P.StartSync();
}

// ----------------------------------------------------------------------
// Revision's collectables (DXCollectable.Frob) with a team: in collectables mode
// (the host's new game) one found counts for everyone, and each player gets the
// bonus single-player gives for the count (the skill points from the finder, who
// shares them). Single-player looks up the map's flag on the finder's screen (a
// remote player has none): the host's. False: not in that mode, DXCollectable's own.
// ----------------------------------------------------------------------

function bool Collectable( DXCollectable C, CoopPlayerProgress Finder )
{
	local CoopPlayerProgress Host, To;
	local Pawn P;
	local DeusExLevelInfo Info;
	local name MapFlag;
	local int n;

	Host = CoopPlayerProgress(GetPlayerPawn());
	if ( Host==None || !Host.bCollectablesMode || C.bUsed )
		return false;
	C.bUsed = true;
	n = Host.flagBase.GetInt( 'CollectablesFound' ) + 1;
	foreach AllActors( class'DeusExLevelInfo', Info )
		break;
	if ( Info!=None && DeusExRootWindow(Host.rootWindow)!=None )
		MapFlag = DeusExRootWindow(Host.rootWindow).StringToName( Caps(Info.mapName) $ "_CF" );
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		To = CoopPlayerProgress(P);
		if ( To==None )
			continue;
		To.flagBase.SetInt( 'CollectablesFound', n,, 100 );
		if ( MapFlag!='' )
			To.flagBase.SetBool( MapFlag, true,, 100 );
		To.ClientTell( Sprintf( C.CollectableAmountFound, n, "75" ) );
		switch ( (n - 1) % 3 )
		{
			case 0:
				if ( To.bCustomDifficulty )
					To.EnergyMax = To.CDEnergyMax + ((n + 2) / 3) * 2;
				else
					To.EnergyMax += 2;
				To.ClientTell( C.BonusEnergy, Sound'DeusExSounds.UserInterface.LogSkillPoints' );
				break;
			case 2:
				To.flagBase.SetInt( 'OverallReductionBonus', To.flagBase.GetInt( 'OverallReductionBonus' ) + 2,, 100 );
				To.ClientTell( C.BonusDamageReduction, Sound'DeusExSounds.UserInterface.LogSkillPoints' );
				break;
		}
	}
	if ( (n - 1) % 3==1 )
		Finder.SkillPointsAdd( C.SkillpointsAwarded );
	C.Destroy();
	return true;
}
