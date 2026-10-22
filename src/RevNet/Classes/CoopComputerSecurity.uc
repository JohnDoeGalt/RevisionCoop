//=============================================================================
// CoopComputerSecurity.
//
// A security computer's terminal on a remote player's machine (see
// CoopComputerPersonal).
//=============================================================================
class CoopComputerSecurity extends NetworkTerminalSecurity;

function ShowScreen( Class<ComputerUIWindow> newScreen )
{
	Super.ShowScreen( class'CoopComputerPersonal'.static.CoopScreen( newScreen ) );
}
