// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class JaacarRewardBox : WoodenBox
{
    public const int RecipeId = 500;

    [Constructible]
    public JaacarRewardBox()
    {
        Hue = 1266;
        DropItem(new RecipeScroll(RecipeId));
    }

    public override string DefaultName => "Jaacar Reward Box";
}

[SerializationGenerator(0)]
public sealed partial class BowlOfRotwormStew : Food
{
    [Constructible]
    public BowlOfRotwormStew() : base(0x2DBA)
    {
        Stackable = true;
        FillFactor = 2;
    }

    public override int LabelNumber => 1031706;
}
