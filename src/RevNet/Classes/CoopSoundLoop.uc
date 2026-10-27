//=============================================================================
// CoopSoundLoop.
//
// A looping sound on an actor, heard on every machine (its AmbientSound: the
// Arm Cannon's Storm BRRRT, CoopMechCannon.Storm). Made on the host, based on
// the actor it sounds from, kept going (Until) by whoever made it; past Until it
// plays its Tail there and is gone.
//=============================================================================
class CoopSoundLoop extends Actor;

var float Until;
var Sound Tail;

function Tick( float DeltaTime )
{
	if ( Role<ROLE_Authority || Until==0 )
		return;
	if ( Base==None || Base.bDeleteMe || Level.TimeSeconds>Until )
	{
		if ( Tail!=None && Base!=None && !Base.bDeleteMe )
			Base.PlaySound( Tail, SLOT_None, 2.0,, 2048 );
		Destroy();
	}
}

defaultproperties
{
	DrawType=DT_None
	bHidden=True
	RemoteRole=ROLE_SimulatedProxy
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	Physics=PHYS_None
	bTravel=False
	SoundRadius=96
	SoundVolume=255
}
