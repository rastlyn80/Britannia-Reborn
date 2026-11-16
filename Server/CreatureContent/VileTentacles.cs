// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class VileTentacles : Item, ICommodity
{
    [Constructible]
    public VileTentacles(int amount = 1) : base(0x5727)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113333;
    public override double DefaultWeight => 0.1;
    int ICommodity.DescriptionNumber => LabelNumber;
    bool ICommodity.IsDeedable => true;
}
