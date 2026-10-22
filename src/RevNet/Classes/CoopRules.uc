//=============================================================================
// CoopRules.
//
// Single-player values in a network game, for code that runs on the host and on
// clients. The DeusEx code copies deathmatch values (mp...) over a weapon's,
// projectile's or ammo's own values when the game isn't standalone; patching the
// class defaults of those mp values to the single-player ones (console "set",
// one class at a time: subclasses keep their own defaults) makes the copy change
// nothing. Skills and augs copy them per class too: SinglePlayerValues puts the
// defaults back.
//=============================================================================
class CoopRules extends Object;

var name TempName;

// A string as a name (script has no conversion; a name property imports one).
static function name NameOf( string S )
{
	local CoopRules R;

	R = new class'CoopRules';
	R.SetPropertyText( "TempName", S );
	return R.TempName;
}

// mp value <- single-player value, for any class that has both.
static function PatchClass( Actor Ctx, class<Actor> C )
{
	local string Name;

	if ( C==None )
		return;
	Name = string(C.Name);
	CopyDefault( Ctx, Name, "mpHitDamage", "HitDamage" );
	CopyDefault( Ctx, Name, "mpBaseAccuracy", "BaseAccuracy" );
	CopyDefault( Ctx, Name, "mpReloadTime", "ReloadTime" );
	CopyDefault( Ctx, Name, "mpAccurateRange", "AccurateRange" );
	CopyDefault( Ctx, Name, "mpMaxRange", "MaxRange" );
	CopyDefault( Ctx, Name, "mpReloadCount", "ReloadCount" );
	CopyDefault( Ctx, Name, "mpPickupAmmoCount", "PickupAmmoCount" );
	CopyDefault( Ctx, Name, "mpBurnTime", "BurnTime" );
	CopyDefault( Ctx, Name, "mpBurnDamage", "BurnDamage" );
	CopyDefault( Ctx, Name, "mpDamage", "Damage" );
	CopyDefault( Ctx, Name, "mpBlastRadius", "blastRadius" );
	CopyDefault( Ctx, Name, "mpProxRadius", "proxRadius" );
	CopyDefault( Ctx, Name, "mpFuselength", "fuseLength" );
	CopyDefault( Ctx, Name, "mpLAMDamage", "Damage" );
	CopyDefault( Ctx, Name, "mpEMPDamage", "Damage" );
	CopyDefault( Ctx, Name, "mpGasDamage", "Damage" );
	CopyDefault( Ctx, Name, "mpExplodeDamage", "Damage" );
	CopyDefault( Ctx, Name, "MPMaxAmmo", "MaxAmmo" );
}

// A weapon class with what it fires and loads.
static function PatchWeapon( Actor Ctx, class<DeusExWeapon> W )
{
	local int i;

	PatchClass( Ctx, W );
	PatchClass( Ctx, W.default.ProjectileClass );
	PatchClass( Ctx, W.default.AltProjectileClass );
	PatchClass( Ctx, W.default.AmmoName );
	for ( i=0; i<ArrayCount(W.default.AmmoNames); i++ )
		PatchClass( Ctx, W.default.AmmoNames[i] );
	// What its other ammo fires (WP rockets, 20mm, plain and flare darts).
	for ( i=0; i<ArrayCount(W.default.ProjectileNames); i++ )
		PatchClass( Ctx, W.default.ProjectileNames[i] );
}

static function CopyDefault( Actor Ctx, string ClassName, string MPField, string SPField )
{
	local string V;

	// An unknown class or field answers with a message (words), a value has no spaces.
	V = Ctx.ConsoleCommand( "get" @ ClassName @ SPField );
	if ( V=="" || InStr( V, " " )>=0 )
		return;
	if ( InStr( Ctx.ConsoleCommand( "get" @ ClassName @ MPField ), " " )>=0 )
		return;
	Ctx.ConsoleCommand( "set" @ ClassName @ MPField @ V );
}

