//=============================================================================
// CoopLightAugArms.
//
// Arms: the cybernetic arm prosthesis (Mankind Divided's), and the blades folded
// in it (CoopMechBlade: LevelValues a cut, CoopLightMechPlayer.RefreshModules).
// Level 2: heavy lifting; level 3: a character that has noticed nobody dies in
// one cut (a takedown); level 4: punches through doors and weapon handling (40%
// less recoil). Every Light Mech has it. It also puts the weapon handling and
// Focus Enhancement's aim on the weapon in hand, four times a second (Feel).
//=============================================================================
class CoopLightAugArms extends CoopLightAug;

var DeusExWeapon Felt;          // the weapon in hand with its own aim kept ...
var float FeltAccuracy, FeltRecoil;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	SetTimer( 0.25, true );
}

function Timer()
{
	Feel();
}

function Feel()
{
	local CoopLightAugFocus Focus;
	local DeusExWeapon W;
	local float Acc, Rec;

	if ( Player==None || Role<ROLE_Authority )
		return;
	W = DeusExWeapon(Player.Weapon);
	if ( W!=Felt )
	{
		Unfeel();
		Felt = W;
		if ( W!=None )
		{
			FeltAccuracy = W.BaseAccuracy;
			FeltRecoil = W.recoilStrength;
		}
	}
	if ( Felt==None )
		return;
	Acc = FeltAccuracy;
	Rec = FeltRecoil;
	if ( bHasIt && CurrentLevel>=3 )
		Rec *= 0.6;
	Focus = CoopLightAugFocus(Find( Player, class'CoopLightAugFocus' ));
	if ( Focus!=None && Focus.bHasIt && Focus.bIsActive )
	{
		Acc = 0;
		if ( Focus.CurrentLevel>=1 )
			Rec = 0;
	}
	if ( Felt.BaseAccuracy!=Acc || Felt.recoilStrength!=Rec )
	{
		Felt.BaseAccuracy = Acc;
		Felt.recoilStrength = Rec;
		if ( CoopPlayerCore(Player)!=None )
			CoopPlayerCore(Player).ServerWeaponValues( Felt );
	}
}

// The weapon put away keeps its own aim.
function Unfeel()
{
	if ( Felt!=None && !Felt.bDeleteMe && (Felt.BaseAccuracy!=FeltAccuracy || Felt.recoilStrength!=FeltRecoil) )
	{
		Felt.BaseAccuracy = FeltAccuracy;
		Felt.recoilStrength = FeltRecoil;
		if ( CoopPlayerCore(Player)!=None )
			CoopPlayerCore(Player).ServerWeaponValues( Felt );
	}
	Felt = None;
}

function Destroyed()
{
	Unfeel();
	Super.Destroyed();
}

defaultproperties
{
	bStarter=True
	LevelValues(0)=16
	LevelValues(1)=22
	LevelValues(2)=28
	LevelValues(3)=34
	TreeName="Arms"
	AugmentationName="Cybernetic Arms"
	Description="Full prosthetic arms with blades of hardened alloy folded in the forearms, and the strength to use them."
	LevelText(0)="The blades: 16 a cut."
	LevelText(1)="22 a cut; heavy lifting (twice the weight)."
	LevelText(2)="28 a cut; takedowns: anyone who has noticed nobody dies in one cut."
	LevelText(3)="34 a cut; punches through doors; weapon handling: 40% less recoil."
	Icon=Texture'DeusExUI.UserInterface.AugIconCombat'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconCombat_Small'
}
