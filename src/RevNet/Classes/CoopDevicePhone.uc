//=============================================================================
// CoopDevicePhone.
//
// Dialling a phone (RevPhone with a number to dial, e.g. RevisionMission03's VoIP
// number) on a remote player's machine: the host triggers the number's event
// (CoopPlayerDevices.ServerDialed), here the window only answers.
//=============================================================================
class CoopDevicePhone extends RevHUDKeypadWindow;

function ValidateCode()
{
	if ( phoneOwner!=None && player.Role<ROLE_Authority && CoopPlayerDevices(player)!=None )
	{
		if ( inputCode==phoneOwner.validNumber && inputCode!="" )
			CoopPlayerDevices(player).ServerDialed( phoneOwner, inputCode );
		phoneOwner.DialEvent = 'CoopDialedOnHost'; // a tag nothing here has: the window answers as for a number with an event
	}
	Super.ValidateCode();
}
