//=============================================================================
// CoopTravelAsk.
//
// The question to the player who walked into a way to another map (CoopExitGate):
// a yes/no box (DeusExRootWindow.MessageBox) whose answer goes to the host
// (CoopPlayerCore.ServerAnswerTravel). An invisible window: it only hears the box.
//=============================================================================
class CoopTravelAsk extends Window;

var localized string TitleText, AskText, LeadsText;

static function Ask( DeusExRootWindow Root, string Area )
{
	local CoopTravelAsk W;

	if ( Root==None )
		return;
	W = CoopTravelAsk(Root.NewChild( class'CoopTravelAsk' ));
	Root.MessageBox( default.TitleText, Fill( default.AskText, Area ), 0, false, W );
}

// The text with the area where it says %s.
static function string Fill( string Text, string Area )
{
	local int i;

	i = InStr( Text, "%s" );
	if ( i<0 )
		return Text;
	return Left( Text, i ) $ Area $ Mid( Text, i+2 );
}

event bool BoxOptionSelected( Window Box, int ButtonNumber )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(GetRootWindow());
	Root.PopWindow();
	if ( CoopPlayerCore(Root.parentPawn)!=None )
		CoopPlayerCore(Root.parentPawn).ServerAnswerTravel( ButtonNumber==0 ); // 0 yes, 1 no
	Destroy();
	return true;
}

defaultproperties
{
	TitleText="Leave this area?"
	AskText="You are about to go to %s. Everyone in your game comes with you. Go now?"
	LeadsText="is taking the team to"
}
