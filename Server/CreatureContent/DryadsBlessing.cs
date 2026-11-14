// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class DryadsBlessing : TransientItem
{
    [Constructible]
    public DryadsBlessing() : base(0x021c, TimeSpan.FromDays(7))
    {
        Hue = 0x0488;
        Weight = 1.0;
        LootType = LootType.Blessed;
    }

    public override int LabelNumber => 1074345;

    public override bool Nontransferable => false;
}
