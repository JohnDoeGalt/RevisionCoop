//=============================================================================
// CoopComputerCameras.
//
// A security computer's cameras, turrets and doors on a remote player's machine:
// door buttons go to the host (CoopPlayerDevices.ServerDoor); cameras and turrets
// already do (DeusExPlayer's camera and turret calls).
// ponytail: the camera and turret choices are the deathmatch ones (ComputerScreenSecurity
// picks them by NetMode); single-player ones would mean replacing their choice windows.
//=============================================================================
class CoopComputerCameras extends ComputerScreenSecurity;

function ToggleDoorLock()
{
	if ( !DoorOnHost( False ) )
		Super.ToggleDoorLock();
}

function TriggerDoor()
{
	if ( !DoorOnHost( True ) )
		Super.TriggerDoor();
}

function bool DoorOnHost( bool bOpen )
{
	if ( player.Role==ROLE_Authority || CoopPlayerDevices(player)==None )
		return false;
	if ( selectedCamera!=None && selectedCamera.door!=None )
	{
		CoopPlayerDevices(player).ServerDoor( ComputerSecurity(compOwner), selectedCamera.door.Tag, bOpen );
		selectedCamera.UpdateDoorStatus();
	}
	return true;
}
