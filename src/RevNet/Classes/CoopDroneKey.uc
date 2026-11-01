//=============================================================================
// CoopDroneKey.
//
// The FPV Drones key just pressed, on the Mech player's own machine (CoopMechPlayer
// .ActivateAugmentation): let go within Hold seconds, a tap (the module as its level
// says: CoopMechPlayer.DroneTapped); still down, a drone flown by hand (DroneHeld).
// The key's binding holds bExtra3 down with it (Install-RevNet.ps1: "| Button
// bExtra3"); bound without it, a press is a tap.
//=============================================================================
class CoopDroneKey extends Info;

var float Hold, Pressed;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	Pressed = Level.TimeSeconds;
}

function Tick( float DeltaTime )
{
	local CoopMechPlayer P;

	P = CoopMechPlayer(Owner);
	if ( P!=None )
	{
		if ( P.bExtra3==0 )
			P.DroneTapped();
		else if ( Level.TimeSeconds - Pressed>=Hold )
			P.DroneHeld();
		else
			return;
	}
	Destroy();
}

defaultproperties
{
	Hold=0.35
	RemoteRole=ROLE_None
}
