//=============================================================================
// CoopPlayerDevices.
//
// Devices for remote players: computers, ATMs, datacubes and books, medical bots,
// keypad codes, aug installation and slots.
// One layer of the co-op player (CoopPlayerCore -> CoopPlayerProgress ->
// CoopPlayerDevices -> CoopPlayerTalk -> CoopPlayer), each with its own
// replication block, so each can be worked on by itself.
//
// A device's screen opens on the user's own machine, on its copy of the device.
// That copy has class defaults (the host sends what the screen needs first) and,
// as a replicated actor, doesn't run its own functions: it does while its screen
// is open (UseDevice gives it authority here). What the screen changes in the
// world goes to the host (Server* calls, single-player rules where they differ).
// Medical bots use single-player screens for every player, the host too
// (deathmatch heals at once and never installs augs).
//=============================================================================
class CoopPlayerDevices extends CoopPlayerProgress;

var Actor OpenDevice;           // the device copy whose screen is open here (UseDevice)
var ENetRole OpenDeviceRole;
var Window MedScreen;           // the medical bot screen open here
var bool bLocalFromClient, bLocalFromListen;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientComputer, ClientComputerUser, ClientComputerOption, ClientATMUser, ClientOpenATM,
		ClientReadDevice, ClientKeypadWindow, ClientAugDisplay, ClientOpenPhone, ClientOpenMedBot, ClientMedBotTime, ClientDeviceTest;
	reliable if ( Role<ROLE_Authority )
		ServerSpecialOption, ServerDoor, ServerWithdraw, ServerDialed, ServerMedBotHeal, ServerInstallAug;
}

// ----------------------------------------------------------------------
// Host: frobbing a device
// ----------------------------------------------------------------------

function DoFrob( Actor Frobber, Inventory frobWith )
{
	local Actor T;
	local bool bRemote;

	T = FrobTarget;
	bRemote = NetConnection(Player)!=None;
	if ( CoopGameInfo(Level.Game)==None || T==None )
	{
		Super.DoFrob( Frobber, frobWith );
		return;
	}
	if ( MedicalBot(T)!=None )
	{
		ClientOpenMedBot( MedicalBot(T), MedicalBot(T).GetRefreshTimeRemaining(), MedicalBot(T).healRefreshTime, MedicalBot(T).healAmount );
		return;
	}
	if ( bRemote && InformationDevices(T)!=None )
	{
		ReadDevice( InformationDevices(T) );
		return;
	}
	// RevPhone.Frob's dialling window (on the frobber's root window).
	if ( bRemote && RevPhone(T)!=None && RevPhone(T).AnswerSound==AS_Dialtone && RevPhone(T).validNumber!="" && !T.IsInState('Conversation') && !T.IsInState('FirstPersonConversation') )
	{
		ClientOpenPhone( RevPhone(T), RevPhone(T).validNumber );
		return;
	}
	if ( bRemote && Computers(T)!=None )
		SendComputer( Computers(T) ); // before its frob sends the screen
	else if ( bRemote && ATM(T)!=None )
		SendATM( ATM(T) );
	Super.DoFrob( Frobber, frobWith );
	// ATM.Frob opens the screen on the frobber's root window (the host has none for them).
	if ( bRemote && ATM(T)!=None && !ATM(T).bLockedOut )
		ClientOpenATM( ATM(T), ATM(T).bSuckedDryByHack );
}

