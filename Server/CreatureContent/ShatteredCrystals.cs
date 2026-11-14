// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class ShatteredCrystals : Item
{
    [Constructible]
    public ShatteredCrystals() : base(0x223F)
    {
        Hue = 0x47E;
        Weight = 1.0;
    }

    public override int LabelNumber => 1074266;
}