// Skills and augs: the per-level values, costs, energy use and body slot the
// deathmatch code set when they were spawned.
static function SinglePlayerValues( Actor A )
{
	local Skill S;
	local Augmentation Aug;
	local int i;

	S = Skill(A);
	if ( S!=None )
	{
		for ( i=0; i<ArrayCount(S.Cost); i++ )
			S.Cost[i] = S.default.Cost[i];
		for ( i=0; i<ArrayCount(S.LevelValues); i++ )
			S.LevelValues[i] = S.default.LevelValues[i];
		return;
	}
	Aug = Augmentation(A);
	if ( Aug!=None )
	{
		for ( i=0; i<ArrayCount(Aug.LevelValues); i++ )
			Aug.LevelValues[i] = Aug.default.LevelValues[i];
		Aug.EnergyRate = Aug.default.EnergyRate;
		Aug.AugmentationLocation = Aug.default.AugmentationLocation;
		// EMP shield, auto-counter: passive in single-player, a draining switch in
		// deathmatch. One already installed is switched on, as its install does.
		Aug.bAlwaysActive = Aug.default.bAlwaysActive;
		if ( Aug.bAlwaysActive && Aug.bHasIt && Aug.Role==ROLE_Authority && Aug.Player!=None && Aug.IsInState('Inactive') )
			Aug.Activate();
		return;
	}
	SinglePlayerItem( A );
}

// Weapons, ammo and pickups spawned under deathmatch rules (CoopGameInfo.IsRelevant),
// on their next tick: what their own code hard-codes for deathmatch, not an mp value.
// A travelling item's travel values are back by then (the same tick): only deathmatch's
// values are changed, and what a pickup lying about holds.
static function SinglePlayerItem( Actor A )
{
	local DeusExWeapon W;
	local DeusExPickup P;
	local Ammo Am;

	W = DeusExWeapon(A);
	if ( W!=None )
	{
		// Deathmatch leaves a weapon where it was taken (Weapon.HandlePickupQuery): taking
		// one of a kind the player has gives its ammo and leaves it there for more.
		W.bWeaponStay = W.default.bWeaponStay;
		// The sniper rifle: one round a clip, reloaded in its shot time.
		if ( W.IsA('WeaponRifle') && W.ReloadCount==1 && W.default.ReloadCount>1 )
		{
			W.ReloadCount = W.default.ReloadCount;
			W.ReloadTime = W.default.ReloadTime;
			W.bHasMuzzleFlash = W.default.bHasMuzzleFlash;
		}
		// The assault rifle's fixed recoil (a recoil mod's change is kept).
		if ( W.IsA('WeaponAssaultGun') && W.ModRecoilStrength==0 )
			W.recoilStrength = W.default.recoilStrength;
		// Rounds in a sawed-off (12) or shurikens (7) lying about.
		if ( W.Owner==None && (W.IsA('WeaponSawedOffShotgun') || W.IsA('WeaponShuriken')) )
			W.PickupAmmoCount = W.default.PickupAmmoCount;
		return;
	}
	// Medkits, lockpicks, multitools, bioelectric cells: deathmatch stacks 5 (the heavy
	// items setting's 1 stays).
	P = DeusExPickup(A);
	if ( P!=None )
	{
		if ( P.MaxCopies==5 && P.default.MaxCopies>5 )
			P.MaxCopies = P.default.MaxCopies;
		return;
	}
	// Rounds in a box lying about (10mm 9, darts 6, shurikens 7).
	Am = Ammo(A);
	if ( Am!=None && Am.Owner==None && (Am.IsA('Ammo10mm') || Am.IsA('AmmoDart') || Am.IsA('AmmoShuriken')) )
		Am.AmmoAmount = Am.default.AmmoAmount;
}

// A bioelectric cell's recharge: deathmatch's (50) replaces the one for the game's
// difficulty (Revision and HR) or its own.
static function int RechargeAmount( BioelectricCell Cell, int Difficulty )
{
	local string S;

	S = Cell.GetPropertyText( "rechargeAmountDiff" $ Difficulty );
	if ( S=="" )
		S = Cell.GetPropertyText( "rechargeAmount" );
	return int(S);
	// (By name: Biomod's is an array, one per medicine level. Read as Revision's one
	// int, the whole array was copied into it, over what was next to it: memory gone
	// wrong, the host crashed at the next garbage collection.)
}
