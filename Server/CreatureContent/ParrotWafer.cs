// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.Craft;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class ParrotWafer : Item
{
    [Constructible]
    public ParrotWafer() : base(0x2FD6)
    {
        Hue = 0x38;
        Stackable = true;
    }

    public override int LabelNumber => 1072904;

    public static void Configure() => EventSink.ServerStarted += RegisterRecipe;

    private static void RegisterRecipe()
    {
        if (Core.ML && DefCooking.CraftSystem is { } cooking)
        {
            var recipe = cooking.AddCraft(typeof(ParrotWafer), 1044496, 1032246, 37.5, 87.5,
                typeof(Dough), 1044469, 1, 1044253);
            cooking.AddRes(recipe, typeof(JarHoney), 1044472, 1, 1044253);
            cooking.AddRes(recipe, typeof(RawFishSteak), 1044476, 10, 1044253);
            cooking.SetNeededExpansion(recipe, Expansion.ML);
        }
    }
}
