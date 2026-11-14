// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class RawRotwormMeat : Item
{
    [Constructible]
    public RawRotwormMeat(int amount = 1) : base(0x2DB9)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1031705;
    public override double DefaultWeight => 0.1;
}
