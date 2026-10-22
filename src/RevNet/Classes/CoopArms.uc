//=============================================================================
// CoopArms.
//
// Weapons, projectiles and bodies under single-player rules where the deathmatch
// code decides as they fly, land or change hands: on the host (rockets, gas, darts,
// clips, bodies blown apart, swim speed) and on each client (its copies of rockets,
// its own weapons' values, its swim speed). Spawned by the host on its first tick,
// always relevant (as CoopClient).
//=============================================================================
class CoopArms extends Info;

var Pawn HeldBy[16];           // (host) each player's weapon in hand a tick ago (Clips)
var DeusExWeapon Held[16];
var int HeldClip[16];
var DeusExProjectile Shown[16]; // (host) darts newly sent to clients, to put in place (Tick)
var float ShownAt[16];
var byte ShownTimes[16];
var int NextShown;
var Cloud Gas[128];            // (host) clouds whose damage beat is ours (Clouds)
var float GasNext[128];
var Inventory Carried[256];    // (host) what bodies carried a tick ago, and where (Bodies)
var vector CarriedAt[256];
var int NumCarried;
var DeusExWeapon Asked[32];    // (client) own weapons whose host values were asked for (Weapons)
var string AskedMods[32];
var SkillSwimming SwimSkill;   // (client) this player's swimming skill (Swimming)

simulated event Tick( float DeltaTime )
{
	local DeusExProjectile P;
	local Pawn Pl;
	local CoopClient Helper;
	local int i;

	foreach AllActors( class'DeusExProjectile', P )
	{
		if ( Rocket(P)!=None )
			Rockets( Rocket(P) );
		else if ( Level.NetMode==NM_Client )
			continue;
		else if ( Cloud(P)!=None )
			Clouds( Cloud(P) );
		else if ( P.bStuck && P.TimerRate>0 && P.bStickToWall && ThrownProjectile(P)==None )
		{
			// A dart or shuriken in a wall: deathmatch removes it after 5 seconds,
			// single-player leaves it to be pulled out (CoopPlayerCore.DoFrob). A remote
			// player's own shot is a copy on its machine only (DoProjectileFire): the
			// host's now goes to the players, to be seen and pulled out.
			P.SetTimer( 0, false );
			if ( P.RemoteRole==ROLE_None )
			{
				P.RemoteRole = ROLE_DumbProxy;
				Shown[NextShown] = P;
				ShownAt[NextShown] = Level.TimeSeconds + 1.0;
				ShownTimes[NextShown] = 3;
				NextShown = (NextShown + 1) % ArrayCount(Shown);
			}
		}
	}
	if ( Level.NetMode==NM_Client )
	{
		Weapons();
		Swimming( DeusExPlayer(GetPlayerPawn()) );
		return;
	}
	// (A client's new copy of a dart flies on from where it was fired, until told where it
	// is: three times a second apart, as a call naming it before the copy is there is lost.)
	for ( i=0; i<ArrayCount(Shown); i++ )
		if ( Shown[i]!=None && Level.TimeSeconds>=ShownAt[i] )
		{
			foreach AllActors( class'CoopClient', Helper )
				Helper.Settle( Shown[i] );
			ShownAt[i] += 1.0;
			if ( --ShownTimes[i]==0 )
				Shown[i] = None;
		}
	GasDamage();
	Clips();
	Bodies();
	for ( Pl=Level.PawnList; Pl!=None; Pl=Pl.nextPawn )
		Swimming( DeusExPlayer(Pl) );
}

// Rockets (exactly Rocket and RocketWP, on every machine): deathmatch flies them at
// 2000 and blows them up after 5 seconds wherever they are (Rocket.PreBeginPlay, Timer);
// single-player at their own speed, until they hit.
simulated function Rockets( Rocket R )
{
	if ( R.TimerRate>0 && (R.Class==class'Rocket' || R.Class==class'RocketWP') )
	{
		R.SetTimer( 0, false );
		R.speed = R.default.speed;
		R.Velocity = Normal(R.Velocity) * R.speed;
	}
}

// Gas (Cloud.Timer): deathmatch hurts every character within reach of a cloud, through
// walls and the one who let it out too, and lays a gas grenade's clouds still;
// single-player hurts what the cloud sees but its owner, and they drift. The cloud's
// damage beat is taken over here.
// ponytail: 128 clouds at once (a gas grenade makes ~14); more keep deathmatch's rule.
function Clouds( Cloud C )
{
	local int i;

	if ( C.TimerRate<=0 )
		return;
	for ( i=0; i<ArrayCount(Gas); i++ )
		if ( Gas[i]==None || Gas[i].bDeleteMe )
		{
			C.SetTimer( 0, false );
			Gas[i] = C;
			GasNext[i] = Level.TimeSeconds + C.damageInterval;
			if ( C.LifeSpan>15 )
				C.bFloating = true; // (only scattered gas lives that long: grenades, barrels)
			return;
		}
}

function GasDamage()
{
	local Cloud C;
	local Actor A;
	local int i;

	for ( i=0; i<ArrayCount(Gas); i++ )
	{
		C = Gas[i];
		if ( C==None || C.bDeleteMe || Level.TimeSeconds<GasNext[i] )
			continue;
		GasNext[i] += C.damageInterval;
		foreach C.VisibleActors( class'Actor', A, C.cloudRadius )
			if ( A!=C.Owner )
				A.TakeDamage( C.Damage, C.Instigator, A.Location, vect(0,0,0), C.damageType );
	}
}

