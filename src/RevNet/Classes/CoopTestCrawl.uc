//=============================================================================
// CoopTestCrawl.
//
// ?CoopTest=Crawl: the whole campaign, map by map, with a client. On each map the
// client arrives, has up to two of the conversations it can start there (the first
// answer each time), and the team moves on to the next map of the list (by the
// host, as a story travel). Logged per map: the client there or not, the characters
// with something to say, the conversations had. The place in the list comes from
// the map the team is on (a map's own story may send the team on by itself).
//=============================================================================
class CoopTestCrawl extends CoopTest;

var string Maps[80];
var int Here, Talks, Step, StepAt, ArriveBy;
var ScriptedPawn Partner;
var string Talked;

function Start( string S )
{
	Super.Start( S );
	Here = Find( string(Level.Outer.Name) );
	ArriveBy = 90; // the client must be here this many seconds into the map
}

function Timer()
{
	Super.Timer();
	if ( Remote==None && Seconds==ArriveBy )
	{
		Log( "RevNetTest: crawl" @ Level.Outer.Name @ "- the client didn't arrive in" @ ArriveBy @ "s", 'RevNet' );
		MoveOn();
	}
}

function Run( int t )
{
	if ( t==4 )
	{
		Log( "RevNetTest: crawl" @ Level.Outer.Name @ "(" $ (Here+1) $ "/" $ Count() $ ") client here; talkers:" @ Talkers(), 'RevNet' );
		Remote.ClientTest( "mem" ); // (levels still loaded, object memory: a leak shows here)
		Remote.ClientTest( "refs" ); // (a map left still loaded: what holds it)
	}
	else if ( Step==0 && t>=6 )
	{
		if ( Talks>=2 || !TalkToSomeone( t ) )
		{
			Log( "RevNetTest: crawl" @ Level.Outer.Name @ "done: talked to" @ Talked @ "| client health" @ Remote.Health @ "| goals" @ GoalCount( Host ) $ "/" $ GoalCount( Remote ), 'RevNet' );
			MoveOn();
			Step = 9;
		}
	}
	else if ( Step==1 )
		Drive( t );
}

function MoveOn()
{
	if ( Here<0 || Here+1>=Count() )
	{
		Log( "RevNetTest: crawl finished on" @ Level.Outer.Name, 'RevNet' );
		Done();
		return;
	}
	Log( "RevNetTest: crawl" @ Level.Outer.Name @ "->" @ Maps[Here+1], 'RevNet' );
	Level.Game.SendPlayer( Host, Maps[Here+1] );
}