// A datacube, book or newspaper: read on the reader's machine (its text window);
// the host triggers what its frob triggers and adds the datavault note and image
// (CoopPlayerProgress shares them; what the client adds itself is the same one).
// ponytail: no frob conversation on a book for a remote reader (CoopPlayerTalk's area);
// the note is the male player's text.
function ReadDevice( InformationDevices D )
{
	local Actor A;
	local DeusExTextParser Parser;
	local DeusExNote Note;
	local DataVaultImage Image;
	local string S;
	local bool bParagraph;

	if ( D.Event!='' )
		foreach AllActors( class'Actor', A, D.Event )
			A.Trigger( D, Self );
	// InformationDevices.CreateInfoWindow's note, without the window.
	if ( D.textTag!='' && D.bAddToVault && GetNote( D.textTag, D.TextPackage )==None && (D.IsA('DataCube') || bInformationDevices) )
	{
		Parser = new(None) class'DeusExTextParser';
		if ( Parser.OpenText( D.textTag, D.TextPackage ) )
		{
			Parser.SetPlayerName( TruePlayerName );
			while ( Parser.ProcessText() )
				switch ( Parser.GetTag() )
				{
					case 0:  // text, the player's name
					case 9:
					case 10:
						S = S $ Parser.GetText();
						break;
					case 18: // new paragraph
						if ( bParagraph )
							S = S $ Chr(13) $ Chr(10);
						bParagraph = True;
						break;
				}
			Parser.CloseText();
			S = S $ D.SpecialText;
			if ( D.IsA('DataCube') )
				Note = AddNote( S,, True, "Datacubes" );
			else
				Note = AddNote( S,, True, "Literature" );
			Note.SetTextTag( D.textTag, D.TextPackage );
		}
		CriticalDelete( Parser );
	}
	if ( D.imageClass!=None )
	{
		Image = Spawn( D.imageClass, Self );
		if ( Image!=None )
		{
			Image.GiveTo( Self );
			Image.SetBase( Self );
			if ( !AddImage( Image ) )
				Image.Destroy();
		}
	}
	// ponytail: script-given text is cut at 300 characters (a call's strings over ~400 never
	// arrive); CoopPlayerProgress.SendLong can carry more.
	ClientReadDevice( D, D.textTag, D.TextPackage, Left( D.SpecialText, 300 ), D.imageClass );
}

function SendComputer( Computers C )
{
	local int i;
	local name Bulletins;

	if ( ComputerPublic(C)!=None )
		Bulletins = ComputerPublic(C).bulletinTag;
	// Node enums as text (Revision's computers have a node list of their own).
	ClientComputer( C, C.GetPropertyText( "ComputerNode" ), C.GetPropertyText( "RevComputerNode" ), C.TextPackage, Bulletins );
	for ( i=0; i<ArrayCount(C.userList); i++ )
		ClientComputerUser( C, i, C.userList[i].userName, C.userList[i].password, C.userList[i].accessLevel );
	for ( i=0; i<ArrayCount(C.specialOptions); i++ )
		ClientComputerOption( C, i, C.specialOptions[i].Text, C.specialOptions[i].TriggerText, C.specialOptions[i].userName, C.specialOptions[i].bTriggerOnceOnly, C.specialOptions[i].bAlreadyTriggered );
}

function SendATM( ATM M )
{
	local int i;

	for ( i=0; i<ArrayCount(M.userList); i++ )
		ClientATMUser( M, i, M.userList[i].accountNumber, M.userList[i].PIN, M.userList[i].balance );
}

// ----------------------------------------------------------------------
// DeusExPlayer sends these to the owner's machine only (bNetOwner), which a call
// made on the host never counts as (measured: they run on the host, where a remote
// player has no screen). Ours reach the client. Under single-player rules the
// keypad window waits (CoopPlayerCore); aug icons catch up when a screen refreshes them.
// ----------------------------------------------------------------------

function bool ForClient()
{
	return Role==ROLE_Authority && NetConnection(Player)!=None;
}

function ActivateKeypadWindow( Keypad KPad, bool bHacked )
{
	if ( ForClient() && !Deferring() )
		ClientKeypadWindow( KPad, bHacked, KPad.Event );
	else
		Super.ActivateKeypadWindow( KPad, bHacked );
}

function AddAugmentationDisplay( Augmentation Aug )
{
	if ( !ForClient() )
		Super.AddAugmentationDisplay( Aug );
	else if ( !Deferring() )
		ClientAugDisplay( Aug, 0 );
}

function RemoveAugmentationDisplay( Augmentation Aug )
{
	if ( !ForClient() )
		Super.RemoveAugmentationDisplay( Aug );
	else if ( !Deferring() )
		ClientAugDisplay( Aug, 1 );
}

function UpdateAugmentationDisplayStatus( Augmentation Aug )
{
	if ( !ForClient() )
		Super.UpdateAugmentationDisplayStatus( Aug );
	else if ( !Deferring() )
		ClientAugDisplay( Aug, 2 );
}

simulated function ClientKeypadWindow( Keypad KPad, bool bHacked, name KeypadEvent )
{
	if ( KPad==None )
		return;
	KPad.Event = KeypadEvent; // the code window runs the keypad's events only if it has one
	ActivateKeypadWindow( KPad, bHacked );
}

