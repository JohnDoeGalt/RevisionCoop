//=============================================================================
// CoopTestRush.
//
// ?CoopTest=Rush (backlog 6, docs/FLY_KITS.md "In flight": the Doppler rush): an unarmed kit flies at the client
// at the kits' middle speed; on the client's own machine its look plays the rush (CoopKitLook.Rush), pitched up as it
// comes on (closing speed and throttle: over 64).
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestRush extends CoopTest;

var CoopFPVGuided K;
var bool bReplied;

function Run( int t )
{
	local vector Dir;

	if ( t==3 )
	{
		Remote.ReducedDamageType = 'All';
		Dir = vector(Remote.Rotation);
		Dir.Z = 0;
		Dir = Normal( Dir );
		K = Spawn( class'CoopFPVGuided',,, Remote.Location + Dir * 2000 + vect(0,0,30), rotator(-Dir) );
		if ( K!=None )
		{
			K.Kind = 0;
			K.LaunchAt( Remote, -Dir, 0.01 );
			K.Speed = class'CoopFPV'.default.GearSpeed[1];
			K.MaxSpeed = K.Speed;
			K.Velocity = -Dir * K.Speed;
			Log( "RevNetTest: a kit at the client at" @ K.Speed @ "units a second from 2000 off", 'RevNet' );
		}
	}
	else if ( t==4 )
		Remote.ClientTest( "rush" );
	else if ( t==6 )
	{
		if ( !bReplied )
			Log( "RevNetTest: CHECK the client answered BAD", 'RevNet' );
		Done();
	}
}

function Reply( CoopPlayer From, string Text )
{
	local int i, Pitch;

	if ( Left( Text, 4 )!="rush" )
		return;
	bReplied = true;
	Log( "RevNetTest: client's looks:" $ Mid( Text, 4 ), 'RevNet' );
	i = InStr( Text, "FPVRush" );
	if ( i>=0 )
		Pitch = int( Mid( Text, i + 8 ) );
	if ( i>=0 && Pitch>64 )
		Log( "RevNetTest: CHECK the client hears the rush pitched up as the kit comes on (" $ Pitch $ ") ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK the client hears the rush pitched up as the kit comes on (" $ Pitch $ ") BAD", 'RevNet' );
}
