//=============================================================================
// CoopTestCapture.
//
// ?CoopTest=Capture (start on 04_NYC_Hotel): after Paul's talk (the host's
// TalkedToPaulAfterMessage_Played) both players go down: the team is captured
// (CoopStory.CaptureTeam), not sent back to the last save, and wakes in Mission 5's
// lab, each captured as the story has it.
//=============================================================================
class CoopTestCapture extends CoopTest;

var config int Stage; // 0 fresh, 1 captured, 2 done (in the test ini: a new map has a new test actor)

function Run( int t )
{
	local DeusExGoal Goal;

	if ( Stage==0 && t==3 )
	{
		Give( Host, class'WeaponPistol' );
		Give( Remote, class'WeaponPistol' );
		Remote.Credits = 700;
	}
	else if ( Stage==0 && t==5 )
	{
		Host.flagBase.SetBool( 'TalkedToPaulAfterMessage_Played', true,, 5 );
		SetStage( 1 );
		Log( "RevNetTest: before: host things" @ Things( Host ) @ "| client things" @ Things( Remote ) @ "credits" @ Remote.Credits, 'RevNet' );
		Remote.TakeDamage( 500, None, Remote.Location, vect(0,0,0), 'Shot' );
		Host.TakeDamage( 500, None, Host.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: both down on" @ Level.Outer.Name $ ": client downed=" $ Remote.bDowned @ "host downed=" $ Host.bDowned, 'RevNet' );
	}
	else if ( Stage==1 && t==8 && string(Level.Outer.Name)~="05_NYC_UNATCOMJ12Lab" )
	{
		SetStage( 2 );
		Goal = Host.FindGoal( 'EscapeToBatteryPark' );
		Log( "RevNetTest: after the capture, on" @ Level.Outer.Name $ ": MS_PlayerCaptured=" $ Host.flagBase.GetBool('MS_PlayerCaptured')
			@ "PaulDenton_Dead=" $ Host.flagBase.GetBool('PaulDenton_Dead') @ "M04_Hotel_Cleared=" $ Host.flagBase.GetBool('M04_Hotel_Cleared')
			@ "goal EscapeToBatteryPark completed=" $ (Goal!=None && Goal.bCompleted), 'RevNet' );
		Log( "RevNetTest: host health" @ Host.Health @ "things" @ Things( Host ) @ "credits" @ Host.Credits @ "downed=" $ Host.bDowned
			@ "| client health" @ Remote.Health @ "things" @ Things( Remote ) @ "credits" @ Remote.Credits @ "downed=" $ Remote.bDowned
			@ "captured=" $ Remote.flagBase.GetBool('RevNet_Captured'), 'RevNet' );
		Done();
	}
}

function Give( DeusExPlayer P, class<Inventory> C )
{
	local Inventory Item;

	Item = Spawn( C,,, P.Location );
	P.FrobTarget = Item;
	P.HandleItemPickup( Item );
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
