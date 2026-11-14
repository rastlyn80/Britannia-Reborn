// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class BouraFur : Item
{
    [Constructible]
    public BouraFur(int hue = 0, int amount = 1) : base(0x1875)
    {
        Hue = hue;
        Stackable = true;
        Amount = amount;
    }
}

[SerializationGenerator(0)]
public partial class BouraSkin : Item
{
    [Constructible]
    public BouraSkin() : base(0x11F4)
    {
        LootType = LootType.Blessed;
        Weight = 1.0;
        Hue = 0x292;
    }

    public override int LabelNumber => 1112900;
}
