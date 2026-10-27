//=============================================================================
// CoopMechBlade.
//
// The Mech's arm blades (CoopMechPlayer): heavy, fast melee built into the arm.
// The combat knife's model in a mechanical hand; part of the body, never left
// lying about.
//=============================================================================
class CoopMechBlade extends WeaponCombatKnife;

var Texture MechHandTex;

function texture GetWeaponHandTex()
{
	if ( PlayerCloakDetected() )
		return Texture'WhiteStatic';
	return MechHandTex;
}

// Its damage is the Arm Blades module's (CoopMechPlayer.RefreshModules). From its
// level 3 a character that has noticed nobody dies in one cut; Servo Arms hit doors
// harder.
simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z )
{
	local int Damage;
	local float Mult;

	Mult = 1.0;
	if ( Role==ROLE_Authority && Pawn(Owner)!=None )
	{
		if ( ScriptedPawn(Other)!=None && ScriptedPawn(Other).Enemy==None
			&& class'CoopMechAug'.static.LevelOf( Pawn(Owner), class'CoopMechAugBlades' )>=2 )
			Mult = 10;
		else if ( DeusExMover(Other)!=None )
			Mult = class'CoopMechAug'.static.ValueOf( Pawn(Owner), class'CoopMechAugServo', 1.0 );
	}
	Damage = HitDamage;
	HitDamage = int(HitDamage * Mult);
	Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z );
	HitDamage = Damage;
}

// Others see the blades out of its forearms (CoopMechParts), not a knife in its hand: no
// third-person model at all. The engine draws a pawn's selected item's ThirdPersonMesh at its
// hand, and the "invisible" InvisibleWeapon is drawn too, as pale scraps floating there.
function bool Facelift( bool bOn )
{
	local bool ret;

	ret = Super.Facelift( bOn );
	ThirdPersonMesh = default.ThirdPersonMesh;
	return ret;
}

function DropFrom( vector StartLocation )
{
	if ( CoopMechPlayer(Owner)!=None && Owner.bDeleteMe==false && Pawn(Owner).Health>0 )
		return;
	Destroy();
}

defaultproperties
{
	MechHandTex=Texture'DeusExCharacters.Skins.MilitaryBotTex1'
	HitDamage=16
	ThirdPersonMesh=None
	ItemName="Arm Blades"
	ItemArticle="the"
	beltDescription="BLADES"
	Description="Blades of hardened alloy folded into both forearms, driven by the arm's own hydraulics. Crude, loud and very effective."
}