simulated function ClientAugDisplay( Augmentation Aug, byte Op )
{
	if ( Aug==None )
		return;
	if ( Op==0 )
		AddAugmentationDisplay( Aug );
	else if ( Op==1 )
		RemoveAugmentationDisplay( Aug );
	else
		UpdateAugmentationDisplayStatus( Aug );
}

// ----------------------------------------------------------------------
// Host: what device screens do (calls from the screens, CoopComputer*/CoopMed*)
// ----------------------------------------------------------------------

// ComputerScreenSpecialOptions.ActivateSpecialOption.
function ServerSpecialOption( Computers C, int i )
{
	local Actor A;

	if ( C==None || C.curFrobber!=Self || i<0 || i>=ArrayCount(C.specialOptions) || C.specialOptions[i].bAlreadyTriggered )
		return;
	if ( C.specialOptions[i].TriggerEvent!='' )
		foreach AllActors( class'Actor', A, C.specialOptions[i].TriggerEvent )
			A.Trigger( None, Self );
	if ( C.specialOptions[i].UnTriggerEvent!='' )
		foreach AllActors( class'Actor', A, C.specialOptions[i].UnTriggerEvent )
			A.UnTrigger( None, Self );
	if ( C.specialOptions[i].bTriggerOnceOnly )
		C.specialOptions[i].bAlreadyTriggered = True;
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "used option" @ i @ "of" @ C @ "event" @ C.specialOptions[i].TriggerEvent, 'RevNet' );
}

// ComputerScreenSecurity.ToggleDoorLock and TriggerDoor: a door of the terminal's views.
function ServerDoor( ComputerSecurity C, name DoorTag, bool bOpen )
{
	local DeusExMover M;
	local int i;

	if ( C==None || C.curFrobber!=Self || DoorTag=='' )
		return;
	for ( i=0; i<ArrayCount(C.Views); i++ )
		if ( C.Views[i].doorTag==DoorTag )
			break;
	if ( i==ArrayCount(C.Views) )
		return;
	foreach AllActors( class'DeusExMover', M, DoorTag )
	{
		if ( bOpen )
			M.Trigger( C, Self );
		else
			M.bLocked = !M.bLocked;
	}
}

// ComputerScreenATMWithdraw.WithdrawCredits (the screen changed the copies there).
function ServerWithdraw( ATM M, int UserIndex, int Amount, bool bDry )
{
	if ( M==None || Amount<=0 || VSize(M.Location - Location)>400 || UserIndex<-1 || UserIndex>=M.NumUsers() )
		return;
	// (-1: hacked, every account's: never more than there is.)
	Amount = Min( Amount, M.GetBalance( UserIndex, 1.0 ) );
	M.ModBalance( UserIndex, Amount, True );
	Credits += Amount;
	if ( bCustomDifficulty )
		Credits = Min( Credits, CDMaxCredits );
	if ( bDry )
		M.bSuckedDryByHack = True;
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "withdrew" @ Amount @ "from" @ M @ "credits" @ Credits, 'RevNet' );
}

// RevHUDKeypadWindow.ValidateCode for a phone: the right number triggers its event.
// ponytail: the dial tone and the phone's "in use" aren't set for a remote player.
function ServerDialed( RevPhone Phone, string Number )
{
	local Actor A;

	if ( Phone==None || Number=="" || Number!=Phone.validNumber || VSize(Phone.Location - Location)>400 || Phone.DialEvent=='' )
		return;
	foreach AllActors( class'Actor', A, Phone.DialEvent )
		A.Trigger( Phone, Self );
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "dialled" @ Number @ "on" @ Phone @ "event" @ Phone.DialEvent, 'RevNet' );
	if ( Phone.bEventOnlyOnce )
		Phone.DialEvent = '';
}

// HUDMedBotHealthScreen.MedBotHealPlayer, single-player healing (deathmatch spreads it
// over fewer body parts).
function ServerMedBotHeal( MedicalBot Bot )
{
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	if ( G==None || Bot==None || !Bot.CanHeal() || VSize(Bot.Location - Location)>400 )
		return;
	G.BeginSinglePlayerRules();
	Bot.HealPlayer( Self );
	G.EndSinglePlayerRules();
	DeusExPlayer(GetPlayerPawn()).flagBase.SetBool( 'PlayerUsedBot', True,, 100 ); // story flags are the host's
	ClientMedBotTime( Bot, Bot.GetRefreshTimeRemaining(), Bot.healRefreshTime, Bot.healAmount );
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "healed by" @ Bot @ "health" @ Health, 'RevNet' );
}

