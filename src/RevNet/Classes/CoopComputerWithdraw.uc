//=============================================================================
// CoopComputerWithdraw.
//
// An ATM withdrawal on a remote player's machine: the screen changes the copies
// there (the ATM's balance, the player's credits) and the host does the same
// (CoopPlayerDevices.ServerWithdraw).
//=============================================================================
class CoopComputerWithdraw extends ComputerScreenATMWithdraw;

function WithdrawCredits()
{
	local int Amount, Before, UserIndex;

	Amount = int(editWithdraw.GetText());
	Before = player.Credits;
	Super.WithdrawCredits();
	if ( player.Role<ROLE_Authority && CoopPlayerDevices(player)!=None && player.Credits!=Before )
	{
		UserIndex = winTerm.GetUserIndex();
		if ( winTerm.bHacked )
			UserIndex = -1;
		CoopPlayerDevices(player).ServerWithdraw( atmOwner, UserIndex, Amount, atmOwner.bSuckedDryByHack );
	}
}
