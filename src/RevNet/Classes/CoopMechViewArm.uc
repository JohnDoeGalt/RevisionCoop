//=============================================================================
// CoopMechViewArm.
//
// The Mech's own arms in its view with its arm cannon (StormArm, RevNetMech, built at
// install from the player's game: the body's own forearms and hands; CoopMechCannon).
// Drawn with the weapon on the player's machine, on the same spot and frame. Never drawn
// in the world, never replicated. (The blades' view carries its own arms: tools/blade_arms.py.)
//=============================================================================
class CoopMechViewArm extends Actor;

// Drawn with W (its view model, being drawn on its owner's screen): its spot, frame and look;
// Cloak a cloak's skin on every slot, else (None) the arms' own skins.
simulated function DrawWith( Canvas Canvas, Actor W, Mesh Arms, Texture Cloak )
{
	local int i;

	Mesh = Arms;
	SetLocation( W.Location );
	SetRotation( W.Rotation );
	DrawScale = W.DrawScale;
	AnimSequence = W.AnimSequence;
	AnimFrame = W.AnimFrame;
	Style = W.Style;
	ScaleGlow = W.ScaleGlow;
	AmbientGlow = W.AmbientGlow;
	for ( i=0; i<8; i++ )
		MultiSkins[i] = Cloak;
	bHidden = false;
	Canvas.DrawActor( Self, false );
	bHidden = true;
}

defaultproperties
{
	bHidden=True
	DrawType=DT_Mesh
	RemoteRole=ROLE_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
}