// The nearest character with a conversation the client can start, not yet had.
function bool TalkToSomeone( int t )
{
	local ScriptedPawn SP, Best;
	local Conversation Con;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.conListItems!=None && SP.Health>0 && !SP.IsInState('Dying') && InStr( Talked, "[" $ SP.Name $ "]" )<0
			&& Remote.GetActiveConversation( SP, IM_Frob )!=None
			&& (Best==None || VSize(SP.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = SP;
	if ( Best==None )
		return false;
	Partner = Best;
	Talked = Talked $ "[" $ Best.Name $ "]";
	Talks++;
	if ( !PutRemote( Best.Location, Best.Rotation, 48 + Best.CollisionRadius ) )
		PutRemote( Best.Location, Best.Rotation + rot(0,32768,0), 48 + Best.CollisionRadius );
	Con = Remote.GetActiveConversation( Best, IM_Frob );
	if ( Con==None )
		return true;
	Remote.FrobTarget = Best;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: crawl" @ Level.Outer.Name @ "- client talks to" @ Best.BindName @ "about" @ Con.conName, 'RevNet' );
	Step = 1;
	StepAt = t;
	return true;
}

function Drive( int t )
{
	local ConPlay CP;

	CP = Remote.conPlay;
	if ( CP==None || t>StepAt+30 )
	{
		if ( CP!=None )
			Remote.AbortConversation();
		Step = 0;
		return;
	}
	if ( CP.IsInState('WaitForInput') && ConEventChoice(CP.currentEvent)!=None )
		Remote.ClientTalkTest( "choose" );
	else if ( CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText') )
		Remote.ClientTalkTest( "continue" );
}

function string Talkers()
{
	local ScriptedPawn SP;
	local string S;
	local int n;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.conListItems!=None && SP.Health>0 && Remote.GetActiveConversation( SP, IM_Frob )!=None && n++<8 )
			S = S @ SP.BindName;
	return S;
}

function int GoalCount( DeusExPlayer P )
{
	local DeusExGoal G;
	local int n;

	for ( G=P.FirstGoal; G!=None; G=G.next )
		n++;
	return n;
}

function int Find( string Map )
{
	local int i;

	for ( i=0; i<ArrayCount(Maps) && Maps[i]!=""; i++ )
		if ( Maps[i]~=Map )
			return i;
	return -1;
}

function int Count()
{
	local int i;

	while ( i<ArrayCount(Maps) && Maps[i]!="" )
		i++;
	return i;
}

defaultproperties
{
	Maps(0)="01_NYC_UNATCOIsland"
	Maps(1)="01_NYC_UNATCOHQ"
	Maps(2)="02_NYC_BatteryPark"
	Maps(3)="02_NYC_Street"
	Maps(4)="02_NYC_Warehouse"
	Maps(5)="02_NYC_Hotel"
	Maps(6)="02_NYC_Bar"
	Maps(7)="02_NYC_FreeClinic"
	Maps(8)="02_NYC_Smug"
	Maps(9)="02_NYC_Underground"
	Maps(10)="03_NYC_UNATCOIsland"
	Maps(11)="03_NYC_UNATCOHQ"
	Maps(12)="03_NYC_BatteryPark"
	Maps(13)="03_NYC_BrooklynBridgeStation"
	Maps(14)="03_NYC_MolePeople"
	Maps(15)="03_NYC_AirfieldHeliBase"
	Maps(16)="03_NYC_Airfield"
	Maps(17)="03_NYC_Hangar"
	Maps(18)="03_NYC_747"
	Maps(19)="04_NYC_UNATCOIsland"
	Maps(20)="04_NYC_UNATCOHQ"
	Maps(21)="04_NYC_BatteryPark"
	Maps(22)="04_NYC_Street"
	Maps(23)="04_NYC_Hotel"
	Maps(24)="04_NYC_Bar"
	Maps(25)="04_NYC_Smug"
	Maps(26)="04_NYC_Underground"
	Maps(27)="04_NYC_NSFHQ"
	Maps(28)="05_NYC_UNATCOMJ12lab"
	Maps(29)="05_NYC_UNATCOHQ"
	Maps(30)="05_NYC_UNATCOIsland"
	Maps(31)="06_HongKong_Helibase"
	Maps(32)="06_HongKong_WanChai_Market"
	Maps(33)="06_HongKong_WanChai_Street"
	Maps(34)="06_HongKong_WanChai_Canal"
	Maps(35)="06_HongKong_WanChai_Underworld"
	Maps(36)="06_HongKong_WanChai_Garage"
	Maps(37)="06_HongKong_WanChai_Compound"
	Maps(38)="06_HongKong_TongBase"
	Maps(39)="06_HongKong_VersaLife"
	Maps(40)="06_HongKong_MJ12lab"
	Maps(41)="06_HongKong_Storage"
	Maps(42)="08_NYC_Street"
	Maps(43)="08_NYC_Hotel"
	Maps(44)="08_NYC_Bar"
	Maps(45)="08_NYC_FreeClinic"
	Maps(46)="08_NYC_Smug"
	Maps(47)="08_NYC_Underground"
	Maps(48)="09_NYC_Dockyard"
	Maps(49)="09_NYC_Ship"
	Maps(50)="09_NYC_ShipBelow"
	Maps(51)="09_NYC_ShipFan"
	Maps(52)="09_NYC_Graveyard"
	Maps(53)="10_Paris_Catacombs"
	Maps(54)="10_Paris_Catacombs_Tunnels"
	Maps(55)="10_Paris_Entrance"
	Maps(56)="10_Paris_Club"
	Maps(57)="10_Paris_Metro"
	Maps(58)="10_Paris_Catacombs_Metro"
	Maps(59)="10_Paris_Chateau"
	Maps(60)="11_Paris_Underground"
	Maps(61)="11_Paris_Everett"
	Maps(62)="11_Paris_Cathedral"
	Maps(63)="12_Vandenberg_Cmd"
	Maps(64)="12_Vandenberg_Tunnels"
	Maps(65)="12_Vandenberg_Computer"
	Maps(66)="12_Vandenberg_Gas"
	Maps(67)="14_Vandenberg_Sub"
	Maps(68)="14_OceanLab_Lab"
	Maps(69)="14_Oceanlab_UC"
	Maps(70)="14_Oceanlab_Silo"
	Maps(71)="15_Area51_Bunker"
	Maps(72)="15_Area51_Entrance"
	Maps(73)="15_Area51_Final"
	Maps(74)="15_Area51_Page"
}
