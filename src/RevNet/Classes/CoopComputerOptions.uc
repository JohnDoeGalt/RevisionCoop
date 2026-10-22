//=============================================================================
// CoopComputerOptions.
//
// A computer's special options on a remote player's machine: the host triggers
// the option's events (CoopPlayerDevices.ServerSpecialOption), here the screen
// only shows it.
//=============================================================================
class CoopComputerOptions extends ComputerScreenSpecialOptions;

function ActivateSpecialOption( MenuUIChoiceButton buttonPressed )
{
	local int i, Option;
	local Computers C;

	C = Computers(compOwner);
	if ( player.Role==ROLE_Authority || C==None || CoopPlayerDevices(player)==None )
	{
		Super.ActivateSpecialOption( buttonPressed );
		return;
	}
	for ( i=0; i<ArrayCount(optionButtons); i++ )
		if ( optionButtons[i].btnSpecial==buttonPressed )
			break;
	if ( i==ArrayCount(optionButtons) )
		return;
	Option = optionButtons[i].specialIndex;
	buttonPressed.SetSensitivity( False );
	if ( C.specialOptions[Option].bAlreadyTriggered )
		return;
	CoopPlayerDevices(player).ServerSpecialOption( C, Option );
	if ( C.specialOptions[Option].bTriggerOnceOnly )
		C.specialOptions[Option].bAlreadyTriggered = True;
	winSpecialInfo.SetText( C.specialOptions[Option].TriggerText );
}