// HUDMedBotAddAugsScreen.InstallAugmentation (and its replacing an aug in a full slot),
// with single-player slots and hotkeys.
function ServerInstallAug( MedicalBot Bot, AugmentationCannister Can, class<Augmentation> AugClass, class<Augmentation> Replaced )
{
	local CoopGameInfo G;
	local Augmentation Aug, Old;
	local int Levels, Key;

	G = CoopGameInfo(Level.Game);
	if ( G==None || Bot==None || Can==None || Can.Owner!=Self || AugClass==None || AugmentationSystem==None || VSize(Bot.Location - Location)>400 )
		return;
	if ( Can.AddAugs[0]!=AugClass.Name && Can.AddAugs[1]!=AugClass.Name )
		return;
	if ( Replaced!=None )
	{
		Old = AugmentationSystem.FindAugmentation( Replaced );
		if ( Old!=None && Old.bHasIt && Old.AugmentationLocation==AugClass.default.AugmentationLocation )
		{
			Levels = Old.CurrentLevel;
			Key = Old.HotKeyNum;
			Old.CurrentLevel = 0;
			Old.bHasIt = False;
			Old.HotKeyNum = -1;
			if ( Old.AugmentationLocation<ArrayCount(AugmentationSystem.AugLocs) ) // (HR's own locations: past them)
				AugmentationSystem.AugLocs[Old.AugmentationLocation].augCount--;
			RemoveAugmentationDisplay( Old );
		}
	}
	// Its aug icon can't reach a remote client under the rules: CoopMedAugs refreshes the icons.
	G.BeginSinglePlayerRules();
	Aug = AugmentationSystem.GivePlayerAugmentation( AugClass );
	while ( Levels-->0 )
		AugmentationSystem.GivePlayerAugmentation( AugClass ); // the replaced aug's level
	G.EndSinglePlayerRules();
	if ( Aug==None || !Aug.bHasIt )
		return; // its slots are full: the canister stays
	if ( Key>0 )
		Aug.HotKeyNum = Key;
	DeleteInventory( Can );
	Can.Destroy();
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "installed" @ Aug.Class.Name @ "level" @ Aug.CurrentLevel @ "hotkey" @ Aug.HotKeyNum @ "location" @ Aug.AugmentationLocation, 'RevNet' );
}

// ----------------------------------------------------------------------
// The user's machine
// ----------------------------------------------------------------------

// A device copy runs its own functions here while its screen is open.
simulated function UseDevice( Actor A )
{
	DoneWithDevice();
	OpenDevice = A;
	OpenDeviceRole = A.Role;
	A.Role = ROLE_Authority;
}

simulated function DoneWithDevice()
{
	if ( OpenDevice!=None )
		OpenDevice.Role = OpenDeviceRole;
	OpenDevice = None;
}

simulated function bool DeviceScreenOpen( Actor A )
{
	return (Computers(A)!=None && Computers(A).termwindow!=None) || (ATM(A)!=None && ATM(A).atmwindow!=None)
		|| (InformationDevices(A)!=None && InformationDevices(A).infoWindow!=None);
}

event PlayerInput( float DeltaTime )
{
	Super.PlayerInput( DeltaTime );
	if ( OpenDevice!=None && !DeviceScreenOpen( OpenDevice ) )
		DoneWithDevice();
}

// Screen code under single-player rules on this machine (code that calls nothing on
// the other side: CoopMedAugs' slot checks).
simulated function BeginLocalRules()
{
	bLocalFromClient = Level.NetMode==NM_Client;
	bLocalFromListen = Level.NetMode==NM_ListenServer;
	Level.NetMode = NM_Standalone;
}

simulated function EndLocalRules()
{
	if ( bLocalFromClient )
		Level.NetMode = NM_Client;
	else if ( bLocalFromListen )
		Level.NetMode = NM_ListenServer;
}

