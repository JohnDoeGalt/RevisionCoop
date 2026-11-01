//=============================================================================
// CoopExplosiveFacts.
//
// HCC.exe RevNet.CoopExplosiveFacts (in the dev folder, no game run): the game's own explosives' numbers as Revision
// has them (its DeusEx.u keeps no script text to export them from), and the Mech's FPV drones' beside them: damage,
// blast radius, the rings it hurts in (DeusExProjectile's Exploding: each ring 2 x Damage / rings, less with distance:
// about twice Damage at the middle), its damage type.
//=============================================================================
class CoopExplosiveFacts extends Commandlet;

function Fact( string What, class<DeusExProjectile> C )
{
	Log( What $ ":" @ C.Name @ "damage" @ C.default.Damage @ "blast radius" @ int(C.default.blastRadius)
		@ "rings" @ C.default.gradualHurtSteps @ "type" @ C.default.damageType @ "push" @ C.default.MomentumTransfer );
}

// A character's health (what a blast has to beat): its total, its torso's, its head's.
function Toughness( class<ScriptedPawn> C )
{
	Log( "health:" @ C.Name @ C.default.Health @ "torso" @ C.default.HealthTorso @ "head" @ C.default.HealthHead
		@ "collision radius" @ int(C.default.CollisionRadius) );
}

// Each class named (Package.Class, spaces between) that blows up: a projectile with a blast, an explosive decoration;
// its numbers, its mesh and size on screen (DrawScale).
function Survey( string Parms )
{
	local string Name;
	local int i;
	local class<Actor> C;
	local class<DeusExProjectile> P;
	local class<DeusExDecoration> D;

	while ( Parms!="" )
	{
		i = InStr( Parms, " " );
		if ( i<0 )
			i = Len( Parms );
		Name = Left( Parms, i );
		Parms = Mid( Parms, i + 1 );
		C = class<Actor>( DynamicLoadObject( Name, class'Class', true ) );
		P = class<DeusExProjectile>(C);
		D = class<DeusExDecoration>(C);
		if ( P!=None && P.default.blastRadius>0 )
			Log( "explosive: projectile" @ Name @ "damage" @ P.default.Damage @ "radius" @ int(P.default.blastRadius) @ "type"
				@ P.default.damageType @ "mesh" @ P.default.Mesh @ "scale" @ P.default.DrawScale @ "sound" @ P.default.ImpactSound
				@ P.default.MiscSound @ "role" @ P.default.RemoteRole );
		else if ( D!=None && D.default.bExplosive )
			Log( "explosive: decoration" @ Name @ "damage" @ D.default.explosionDamage @ "radius" @ int(D.default.explosionRadius)
				@ "type Exploded health" @ D.default.HitPoints @ "mesh" @ D.default.Mesh );
		else if ( C!=None && C.default.Mesh!=None && C.default.DrawType==DT_Mesh )     // a mesh actor's look (concept art: tools/ue1map.py, flykit_swarm.py)
			Log( "look:" @ Name @ "mesh" @ C.default.Mesh @ "scale" @ C.default.DrawScale @ "radius" @ C.default.CollisionRadius
				@ "height" @ C.default.CollisionHeight @ "skins" @ C.default.MultiSkins[0] @ C.default.MultiSkins[1]
				@ C.default.MultiSkins[2] @ C.default.MultiSkins[3] @ C.default.MultiSkins[4] @ C.default.MultiSkins[5]
				@ C.default.MultiSkins[6] @ C.default.MultiSkins[7] @ "texture" @ C.default.Texture @ "skin" @ C.default.Skin
				@ "hidden" @ C.default.bHidden @ "role" @ C.default.RemoteRole );
	}
}

event int Main( string Parms )
{
	local class<CoopMechAugDrones> M;

	if ( Parms!="" )
	{
		Survey( Parms );
		return 0;
	}

	Toughness( class'Terrorist' );
	Toughness( class'UNATCOTroop' );
	Toughness( class'MJ12Troop' );
	Toughness( class'MJ12Commando' );
	Toughness( class'Doberman' );
	Toughness( class'Greasel' );
	Toughness( class'Karkian' );
	Toughness( class'SecurityBot2' );
	Toughness( class'MilitaryBot' );

	Fact( "GEP gun rocket", class'Rocket' );
	Fact( "GEP gun WP rocket", class'RocketWP' );
	Fact( "assault rifle 20 mm HE", class'HECannister20mm' );
	Fact( "LAM", class'LAM' );
	Fact( "gas grenade", class'GasGrenade' );
	Fact( "EMP grenade", class'EMPGrenade' );
	Fact( "scramble grenade", class'NanoVirusGrenade' );
	Fact( "Spy Drone", class'SpyDrone' );
	Fact( "FPV drone flown", class'CoopFPV' );
	Fact( "FPV drone guided", class'CoopFPVGuided' );
	M = class'CoopMechAugDrones';
	Log( "FPV drones (CoopMechAugDrones): damage by level" @ int(M.default.LevelValues[0]) @ int(M.default.LevelValues[1])
		@ int(M.default.LevelValues[2]) @ int(M.default.LevelValues[3]) @ "blast radius" @ int(M.default.Blast) );
	return 0;
}

defaultproperties
{
	LogToStdout=True
	IsServer=False
	IsClient=False
	IsEditor=False
	ShowBanner=False
}
