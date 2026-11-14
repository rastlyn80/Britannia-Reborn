// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class Sutek : BaseCreature
{
    [Constructible]
    public Sutek() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Title = "the Mage";
        Body = 400;
        Hue = 0x840D;
        HairItemID = 0x203C;
        HairHue = 0x835;
        FacialHairItemID = 0x2040;
        FacialHairHue = 0x835;
        InitStats(100, 100, 25);
        AddItem(new Sandals());
        AddItem(new TattsukeHakama(0x528));
        AddItem(new WizardsHat(0x528));
        AddItem(new Tunic(0x528));
    }

    public override string DefaultName => "Sutek";
    public override bool IsInvulnerable => true;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Map == Map && from.InRange(this, 2) && from.InLOS(this))
        {
            base.OnDoubleClick(from);
        }
        else
        {
            from.SendLocalizedMessage(1019045);
        }
    }
}

[SerializationGenerator(0)]
public partial class SutekTrainingConstruct : Mobile
{
    private TimerExecutionToken _departure;

    internal SutekTrainingConstruct(int body, string name)
    {
        Body = body;
        Name = name;
        Blessed = true;
        Frozen = true;
        Timer.StartTimer(TimeSpan.FromSeconds(5), Delete, out _departure);
    }

    public override bool CanBeDamaged() => false;

    public override void OnDelete()
    {
        _departure.Cancel();
        base.OnDelete();
    }

    [AfterDeserialization]
    private void RemoveTransientConstruct() => Timer.StartTimer(TimeSpan.Zero, Delete, out _departure);
}