simulated function ClientComputer( Computers C, string Node, string RevNode, string Package, name Bulletins )
{
	if ( C==None )
		return;
	C.SetPropertyText( "ComputerNode", Node );
	if ( RevNode!="" )
		C.SetPropertyText( "RevComputerNode", RevNode );
	if ( ComputerPublic(C)!=None )
		ComputerPublic(C).bulletinTag = Bulletins;
	C.TextPackage = Package;
}

simulated function ClientComputerUser( Computers C, int i, string UserName, string Password, byte Access )
{
	if ( C==None )
		return;
	C.userList[i].userName = UserName;
	C.userList[i].password = Password;
	switch ( Access ) // (no byte to enum here)
	{
		case 0: C.userList[i].accessLevel = AL_Untrained; break;
		case 1: C.userList[i].accessLevel = AL_Trained; break;
		case 2: C.userList[i].accessLevel = AL_Advanced; break;
		default: C.userList[i].accessLevel = AL_Master;
	}
}

simulated function ClientComputerOption( Computers C, int i, string Text, string TriggerText, string UserName, bool bOnce, bool bDone )
{
	if ( C==None )
		return;
	C.specialOptions[i].Text = Text;
	C.specialOptions[i].TriggerText = TriggerText;
	C.specialOptions[i].userName = UserName;
	C.specialOptions[i].bTriggerOnceOnly = bOnce;
	C.specialOptions[i].bAlreadyTriggered = bDone;
}

// The computer's screen (Computers.Invoke), single-player's: deathmatch starts hacking
// right away when the computer has no users (its copy here never has any).
function InvokeComputerScreen( Computers computerToActivate, float CompHackTime, float ServerLevelTime )
{
	local DeusExRootWindow Root;
	local NetworkTerminal Term;

	if ( Role==ROLE_Authority || computerToActivate==None )
	{
		Super.InvokeComputerScreen( computerToActivate, CompHackTime, ServerLevelTime );
		return;
	}
	computerToActivate.LastHackTime = CompHackTime + (Level.TimeSeconds - ServerLevelTime);
	ActiveComputer = computerToActivate;
	Root = DeusExRootWindow(rootWindow);
	if ( Root!=None )
	{
		UseDevice( computerToActivate );
		Term = NetworkTerminal(Root.InvokeUIScreen( TerminalClass( computerToActivate.terminalType ), True ));
	}
	if ( Term==None )
	{
		DoneWithDevice();
		CloseComputerScreen( computerToActivate );
		ActiveComputer = None;
		return;
	}
	computerToActivate.termwindow = Term;
	Term.SetCompOwner( computerToActivate );
	Term.ShowFirstScreen();
	Log( "RevNetTest: client computer screen" @ Term.Class.Name @ "for" @ computerToActivate @ "users=" $ computerToActivate.NumUsers() @ "screen=" $ Term.winComputer, 'RevNet' );
}

// Terminals whose screens change the world (CoopComputerPersonal.CoopScreen).
simulated function class<NetworkTerminal> TerminalClass( class<NetworkTerminal> T )
{
	if ( T==class'NetworkTerminalPersonal' )
		return class'CoopComputerPersonal';
	if ( T==class'NetworkTerminalSecurity' )
		return class'CoopComputerSecurity';
	return T;
}

simulated function ClientATMUser( ATM M, int i, string Account, string PIN, int Balance )
{
	if ( M==None )
		return;
	M.userList[i].accountNumber = Account;
	M.userList[i].PIN = PIN;
	M.userList[i].balance = Balance;
}

// ATM.Frob's screen.
simulated function ClientOpenATM( ATM M, bool bDry )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(rootWindow);
	if ( M==None || Root==None || M.atmwindow!=None )
		return;
	M.bSuckedDryByHack = bDry;
	UseDevice( M );
	M.atmwindow = ATMWindow(Root.InvokeUIScreen( class'CoopComputerATM', True ));
	if ( M.atmwindow==None )
	{
		DoneWithDevice();
		return;
	}
	M.atmwindow.SetCompOwner( M );
	M.atmwindow.ShowFirstScreen();
	Log( "RevNetTest: client ATM screen for" @ M @ "accounts=" $ M.NumUsers(), 'RevNet' );
}

