//=============================================================================
// CoopTestRevive.
//
// ?CoopTest=Revive (playtest 2026-11-15, docs/BACKLOG.md P9: "the light bugs out after being revived it seems, no
// augmentation in that slot"): the client switches its light on, goes down, the host revives it with a medkit; its
// light is still its own, on its key, and switches on again, on the host and on the client's own machine.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestRevive extends CoopTest;

var Augmentation Lamp;
var int KeyBefore;
var string ClientSays;

function Run( int t )
{
	if ( t==4 )
	{
		for ( Lamp=class'CoopRules'.static.FirstAug( Remote ); Lamp!=None; Lamp=Lamp.next )
			if ( Lamp.IsA('AugLight') )
				break;
		KeyBefore = Lamp.HotKeyNum;
		Log( "RevNetTest: before:" @ State(), 'RevNet' );
		Remote.AugmentationSystem.ActivateAugByKey( KeyBefore - 3 );
	}
	else if ( t==5 )
	{
		Verdict( "the light is on before (" $ State() $ ")", Lamp.bIsActive );
		Remote.ClientTest( "aug AugLight" );
		Host.ReducedDamageType = 'All';
		Remote.Died( None, 'Shot', Remote.Location );
	}
	else if ( t==7 )
	{
		Log( "RevNetTest: down" @ Remote.bDowned $ ":" @ State(), 'RevNet' );
		Remote.ClientTest( "aug AugLight" );
		GiveMedkit( Host );
		Host.SetLocation( Remote.Location + vect(60,0,10) );
		Host.FrobTarget = Remote;
		Host.ParseRightClick();
	}
	else if ( t==9 )
	{
		Verdict( "the client is up again", !Remote.bDowned );
		Verdict( "its light is still its own, on its key (" $ State() $ ")", Lamp!=None && !Lamp.bDeleteMe && Lamp.bHasIt && Lamp.HotKeyNum==KeyBefore && Lamp.Player==Remote );
		Remote.ClientTest( "aug AugLight" );
		Remote.AugmentationSystem.ActivateAugByKey( KeyBefore - 3 );
	}
	else if ( t==11 )
	{
		Verdict( "the light switches on after the revive (" $ State() $ ")", Lamp.bIsActive );
		Remote.ClientTest( "aug AugLight" );
	}
	else if ( t==13 )
	{
		Log( "RevNetTest: the client's own view of its light:" $ ClientSays, 'RevNet' );
		Done();
	}
}

function string State()
{
	if ( Lamp==None )
		return "no light";
	return "has" @ Lamp.bHasIt @ "key" @ Lamp.HotKeyNum @ "on" @ Lamp.bIsActive @ "level" @ Lamp.CurrentLevel @ "energy" @ int(Remote.Energy);
}

function Reply( CoopPlayer From, string Text )
{
	ClientSays = ClientSays @ "|" @ Text;
}

function Verdict( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}
