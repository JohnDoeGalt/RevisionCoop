//=============================================================================
// CoopTestKit.
//
// Helpers for the world, device and character scenarios (CoopTestDoors,
// CoopTestNPC, CoopTestHazards): give the remote player things, face it at
// something so its own frob target is that (its machine sends it), spawn
// characters, have its machine do something (CoopTestProbe).
//=============================================================================
class CoopTestKit extends CoopTestDevices;

var CoopTestProbe Probe;

// Into the remote player's inventory (as a pickup does), optionally in hand.
function Inventory Give( class<Inventory> C, optional bool bHold )
{
	local Inventory Item;

	Item = Remote.FindInventoryType( C );
	if ( Item==None )
	{
		Item = Spawn( C,,, Remote.Location );
		Remote.FrobTarget = Item;
		Remote.HandleItemPickup( Item );
		Item = Remote.FindInventoryType( C );
	}
	if ( bHold && Item!=None )
		Remote.PutInHand( Item );
	return Item;
}

// Stands the remote player near A, looking at it: what its machine highlights is
// A, so the frob target it sends (checked while picking or hacking) is A.
function bool Face( Actor A, optional Pawn Who )
{
	local int i, j, k;
	local vector Spot, Eye, HitLocation, HitNormal;
	local rotator R, Dir;
	local float Reach;

	if ( Who==None )
		Who = Remote;
	if ( A==None )
		return false;
	Reach = DeusExPlayer(Who).MaxFrobDistance * 0.8;
	for ( k=0; k<4; k++ )
		for ( i=0; i<16; i++ )
		{
			Dir.Yaw = i * 4096;
			Spot = A.Location + vector(Dir) * (40 + k * 24);
			if ( Trace( HitLocation, HitNormal, Spot - vect(0,0,320), Spot, false )!=None )
				Spot = HitLocation + vect(0,0,1) * (Who.CollisionHeight + 2);
			if ( !Who.SetLocation( Spot ) )
				continue;
			Eye = Who.Location + vect(0,0,1) * Who.BaseEyeHeight;
			for ( j=0; j<81; j++ )
			{
				R = rotator(A.Location - Eye);
				R.Yaw += ((j % 9) - 4) * 1536;
				R.Pitch += ((j / 9) - 4) * 1024;
				if ( Trace( HitLocation, HitNormal, Eye + vector(R) * Reach, Eye, true )==A )
				{
					Who.SetRotation( R );
					PlayerPawn(Who).ViewRotation = R;
					PlayerPawn(Who).ClientSetLocation( Who.Location, R );
					Log( "RevNetTest:" @ Who.PlayerReplicationInfo.PlayerName @ "faces" @ A @ "from" @ int(VSize(HitLocation - Eye)) @ "units", 'RevNet' );
					return true;
				}
			}
		}
	Log( "RevNetTest:" @ Who.PlayerReplicationInfo.PlayerName @ "found no spot facing" @ A, 'RevNet' );
	return false;
}

// A character spawned now (after the map started), at a free spot near At.
function ScriptedPawn SpawnNPC( class<ScriptedPawn> C, vector At, optional rotator Facing )
{
	local ScriptedPawn SP;
	local int i;
	local rotator Dir;

	for ( i=0; i<16 && SP==None; i++ )
	{
		Dir.Yaw = i * 4096;
		SP = Spawn( C,,, At + vector(Dir) * (i / 4) * 40, Facing );
	}
	Log( "RevNetTest: spawned" @ SP @ "at" @ int(VSize(SP.Location - At)) @ "units from the spot", 'RevNet' );
	return SP;
}

function NPCLine( string Label, ScriptedPawn SP )
{
	if ( SP==None )
	{
		Log( "RevNetTest:" @ Label @ "(none)", 'RevNet' );
		return;
	}
	Log( "RevNetTest:" @ Label @ SP @ SP.Alliance @ "state" @ SP.GetStateName() @ "health" @ SP.Health @ "enemy" @ SP.Enemy @ "seeking" @ SP.SeekPawn
		@ "client" @ int(VSize(SP.Location - Remote.Location)) @ "host" @ int(VSize(SP.Location - Host.Location)) @ "dfp" @ int(SP.DistanceFromPlayer)
		@ "tickvis=" $ SP.bTickVisibleOnly @ "check" @ int(SP.playerCheckDistance) @ "sight" @ int(SP.SightRadius) @ "hearing" @ SP.HearingThreshold
		@ "visibility" @ SP.VisibilityThreshold @ "root" @ SP.playerDiffRoot, 'RevNet' );
}

function string Limbs( DeusExPlayer P )
{
	return "health" @ P.Health @ "head" @ P.HealthHead @ "torso" @ P.HealthTorso @ "arms" @ P.HealthArmLeft @ P.HealthArmRight @ "legs" @ P.HealthLegLeft @ P.HealthLegRight;
}

function ClientDo( string Command, optional Actor A )
{
	if ( Probe==None )
		Probe = Spawn( class'CoopTestProbe', Remote ); // (answers from the next call on)
	else
		Probe.ClientDo( Command, A );
}
