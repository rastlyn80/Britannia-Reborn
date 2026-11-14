// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class ReflectiveWolfEye : Item, ICommodity
{
    [Constructible]
    public ReflectiveWolfEye(int amount = 1) : base(0x5749)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113362;
    int ICommodity.DescriptionNumber => LabelNumber;
    bool ICommodity.IsDeedable => true;
}
