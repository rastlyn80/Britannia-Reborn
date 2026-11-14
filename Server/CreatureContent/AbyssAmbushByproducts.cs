// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class KepetchWax : Item
{
    [Constructible]
    public KepetchWax() : base(0x5745) => Weight = 1;

    public override int LabelNumber => 1112412;
}

[SerializationGenerator(0)]
public sealed partial class SearedFireAntGoo : Item
{
    [Constructible]
    public SearedFireAntGoo() : base(0x0976) => Weight = 1;

    public override int LabelNumber => 1112902;
}

[SerializationGenerator(0)]
public sealed partial class KepetchFur : Item
{
    [Constructible]
    public KepetchFur() : base(0x1875)
    {
        Stackable = true;
        Amount = 15;
        Hue = 343;
    }

    internal static void Gather(Mobile from, ref bool gathered, Server.Mobiles.BaseCreature source)
    {
        if (gathered)
        {
            from.SendLocalizedMessage(1112358);
            return;
        }

        var fur = new KepetchFur();
        if (from.Backpack?.TryDropItem(from, fur, false) != true)
        {
            fur.Delete();
            from.SendLocalizedMessage(1112359);
            return;
        }

        gathered = true;
        source.MarkDirty();
        from.SendLocalizedMessage(1112360);
    }
}
