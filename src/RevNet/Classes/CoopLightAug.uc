//=============================================================================
// CoopLightAug.
//
// A Light Mech's module (CoopLightMechPlayer, docs/LIGHT_MECH_CLASS.md): one of
// Adam Jensen's augmentations from Deus Ex: Mankind Divided, its upgrades as the
// levels. Bought with Praxis. A one-shot module (Shot > 0: Typhoon, Tesla and the
// like) fires once on each press of its key, spending Shot energy, and is never
// "on"; the others switch on and off and drain energy while on, or always work.
//=============================================================================
class CoopLightAug extends CoopMechAug
	abstract;

var float Shot;                 // energy one use spends (a one-shot module)
var int ShotLevel;              // the level (0..3) its key first fires at (Icarus Dash: 2)
var Pawn Hit[4];                // (Aim) the characters found, nearest the crosshair first
var int NumHit;
var localized string NoEnergyText, NoTargetText, NotYetText;

function Activate()
{
	if ( Shot<=0 )
	{
		Super.Activate();
		return;
	}
	if ( !bHasIt || Player==None )
		return;
	if ( CurrentLevel<ShotLevel )
	{
		Player.ClientMessage( Fill( NotYetText, AugmentationName, string(ShotLevel + 1) ) );
		return;
	}
	if ( Player.Energy<ShotCost() )
	{
		Player.ClientMessage( Fill( NoEnergyText, AugmentationName ) );
		return;
	}
	if ( !Fire() )
		return;
	Player.Energy = FMax( 0, Player.Energy - ShotCost() );
	Player.PlaySound( ActivateSound, SLOT_None );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "fired" @ Class.Name @ "level" @ CurrentLevel + 1 @ "energy left" @ int(Player.Energy), 'RevNet' );
}

simulated function float ShotCost()
{
	return Shot;
}

// The use itself (a one-shot module): true if it did something (only then is energy spent).
function bool Fire()
{
	return false;
}

static function bool Hostile( Pawn P, Pawn Me )
{
	return ScriptedPawn(P)!=None && P.Health>0 && !P.bDeleteMe && ScriptedPawn(P).GetPawnAllianceType( Me )==ALLIANCE_Hostile;
}

simulated function vector Eye()
{
	return Player.Location + vect(0,0,1) * Player.BaseEyeHeight;
}

// Up to Most hostile characters within Range of the eye and Cone degrees of the crosshair, in
// sight: Hit[0..NumHit-1], nearest the crosshair first.
function Aim( float Range, float Cone, int Most )
{
	local ScriptedPawn SP;
	local vector From, Dir;
	local float Dots[4], d;
	local int i, j;

	NumHit = 0;
	Most = Min( Most, ArrayCount(Hit) );
	From = Eye();
	Dir = vector(Player.ViewRotation);
	foreach Player.RadiusActors( class'ScriptedPawn', SP, Range, From )
	{
		if ( !Hostile( SP, Player ) )
			continue;
		d = Normal(SP.Location - From) dot Dir;
		if ( d<Cos( Cone * Pi / 180 ) || !Player.FastTrace( SP.Location, From ) )
			continue;
		i = 0;
		while ( i<NumHit && Dots[i]>=d )
			i++;
		if ( i>=Most )
			continue;
		for ( j=Min( NumHit, Most - 1 ); j>i; j-- )
		{
			Hit[j] = Hit[j - 1];
			Dots[j] = Dots[j - 1];
		}
		Hit[i] = SP;
		Dots[i] = d;
		NumHit = Min( NumHit + 1, Most );
	}
}

// A burst every player sees (effects the host spawns never reach clients: ClientBlast).
function Blast( vector At, float Size )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None )
			CoopPlayerCore(P).ClientBlast( At, Size );
	if ( Level.NetMode!=NM_DedicatedServer )
	{
		if ( Size<1 )
			Spawn( class'ExplosionSmall',,, At );
		else
			Spawn( class'ExplosionMedium',,, At );
	}
}

defaultproperties
{
	Cost(0)=2
	Cost(1)=1
	Cost(2)=2
	Cost(3)=2
	CostLabel="Next level: %d Praxis."
	NoEnergyText="Not enough energy for %s."
	NoTargetText="%s: nothing in reach."
	NotYetText="%s: from level %s."
}
