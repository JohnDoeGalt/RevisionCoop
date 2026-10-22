//=============================================================================
// CoopWitness.
//
// An invisible pawn on the host told of every death (Pawn.Died calls Killed on
// every pawn): CoopWorld.Killed.
//=============================================================================
class CoopWitness extends CoopNobody;

var CoopWorld World;

function Killed( pawn Killer, pawn Other, name damageType )
{
	if ( World!=None )
		World.Killed( Killer, Other, damageType );
}
