//=============================================================================
// CoopTestLightMech.
//
// ?CoopTest=LightMech (tools/run_net_live.ps1 -ClientAgent LightMech): the client
// is a Light Mech (CoopLightMechPlayer, docs/LIGHT_MECH_CLASS.md), the host JC's
// kind. Its body and rules against the host's, Praxis from skill points, all
// fourteen modules bought to level 4, and each one's effect: the damage rules
// (Rhino, Icarus, Sentinel's rebreather, Titan), the arms, Tesla, Nanoblade,
// P.E.P.S. and Typhoon on hostile troopers, Remote Hacking on a camera and a robot,
// Glass-Shield, Focus on a pistol, Smart Vision from the client's own key and on
// its HUD, Icarus Dash, Sentinel's healing, a use refused without energy, the
// screen on the client; then a reconnect keeps the class, its levels and Praxis.
//=============================================================================
class CoopTestLightMech extends CoopTest;

var int Stage;
var ScriptedPawn Troops[4];
var int NumTroops;
var Actor Camera, Bot;
var DeusExWeapon Pistol;
var int HurtHealth;
var rotator Facing;

function CoopLightAug Mod( class<CoopLightAug> C )
{
	return CoopLightAug(class'CoopMechAug'.static.Find( Remote, C ));
}

// Every module's level on the host, and the Praxis.
function string Levels()
{
	local CoopMechPlayer M;
	local string S;
	local int i;

	M = CoopMechPlayer(Remote);
	if ( M==None )
		return "not a Mech";
	for ( i=0; i<ArrayCount(M.Modules); i++ )
		if ( M.Modules[i]!=None )
			S = S @ M.Modules[i].Name $ "=" $ M.ModLevel( M.Modules[i] );
	return "praxis" @ M.Salvage $ ":" $ S;
}

function string TroopState()
{
	local string S;
	local int i;

	for ( i=0; i<NumTroops; i++ )
		if ( Troops[i]==None || Troops[i].bDeleteMe )
			S = S @ "|gone";
		else
			S = S @ "|" @ Troops[i].Health @ Troops[i].GetStateName() @ int(VSize(Troops[i].Velocity));
	return S;
}

// Faces the client toward its front (the host's view of it is what the modules aim by).
function Face()
{
	Remote.ViewRotation = Facing;
	Remote.SetRotation( Facing );
	Remote.ClientSetLocation( Remote.Location, Facing );
}

