// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class SerpentFangKey : TransientItem
{
    [Constructible]
    public SerpentFangKey() : base(0x2002, TimeSpan.FromDays(7))
    {
        Hue = 53;
        LootType = LootType.Blessed;
    }

    public override double DefaultWeight => 2.0;
    public override int LabelNumber => 1074341;
    public override bool Nontransferable => false;
}
