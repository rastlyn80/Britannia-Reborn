// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class ShroudOfTheCondemned : HoodedShroudOfShadows
{
    [Constructible]
    public ShroudOfTheCondemned()
    {
        LootType = LootType.Regular;
        Attributes.BonusInt = 5;
        Attributes.BonusHits = 3;
    }

    public override string DefaultName => "Shroud of the Condemned";
    public override int LabelNumber => 1113703;
}
