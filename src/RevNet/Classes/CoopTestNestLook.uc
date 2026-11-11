//=============================================================================
// CoopTestNestLook.
//
// ?CoopTest=NestLook (tools/shot_take.py, -Visible): CoopTestNests' steps, and between them a
// look at the nests as a player sees them (the user's rule: check what the player sees, not
// only the counts): the host stood before them, a lamp over its shoulder (PhotoStage), a shot.
//=============================================================================
class CoopTestNestLook extends CoopTestNests;

function Run( int t )
{
	local vector Mid;
	local rotator R, Facing;

	Super.Run( t );
	if ( t==6 && Perch!=None && Trellis!=None )
	{
		Mid = (Perch.Location + Trellis.Location) / 2;
		Facing.Yaw = Perch.Rotation.Yaw;
		Host.SetLocation( Mid + (vect(110,0,0) >> Facing) + vect(0,0,1) * (Host.CollisionHeight + 4) );
		R = rotator( Mid - (Host.Location + vect(0,0,1) * Host.BaseEyeHeight) );
		Host.SetRotation( R );
		Host.ViewRotation = R;
		Host.ClientSetRotation( R );
		PhotoStage();
	}
	if ( t==7 )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: nests: shot", 'RevNet' );
	}
}
