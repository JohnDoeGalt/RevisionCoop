//=============================================================================
// CoopComputerPersonal.
//
// A personal computer's terminal on a remote player's machine
// (CoopPlayerDevices.InvokeComputerScreen): its screens that change the world
// tell the host (CoopScreen).
//=============================================================================
class CoopComputerPersonal extends NetworkTerminalPersonal;

function ShowScreen( Class<ComputerUIWindow> newScreen )
{
	Super.ShowScreen( CoopScreen( newScreen ) );
}

static function Class<ComputerUIWindow> CoopScreen( Class<ComputerUIWindow> S )
{
	if ( S==class'ComputerScreenSpecialOptions' )
		return class'CoopComputerOptions';
	if ( S==class'ComputerScreenSecurity' )
		return class'CoopComputerCameras';
	if ( S==class'ComputerScreenATMWithdraw' )
		return class'CoopComputerWithdraw';
	return S;
}