function Run( int t )
{
	local CoopLightMechPlayer L;
	local CoopLightAug A;
	local DeusExProjectile Proj;
	local vector Dir, Side;
	local float E;
	local int i, k, Before;

	L = CoopLightMechPlayer(Remote);
	if ( Stage==1 )
	{
		if ( t==6 )
		{
			Log( "RevNetTest: lightmech back: class" @ Remote.Class.Name @ "| arms" @ (Remote.FindInventoryType( class'CoopMechBlade' )!=None) @ "cannon" @ (Remote.FindInventoryType( class'CoopMechCannon' )!=None), 'RevNet' );
			Log( "RevNetTest: lightmech back:" @ Levels(), 'RevNet' );
			Done();
		}
		return;
	}
	if ( L==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: lightmech: the client is a" @ Remote.Class.Name @ "(run with -ClientAgent LightMech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==3 )
	{
		Log( "RevNetTest: lightmech class" @ Remote.Class.Name @ "| mesh" @ Remote.Mesh @ "host" @ Host.Mesh @ "| skins" @ Remote.MultiSkins[0] @ Remote.MultiSkins[1]
			@ "| scale" @ Remote.DrawScale @ "| jump" @ Remote.JumpZ @ "host" @ Host.JumpZ @ "| mass" @ Remote.Mass @ "host" @ Host.Mass
			@ "| speed" @ int(Remote.GetCurrentGroundSpeed()) @ "host" @ int(Host.GetCurrentGroundSpeed()), 'RevNet' );
		Log( "RevNetTest: lightmech arms: blades" @ (Remote.FindInventoryType( class'CoopMechBlade' )!=None) @ "cannon" @ (Remote.FindInventoryType( class'CoopMechCannon' )!=None) @ "| start" @ Levels(), 'RevNet' );
	}
	else if ( t==4 )
	{
		Before = L.Salvage;
		Remote.SkillPointsAdd( 600 );
		Log( "RevNetTest: lightmech 600 skill points: praxis +" $ (L.Salvage - Before) @ "toward the next" @ L.PointsToPraxis, 'RevNet' );
		L.Salvage = 300;
		for ( i=0; i<ArrayCount(L.Modules); i++ )
			for ( k=0; k<4; k++ )
				L.ServerUpgradeModule( i );
		Log( "RevNetTest: lightmech all bought:" @ Levels(), 'RevNet' );
		Remote.ClientTest( "mech" );
	}
	else if ( t==5 )
	{
		Before = Remote.HealthTorso;
		k = Host.HealthTorso;
		Remote.TakeDamage( 20, None, Remote.Location, vect(0,0,0), 'Shot' );
		Host.TakeDamage( 20, None, Host.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: lightmech shot 20 (Rhino 4): torso lost" @ (Before - Remote.HealthTorso) @ "host lost" @ (k - Host.HealthTorso), 'RevNet' );
		Host.RestoreAllHealth();
		Before = Remote.HealthLegLeft + Remote.HealthLegRight;
		Remote.TakeDamage( 30, None, Remote.Location - vect(0,0,30), vect(0,0,0), 'Fell' );
		Log( "RevNetTest: lightmech fall 30 (Icarus): legs lost" @ (Before - Remote.HealthLegLeft - Remote.HealthLegRight), 'RevNet' );
		E = Remote.Energy;
		Remote.TakeDamage( 10, None, Remote.Location, vect(0,0,0), 'EMP' );
		Log( "RevNetTest: lightmech EMP 10 (Rhino 4 shielding): energy lost" @ (E - Remote.Energy), 'RevNet' );
		Before = Remote.Health;
		Remote.TakeDamage( 10, None, Remote.Location, vect(0,0,0), 'TearGas' );
		Log( "RevNetTest: lightmech tear gas 10 (rebreather): health lost" @ (Before - Remote.Health), 'RevNet' );
		Mod( class'CoopLightAugTitan' ).Activate();
		Before = Remote.HealthTorso;
		Remote.TakeDamage( 40, None, Remote.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: lightmech shot 40 with Titan on: torso lost" @ (Before - Remote.HealthTorso) @ "glow" @ Remote.AmbientGlow, 'RevNet' );
		Mod( class'CoopLightAugTitan' ).Deactivate();
		Remote.RestoreAllHealth();
	}
	else if ( t==6 )
	{
		Log( "RevNetTest: lightmech legs 4: speed" @ int(Remote.GetCurrentGroundSpeed()) @ "host" @ int(Host.GetCurrentGroundSpeed())
			@ "| blades" @ DeusExWeapon(Remote.FindInventoryType( class'CoopMechBlade' )).HitDamage
			@ "takedown level" @ L.BladeLevel() @ "doors x" $ L.BladeDoorMult(), 'RevNet' );
		Log( "RevNetTest: lightmech drop blades:" @ Remote.DropItem( Remote.FindInventoryType( class'CoopMechBlade' ), true ), 'RevNet' );
	}
	else if ( t==7 )
	{
		// Four hostile troopers ahead, unarmed.
		Facing = Remote.ViewRotation;
		Facing.Pitch = 0;
		Face();
		Dir = vector(Facing);
		Side = Dir cross vect(0,0,1);
		for ( i=0; i<4; i++ )
		{
			Troops[NumTroops] = Spawn( class'MJ12Troop',,, Remote.Location + Dir * 360 + Side * (i - 1.5) * 90 );
			if ( Troops[NumTroops]==None )
				continue;
			Troops[NumTroops].ChangeAlly( 'Player', -1.0, true );
			while ( Troops[NumTroops].Inventory!=None )
				Troops[NumTroops].Inventory.Destroy();
			NumTroops++;
		}
		Remote.Energy = Remote.EnergyMax;
		Log( "RevNetTest: lightmech troopers" @ NumTroops @ "hostile" @ (NumTroops>0 && class'CoopLightAug'.static.Hostile( Troops[0], Remote ))$ ":" $ TroopState(), 'RevNet' );
	}
	else if ( t==8 )
	{
		Face();
		E = Remote.Energy;
		A = Mod( class'CoopLightAugTesla' );
		A.Activate();
		Log( "RevNetTest: lightmech Tesla: hit" @ A.NumHit @ "energy -" $ int(E - Remote.Energy) $ ":" $ TroopState(), 'RevNet' );
	}
	else if ( t==9 )
	{
		// At a trooper (the second: the first two Tesla may have stunned).
		if ( NumTroops>1 && Troops[1]!=None )
			Facing = rotator(Troops[1].Location - (Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight));
		Face();
		E = Remote.Energy;
		Mod( class'CoopLightAugNanoblade' ).Activate();
		foreach AllActors( class'DeusExProjectile', Proj )
			if ( Proj.Owner==Remote )
				k++;
		Log( "RevNetTest: lightmech Nanoblade fired: blades in flight" @ k @ "energy -" $ int(E - Remote.Energy), 'RevNet' );
	}
	else if ( t==10 )
	{
		Log( "RevNetTest: lightmech after the Nanoblade:" @ TroopState(), 'RevNet' );
		Face();
		E = Remote.Energy;
		Mod( class'CoopLightAugPEPS' ).Activate();
		Log( "RevNetTest: lightmech P.E.P.S.: energy -" $ int(E - Remote.Energy) $ ":" $ TroopState(), 'RevNet' );
	}
	else if ( t==11 )
	{
		E = Remote.Energy;
		Mod( class'CoopLightAugTyphoon' ).Activate();
		Log( "RevNetTest: lightmech Typhoon: energy -" $ int(E - Remote.Energy) $ ":" $ TroopState(), 'RevNet' );
	}
	else if ( t==12 )
	{
		Remote.Energy = 5;
		Mod( class'CoopLightAugTyphoon' ).Activate();
		Log( "RevNetTest: lightmech Typhoon with 5 energy: energy now" @ int(Remote.Energy), 'RevNet' );
		Remote.Energy = Remote.EnergyMax;
	}
	else if ( t==13 )
	{
		Face();
		Dir = vector(Facing);
		Camera = Spawn( class'SecurityCamera',,, Remote.Location + Dir * 300 + vect(0,0,40) );
		Log( "RevNetTest: lightmech camera" @ Camera, 'RevNet' );
		Mod( class'CoopLightAugRemote' ).Activate();
		if ( SecurityCamera(Camera)!=None )
			Log( "RevNetTest: lightmech Remote Hacking a camera: confused" @ SecurityCamera(Camera).bConfused, 'RevNet' );
		if ( Camera!=None )
			Camera.Destroy();
		Bot = Spawn( class'SecurityBot2',,, Remote.Location + Dir * 360 );
		if ( ScriptedPawn(Bot)!=None )
		{
			ScriptedPawn(Bot).ChangeAlly( 'Player', -1.0, true );
			Mod( class'CoopLightAugRemote' ).Activate();
			Log( "RevNetTest: lightmech Remote Hacking a robot: EMP hit points left" @ Robot(Bot).EMPHitPoints, 'RevNet' );
			Bot.Destroy();
		}
		else
			Log( "RevNetTest: lightmech no room for a robot", 'RevNet' );
	}
	else if ( t==14 )
	{
		Mod( class'CoopLightAugCloak' ).Activate();
		Log( "RevNetTest: lightmech Glass-Shield on: cloaked" @ Remote.bCloaked @ "radar" @ Remote.bRadarCloaked @ "style" @ Remote.Style, 'RevNet' );
		Mod( class'CoopLightAugCloak' ).Deactivate();
		Log( "RevNetTest: lightmech Glass-Shield off: cloaked" @ Remote.bCloaked @ "radar" @ Remote.bRadarCloaked, 'RevNet' );
		Pistol = Spawn( class'WeaponPistol',,, Remote.Location );
		Remote.FrobTarget = Pistol;
		Remote.HandleItemPickup( Pistol );
		Remote.FrobTarget = None;
		Remote.PutInHand( Pistol );
	}
	else if ( t==15 )
	{
		Log( "RevNetTest: lightmech pistol in hand:" @ Remote.Weapon @ "accuracy" @ Pistol.BaseAccuracy @ "recoil" @ Pistol.recoilStrength @ "(arms 4: 40% less)", 'RevNet' );
		Mod( class'CoopLightAugFocus' ).Activate();
		Log( "RevNetTest: lightmech Focus on: accuracy" @ Pistol.BaseAccuracy @ "recoil" @ Pistol.recoilStrength @ "speed" @ int(Remote.GetCurrentGroundSpeed()), 'RevNet' );
		Remote.ClientTest( "augkey 0" ); // F3: Smart Vision, from the client's own key
	}
	else if ( t==16 )
	{
		Mod( class'CoopLightAugFocus' ).Deactivate();
		Log( "RevNetTest: lightmech Focus off: accuracy" @ Pistol.BaseAccuracy @ "recoil" @ Pistol.recoilStrength, 'RevNet' );
		Log( "RevNetTest: lightmech Smart Vision on the host: active" @ Mod( class'CoopLightAugVision' ).bIsActive, 'RevNet' );
		Remote.ClientTest( "lightvision" );
		Remote.ClientTest( "augkey 0" );
		Remote.Velocity = vect(0,0,0);
		Mod( class'CoopLightAugIcarus' ).Activate();
		Log( "RevNetTest: lightmech Icarus Dash: speed" @ int(VSize(Remote.Velocity)) @ "physics" @ Remote.Physics, 'RevNet' );
	}
	else if ( t==17 )
	{
		Remote.ClientTest( "lightvision" );
		Remote.ClientUITest( "console", "ShowAugmentationsWindow" );
	}
	else if ( t==18 )
		Remote.ClientTest( "mechscreen" );
	else if ( t==19 )
	{
		// Sentinel RX, with nobody about: hurt, then left alone for 6 s.
		Remote.ClientUITest( "close" );
		for ( i=0; i<NumTroops; i++ )
			if ( Troops[i]!=None )
				Troops[i].Destroy();
		Remote.TakeDamage( 40, None, Remote.Location, vect(0,0,0), 'Shot' );
		HurtHealth = Remote.Health;
		Log( "RevNetTest: lightmech hurt to" @ HurtHealth @ "(Sentinel heals after 4 s)", 'RevNet' );
	}
	else if ( t==25 )
	{
		Log( "RevNetTest: lightmech Sentinel: health" @ HurtHealth @ "->" @ Remote.Health, 'RevNet' );
		CoopGameInfo(Level.Game).SaveCoopGame( false );
		Stage = 1;
		Log( "RevNetTest: the light mech drops out and reconnects", 'RevNet' );
		Remote.ClientTest( "reconnect" );
	}
}
