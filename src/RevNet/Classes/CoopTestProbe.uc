//=============================================================================
// CoopTestProbe.
//
// Test harness (CoopTestKit): the host's scenario has the remote player's own
// machine do something (ClientDo); the answer comes back as a "reply from" line
// (CoopPlayer.ServerTestReply). Owned by the remote player.
//=============================================================================
class CoopTestProbe extends Info;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientDo;
}

simulated function ClientDo( string Command, optional Actor A )
{
	local CoopPlayer Me;
	local Computers C;

	Me = CoopPlayer(Owner);
	if ( Me==None || Level.NetMode!=NM_Client )
		return;
	if ( Command=="hackdetect" )
	{
		// What the hack screen does when it catches the player (ComputerScreenHack).
		C = Computers(A);
		if ( C==None || C.termwindow==None )
		{
			Me.ServerTestReply( "no computer screen open for" @ A );
			return;
		}
		C.termwindow.HackDetected( false );
		Me.ServerTestReply( "hack detected on the client's screen: client copy locked out=" $ C.bLockedOut @ "health" @ Me.Health @ "energy" @ int(Me.Energy) );
	}
	else if ( Command=="body" )
		Me.ServerTestReply( "client body: state" @ Me.GetStateName() @ "zone water=" $ Me.Region.Zone.bWaterZone @ "head water=" $ Me.HeadRegion.Zone.bWaterZone
			@ "air" @ int(Me.swimTimer) $ "/" $ int(Me.swimDuration) @ "health" @ Me.Health @ "head" @ Me.HealthHead @ "torso" @ Me.HealthTorso
			@ "arms" @ Me.HealthArmLeft @ Me.HealthArmRight @ "legs" @ Me.HealthLegLeft @ Me.HealthLegRight @ "on fire=" $ Me.bOnFire
			@ "walk speed" @ Me.GroundSpeed @ "swim speed" @ Me.WaterSpeed @ "(class: deathmatch" @ Me.default.mpWaterSpeed @ "get" @ Me.ConsoleCommand( "get CoopPlayer mpWaterSpeed" ) @ "single-player" @ Me.default.WaterSpeed $ ") flamethrower burn" @ Me.ConsoleCommand( "get WeaponFlamethrower mpBurnTime" ) @ Me.ConsoleCommand( "get WeaponFlamethrower mpBurnDamage" ) );
	else if ( Command=="frob" )
		Me.ServerTestReply( "client frob target" @ Me.FrobTarget @ "in hand" @ Me.inHand );
}

defaultproperties
{
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
}
