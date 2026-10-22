//=============================================================================
// CoopComputerATM.
//
// An ATM's screen on a remote player's machine (CoopPlayerDevices.ClientOpenATM,
// see CoopComputerPersonal).
//=============================================================================
class CoopComputerATM extends ATMWindow;

function ShowScreen( Class<ComputerUIWindow> newScreen )
{
	Super.ShowScreen( class'CoopComputerPersonal'.static.CoopScreen( newScreen ) );
}
