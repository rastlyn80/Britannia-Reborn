// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class VoidCore : Item, ICommodity
{
    [Constructible]
    public VoidCore() : this(1)
    {
    }

    [Constructible]
    public VoidCore(int amount) : base(0x5728)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113334;
    public override double DefaultWeight => 0.1;
    int ICommodity.DescriptionNumber => LabelNumber;
    bool ICommodity.IsDeedable => true;
}

[SerializationGenerator(0)]
public partial class VoidOrb : Item, ICommodity
{
    [Constructible]
    public VoidOrb() : this(1)
    {
    }

    [Constructible]
    public VoidOrb(int amount) : base(0x573E)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113354;
    int ICommodity.DescriptionNumber => LabelNumber;
    bool ICommodity.IsDeedable => true;
}

[SerializationGenerator(0)]
public partial class AncientPotteryFragments : Item
{
    [Constructible]
    public AncientPotteryFragments() : base(0x2243)
    {
        Hue = 2108;
    }

    public override int LabelNumber => 1112990;
}