// The device's own frob on its copy here: its text window (a second frob closes it),
// datavault note and image.
simulated function ClientReadDevice( InformationDevices D, name TextTag, string Package, string Special, class<DataVaultImage> Image )
{
	if ( D==None )
		return;
	D.textTag = TextTag;
	D.TextPackage = Package;
	D.SpecialText = Special;
	D.imageClass = Image;
	UseDevice( D );
	D.Frob( Self, None );
	if ( D.infoWindow==None )
		DoneWithDevice();
	Log( "RevNetTest: client reads" @ D @ TextTag @ "window=" $ (D.infoWindow!=None) @ "text:" @ Left( D.winText.GetText(), 60 ), 'RevNet' );
}

simulated function ClientOpenPhone( RevPhone Phone, string Number )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(rootWindow);
	if ( Phone==None || Root==None || Phone.dialwindow!=None )
		return;
	Phone.validNumber = Number;
	Phone.dialwindow = RevHUDKeypadWindow(Root.InvokeUIScreen( class'CoopDevicePhone', True ));
	Root.MaskBackground( True );
	if ( Phone.dialwindow!=None )
	{
		Phone.dialwindow.phoneOwner = Phone;
		Phone.dialwindow.player = Self;
		Phone.dialwindow.InitData();
	}
	Log( "RevNetTest: client phone window for" @ Phone @ "window=" $ Phone.dialwindow, 'RevNet' );
}

// MedicalBot.Frob's single-player screens.
simulated function ClientOpenMedBot( MedicalBot Bot, float Remaining, int Refresh, int Heal )
{
	if ( Bot==None )
		return;
	ClientMedBotTime( Bot, Remaining, Refresh, Heal );
	OpenMedScreen( Bot, FindInventoryType( class'AugmentationCannister' )!=None, True );
}

// What CanHeal reads on the bot's copy here.
simulated function ClientMedBotTime( MedicalBot Bot, float Remaining, int Refresh, int Heal )
{
	if ( Bot==None || Role==ROLE_Authority )
		return;
	Bot.healRefreshTime = Refresh;
	Bot.lastHealTime = Level.TimeSeconds - Refresh + Remaining;
	Bot.healAmount = Heal;
	if ( HUDMedBotHealthScreen(MedScreen)!=None )
		HUDMedBotHealthScreen(MedScreen).UpdateRegionWindows();
}

// (Also the screens' navigation bar, CoopMedNavBar.)
function OpenMedScreen( MedicalBot Bot, bool bAugs, bool bFirst )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(rootWindow);
	if ( Root==None )
		return;
	if ( bAugs )
	{
		MedScreen = Root.InvokeUIScreen( class'CoopMedAugs', True );
		HUDMedBotAddAugsScreen(MedScreen).SetMedicalBot( Bot, bFirst );
	}
	else
	{
		MedScreen = Root.InvokeUIScreen( class'CoopMedHealth', True );
		HUDMedBotHealthScreen(MedScreen).SetMedicalBot( Bot, bFirst );
	}
	if ( bFirst )
		Root.MaskBackground( True );
	Log( "RevNetTest: medbot screen" @ MedScreen.Class.Name @ "for" @ Bot @ "netmode" @ Level.NetMode @ "last heal" @ Bot.lastHealTime @ "of" @ Level.TimeSeconds, 'RevNet' );
}

// ----------------------------------------------------------------------
// Test harness (CoopTestDevices): drives the screens open here.
// ----------------------------------------------------------------------

