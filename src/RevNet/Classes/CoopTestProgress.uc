//=============================================================================
// CoopTestProgress.
//
// ?CoopTest=Progress: shared progress (CoopProgress). On 01 the host gets a note,
// a long note, a goal (then completed, then reset as at a mission's start), an image
// and skill points; the client reads a datacube, picks up a nanokey and a
// collectable and gets credits. Then the team travels to 02: the client's new pawn
// gets the full lists. Host side and client side of each player are logged.
//=============================================================================
class CoopTestProgress extends CoopTest;

function Run( int t )
{
	local DataVaultImage Image;
	local DeusExGoal Goal;
	local NanoKey Key;
	local DXCollectable C;
	local string S;

	if ( Level.Outer.Name!='01_NYC_UNATCOIsland' )
	{
		if ( t==10 )
		{
			Progress( "after travel", 'RevNetTestGoal2' );
			Done();
		}
		return;
	}
	switch ( t )
	{
		case 3:
			Progress( "joined", 'RevNetTestGoal' );
			Host.AddNote( "RevNet test note from the host", false, true );
			while ( Len(S)<2400 )
				S = S $ "A long note, as a datacube's. ";
			Host.AddNote( S, false, false );
			Goal = Host.AddGoal( 'RevNetTestGoal', false );
			Goal.SetText( "Test the shared goals" );
			Image = Spawn( class'Image01_LibertyIsland', Host );
			Image.GiveTo( Host );
			Image.SetBase( Host );
			Log( "RevNetTest: image added to the host:" @ Host.AddImage( Image ), 'RevNet' );
			Host.SkillPointsAdd( 50 );
			// As a datacube the client reads (InformationDevices).
			Remote.AddNote( "RevNet test note the client read", false, true ).SetTextTag( 'RevNetTestCube', "RevNet" );
			Remote.Credits += 123;
			break;
		case 4:
			Key = Spawn( class'NanoKey',,, Remote.Location );
			Key.KeyID = 'RevNetTestKey';
			Key.Description = "RevNet test key";
			Remote.FrobTarget = Key; // as the client's frob sets it
			Remote.ParseRightClick();
			Log( "RevNetTest: client picked up nanokey: gone=" $ (Key==None || Key.bDeleteMe), 'RevNet' );
			Host.bCollectablesMode = true;
			C = Spawn( class'DXCollectable',,, Remote.Location + vect(0,0,48) );
			if ( C!=None )
			{
				Remote.FrobTarget = C;
				Remote.DoFrob( Remote, None );
				Log( "RevNetTest: client found a collectable: gone=" $ (C==None || C.bDeleteMe) @ "host found=" $ Host.flagBase.GetInt('CollectablesFound') @ "client found=" $ Remote.flagBase.GetInt('CollectablesFound') @ "energy max" @ Host.EnergyMax @ Remote.EnergyMax, 'RevNet' );
			}
			else
				Log( "RevNetTest: no room for a collectable", 'RevNet' );
			break;
		case 6:
			Progress( "added", 'RevNetTestGoal' );
			Log( "RevNetTest: key on host's ring=" $ Host.KeyRing.HasKey('RevNetTestKey') @ "on client's (host side)=" $ Remote.KeyRing.HasKey('RevNetTestKey') @ "client's datacube note on the host:" @ (Host.GetNote('RevNetTestCube', "RevNet")!=None), 'RevNet' );
			Host.GoalCompleted( 'RevNetTestGoal' );
			break;
		case 8:
			Progress( "completed", 'RevNetTestGoal' );
			// A mission's start (MissionScript): completed primary goals and secondary ones go.
			Host.ResetGoals();
			// One for the next mission (a primary one stays).
			Goal = Host.AddGoal( 'RevNetTestGoal2', true );
			Goal.SetText( "A goal that travels" );
			break;
		case 10:
			Progress( "reset", 'RevNetTestGoal' );
			Level.Game.SendPlayer( Host, "02_NYC_BatteryPark" );
			break;
	}
}

function Progress( string When, name GoalName )
{
	Log( "RevNetTest: progress" @ When @ "host:" @ Host.ProgressSummary( GoalName, 'RevNetTestKey' ), 'RevNet' );
	Log( "RevNetTest: progress" @ When @ "client (host side):" @ Remote.ProgressSummary( GoalName, 'RevNetTestKey' ), 'RevNet' );
	Remote.ClientProgressReport( GoalName, 'RevNetTestKey' );
}
