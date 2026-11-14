// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.MLQuests;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("Sarakki (Britain)")]
[SerializationGenerator(0)]
public partial class Sarakki : BaseCreature
{
    [Constructible]
    public Sarakki() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Title = "the notary";
        Race = Race.Human;
        Female = true;
        Body = 401;
        Hue = 0x841E;
        HairItemID = 0x2049;
        HairHue = 0x1BB;
        InitStats(100, 100, 25);
        AddItem(new Backpack());
        AddItem(new Shoes(0x740));
        AddItem(new FancyShirt(0x72C));
        AddItem(new Skirt(0x53C));
    }

    public override string DefaultName => "Sarakki";
    public override bool IsInvulnerable => true;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Map != Map || !from.InRange(this, 2) || !from.InLOS(this))
        {
            from.SendLocalizedMessage(1019045);
            return;
        }

        base.OnDoubleClick(from);
    }
}