simulated function ClientDeviceTest( string Command, optional Actor A, optional string Arg )
{
	local Computers C;
	local NetworkTerminal Term;
	local ComputerScreenLogin Login;
	local ComputerScreenATM AtmLogin;
	local CoopComputerOptions Options;
	local CoopComputerWithdraw Withdraw;
	local CoopMedAugs Augs;
	local HUDMedBotAugCanWindow CanWin;
	local Augmentation Aug;
	local Keypad K;

	if ( Command=="login" )
	{
		C = Computers(A);
		Term = C.termwindow;
		Login = ComputerScreenLogin(Term.winComputer);
		Login.editUserName.SetText( C.userList[C.NumUsers() - 1].userName );
		Login.editPassword.SetText( C.userList[C.NumUsers() - 1].password );
		Login.ProcessLogin();
		Log( "RevNetTest: client logged in as" @ Term.GetUserName() @ "screen" @ Term.winComputer.Class.Name, 'RevNet' );
		if ( ComputerScreenEmail(Term.winComputer)!=None )
			Log( "RevNetTest: client emails" @ ComputerScreenEmail(Term.winComputer).lstEmail.GetNumRows() @ "first:" @ Left( ComputerScreenEmail(Term.winComputer).winEmail.GetText(), 60 ), 'RevNet' );
		Options = CoopComputerOptions(Term.winComputer);
		if ( Options!=None && Options.optionButtons[0].btnSpecial!=None )
		{
			Options.ActivateSpecialOption( Options.optionButtons[0].btnSpecial );
			Log( "RevNetTest: client used option" @ Options.optionButtons[0].specialIndex @ "text:" @ Options.winSpecialInfo.GetText(), 'RevNet' );
		}
	}
	else if ( Command=="close" )
	{
		C = Computers(A);
		if ( C!=None && C.termwindow!=None )
			C.termwindow.CloseScreen( "EXIT" );
		else if ( ATM(A)!=None && ATM(A).atmwindow!=None )
			ATM(A).atmwindow.CloseScreen( "EXIT" );
		else if ( MedScreen!=None )
			DeusExRootWindow(rootWindow).PopWindow();
		Log( "RevNetTest: client closed the screen, device role=" $ A.Role @ "open device=" $ OpenDevice, 'RevNet' );
	}
	else if ( Command=="atm" )
	{
		AtmLogin = ComputerScreenATM(ATM(A).atmwindow.winComputer);
		AtmLogin.editAccount.SetText( ATM(A).userList[0].accountNumber );
		AtmLogin.editPIN.SetText( ATM(A).userList[0].PIN );
		AtmLogin.ProcessLogin();
		Withdraw = CoopComputerWithdraw(ATM(A).atmwindow.winComputer);
		Log( "RevNetTest: client ATM login screen" @ ATM(A).atmwindow.winComputer.Class.Name @ "credits" @ Credits, 'RevNet' );
		if ( Withdraw!=None )
		{
			Withdraw.editWithdraw.SetText( Arg );
			Withdraw.WithdrawCredits();
			Log( "RevNetTest: client withdrew" @ Arg @ "credits now" @ Credits @ "balance" @ ATM(A).userList[0].balance, 'RevNet' );
		}
	}
	else if ( Command=="keypad" )
	{
		K = Keypad(A);
		Log( "RevNetTest: client keypad" @ K @ "event=" $ K.Event @ "window=" $ K.keypadwindow, 'RevNet' );
		K.keypadwindow.inputCode = K.validCode;
		K.keypadwindow.ValidateCode();
	}
	else if ( Command=="phone" )
	{
		Log( "RevNetTest: client dials" @ RevPhone(A).validNumber @ "window=" $ RevPhone(A).dialwindow, 'RevNet' );
		RevPhone(A).dialwindow.inputCode = RevPhone(A).validNumber;
		RevPhone(A).dialwindow.ValidateCode();
	}
	else if ( Command=="medinstall" )
	{
		Augs = CoopMedAugs(MedScreen);
		CanWin = HUDMedBotAugCanWindow(Augs.winAugsTile.GetTopChild());
		Log( "RevNetTest: client aug screen" @ Augs @ "can" @ CanWin @ "slot full=" $ CanWin.btnAug1.bSlotFull, 'RevNet' );
		Augs.SelectAugmentation( CanWin.btnAug1 );
		Augs.ButtonActivated( Augs.btnInstall );
	}
	else if ( Command=="medheal" )
	{
		Log( "RevNetTest: client health screen" @ MedScreen @ "health" @ Health, 'RevNet' );
		HUDMedBotHealthScreen(MedScreen).MedBotHealPlayer();
	}
	else if ( Command=="augs" )
	{
		for ( Aug=class'CoopRules'.static.FirstAug( Self ); Aug!=None; Aug=Aug.next )
			if ( Aug.bHasIt )
				Log( "RevNetTest: client aug" @ Aug.Class.Name @ "level" @ Aug.CurrentLevel @ "hotkey" @ Aug.HotKeyNum @ "active=" $ Aug.bIsActive @ "location" @ Aug.AugmentationLocation, 'RevNet' );
		if ( Arg!="" )
			ActivateAugmentation( int(Arg) );
	}
	else
		Log( "RevNetTest: client device" @ Command @ A @ "role=" $ A.Role @ "open device=" $ OpenDevice @ "health" @ Health @ "credits" @ Credits, 'RevNet' );
}
