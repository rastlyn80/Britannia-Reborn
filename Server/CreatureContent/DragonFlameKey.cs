// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class DragonFlameKey : TransientItem
{
    [Constructible]
    public DragonFlameKey() : base(0x2002, TimeSpan.FromDays(7))
    {
        Hue = 42;
        LootType = LootType.Blessed;
    }

    public override double DefaultWeight => 2.0;
    public override int LabelNumber => 1074343;
    public override bool Nontransferable => false;
}
