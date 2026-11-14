// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class GreenGoblinCaptain : BaseCreature
{
    [Constructible]
    public GreenGoblinCaptain() : base(AIType.AI_Melee, FightMode.None, 2)
    {
        Body = 723;
        CantWalk = true;
        NoKillAwards = true;
        SetHits(1);
        ScheduleFall();
    }

    public override string DefaultName => "Green Goblin Captain";
    public override string CorpseName => "a green goblin captain corpse";
    public override bool IsInvulnerable => true;
    public override bool CanBeDamaged() => _falling;

    [AfterDeserialization]
    private void ScheduleFall() => Timer.DelayCall(TimeSpan.FromMilliseconds(150), Fall);

    private bool _falling;

    private void Fall()
    {
        if (Deleted)
        {
            return;
        }

        _falling = true;
        base.Kill();
        if (!Deleted)
        {
            Delete();
        }
    }
}