// A weapon put away: deathmatch empties what was fired from its clip (a reload for free,
// DeusExWeapon state DownWeapon); single-player keeps it. Its count before the swap
// is put back once it is out of the hand.
// ponytail: players only; characters swap weapons rarely.
function Clips()
{
	local Pawn P;
	local DeusExWeapon W;
	local int i;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
	{
		if ( PlayerPawn(P)==None )
			continue;
		for ( i=0; i<ArrayCount(HeldBy)-1; i++ )
			if ( HeldBy[i]==P || HeldBy[i]==None )
				break;
		if ( HeldBy[i]!=P )
		{
			HeldBy[i] = P;
			Held[i] = None;
		}
		W = DeusExWeapon(P.Weapon);
		if ( Held[i]!=None && Held[i]!=W && Held[i].Owner==P && Held[i].ClipCount==0 && HeldClip[i]>0 )
			Held[i].ClipCount = HeldClip[i];
		if ( W==None || !W.IsInState('DownWeapon') )
		{
			Held[i] = W;
			if ( W!=None )
				HeldClip[i] = W.ClipCount;
		}
	}
}

// A body blown apart: deathmatch loses what it carried (DeusExCarcass.ExpelInventory
// returns); Revision's and HR's single-player drop it around (their bodies have
// bBleedHead; the other modes' lose it too). What bodies carry is noted every tick:
// what a body that is gone carried, now nobody's, is dropped where it was.
// ponytail: a body that goes otherwise (an unconscious MIB's self-destruct) drops it too.
function Bodies()
{
	local DeusExCarcass Body;
	local Inventory Item;
	local CoopGameInfo G;
	local CoopClient Helper;
	local vector At;
	local int i;

	for ( i=0; i<NumCarried; i++ )
	{
		Item = Carried[i];
		if ( Item==None || Item.bDeleteMe || Item.Owner!=None || Item.IsInState('Pickup') )
			continue;
		if ( Item.bIsAmmo || Item.IsA('DataVaultImage') )
		{
			Item.Destroy(); // (single-player too: only ammo in a weapon is kept)
			continue;
		}
		At = CarriedAt[i] + VRand() * 16;
		At.Z = CarriedAt[i].Z;
		Item.DropFrom( At );
		if ( DeusExWeapon(Item)!=None )
		{
			foreach AllActors( class'CoopClient', Helper )
				DeusExWeapon(Item).PickupAmmoCount = Helper.DroppedAmmo( DeusExWeapon(Item) );
		}
		Log( "RevNet: a body blown apart dropped" @ Item, 'RevNet' );
	}
	NumCarried = 0;
	foreach AllActors( class'DeusExCarcass', Body )
		if ( Body.Inventory!=None && Body.GetPropertyText("bBleedHead")!="" )
			for ( Item=Body.Inventory; Item!=None && NumCarried<ArrayCount(Carried); Item=Item.Inventory )
			{
				Carried[NumCarried] = Item;
				CarriedAt[NumCarried] = Body.Location;
				NumCarried++;
			}
}

// Swimming: deathmatch's speed (Human.mpWaterSpeed, twice with the aqualung) as a player
// enters water; single-player's is the player's own times the swimming skill. On every
// machine: a client moves its own player, and the host's value, the class's, is never
// sent (its own PreBeginPlay set deathmatch's). A client's skill manager finds no skills
// (0, also in deathmatch's code there): its skill is looked up.
simulated function Swimming( DeusExPlayer P )
{
	local float DM, M, Value;
	local SkillSwimming S;

	if ( Human(P)==None )
		return;
	if ( P.SkillSystem!=None )
		M = P.SkillSystem.GetSkillLevelValue( class'SkillSwimming' );
	DM = Human(P).default.mpWaterSpeed;
	if ( P.WaterSpeed!=DM && P.WaterSpeed!=DM * M && P.WaterSpeed!=DM * 2.0 * M )
		return;
	Value = M;
	if ( Value<=0 )
	{
		if ( SwimSkill==None || SwimSkill.bDeleteMe )
			foreach AllActors( class'SkillSwimming', S )
				if ( S.Owner==P || (S.Owner!=None && S.Owner.Owner==P) )
					SwimSkill = S;
		if ( SwimSkill!=None )
			Value = SwimSkill.LevelValues[SwimSkill.CurrentLevel];
	}
	if ( Value>0 )
		P.WaterSpeed = P.default.WaterSpeed * Value;
}

// (Client) this player's weapons as the host has them (CoopPlayerCore.ServerWeaponValues):
// asked for once each, and again when its mods change.
simulated function Weapons()
{
	local CoopPlayerCore Me;
	local Inventory Item;
	local DeusExWeapon W;
	local string Mods;
	local int i;

	Me = CoopPlayerCore(GetPlayerPawn());
	if ( Me==None )
		return;
	for ( Item=Me.Inventory; Item!=None; Item=Item.Inventory )
	{
		W = DeusExWeapon(Item);
		if ( W==None )
			continue;
		Mods = W.ModBaseAccuracy @ W.ModReloadCount @ W.ModAccurateRange @ W.ModReloadTime @ W.ModRecoilStrength;
		for ( i=0; i<ArrayCount(Asked)-1; i++ )
			if ( Asked[i]==W || Asked[i]==None )
				break;
		if ( Asked[i]==W && AskedMods[i]==Mods )
			continue;
		Asked[i] = W;
		AskedMods[i] = Mods;
		Me.ServerWeaponValues( W );
	}
}

defaultproperties
{
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
}
