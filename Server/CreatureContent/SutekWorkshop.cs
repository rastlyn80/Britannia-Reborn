// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Commands;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;
using Server.Mobiles;

namespace Server;

public static class SutekWorkshop
{
    public const string RegionName = "Sutek the Mage";
    public static readonly Point3D Home = new(917, 594, -14);

    private readonly record struct Ingredient(Point3D Location, int Graphic, int Label, int Hue);

    // Multiple workshop props can satisfy the same requested ingredient.
    private static readonly Ingredient[] _props =
    [
        new(new(921, 598, -8), 0x1BD3, 1023578, 0),
        new(new(918, 591, -14), 0x1BD6, 1027125, 0),
        new(new(917, 589, -5), 0x1F1C, 1112811, 0),
        new(new(926, 597, -4), 0x1F19, 1112811, 0),
        new(new(926, 593, -8), 0x183B, 1023852, 0),
        new(new(931, 601, -14), 0x1DB7, 1011228, 0),
        new(new(931, 601, -12), 0x1DB7, 1011228, 0),
        new(new(932, 600, -14), 0x1EB2, 1027857, 0),
        new(new(933, 600, -14), 0x1EB3, 1027857, 0),
        new(new(925, 605, -14), 0x21FC, 1023786, 0),
        new(new(926, 599, -5), 0x2D92, 1031066, 0),
        new(new(926, 589, -3), 0x2D92, 1112327, 0x835),
        new(new(916, 602, -4), 0x2D87, 1055029, 0x481),
        new(new(911, 589, -13), 0x14F8, 1020934, 0),
        new(new(919, 581, -14), 0x14FA, 1020934, 0),
        new(new(910, 590, -13), 0x1BDF, 1021217, 0),
        new(new(916, 609, -14), 0x1BE1, 1021217, 0),
        new(new(939, 593, -14), 0x1BDE, 1021217, 0),
        new(new(911, 602, -14), 0x1BE2, 1021217, 0),
        new(new(916, 601, -6), 0x1841, 1023853, 0),
        new(new(921, 588, -8), 0x26B5, 1029905, 0),
        new(new(923, 603, -6), 0x26B2, 1029905, 0),
        new(new(927, 605, -14), 0x177A, 1112813, 0),
        new(new(931, 583, -14), 0x1776, 1112866, 0),
        new(new(926, 600, -6), 0x1425, 1025154, 0),
        new(new(925, 603, -8), 0x1426, 1025154, 0),
        new(new(928, 595, -14), 0x3022, 1112818, 0),
        new(new(928, 596, -14), 0x3022, 1112818, 0),
        new(new(939, 592, -14), 0x1BDB, 1021189, 0),
        new(new(928, 590, -14), 0x1BDC, 1021189, 0),
        new(new(911, 591, -14), 0x1BD8, 1021189, 0),
        new(new(916, 598, -14), 0x1BD9, 1021189, 0),
        new(new(922, 577, -14), 0x1772, 1112814, 0),
        new(new(925, 603, -8), 0x183E, 1023851, 0),
        new(new(921, 597, -10), 0x1839, 1023853, 0),
        new(new(921, 596, -7), 0x1844, 1023848, 0),
        new(new(920, 597, -8), 0x1051, 1024177, 0),
        new(new(916, 600, -6), 0x142B, 1025162, 0),
        new(new(926, 595, -7), 0x142A, 1025162, 0),
        new(new(924, 588, -14), 0x1078, 1024216, 0),
        new(new(910, 589, -8), 0x1879, 1026265, 0),
        new(new(910, 589, -13), 0x1878, 1026264, 0),
        new(new(910, 589, -10), 0x1877, 1026263, 0),
        new(new(910, 589, -6), 0x1876, 1026262, 0),
        new(new(911, 588, -14), 0x1BFA, 1027158, 0),
        new(new(928, 603, -14), 0x1BF7, 1027158, 0),
        new(new(914, 581, -14), 0x1BEE, 1027146, 0),
        new(new(922, 594, -14), 0x1BEB, 1027146, 0),
        new(new(914, 580, -14), 0x1BE5, 1027140, 0),
        new(new(916, 590, -11), 0x1BE8, 1027140, 0),
        new(new(915, 580, -14), 0x1BF1, 1027152, 0),
        new(new(912, 602, -15), 0x1BF4, 1027152, 0),
        new(new(916, 601, -8), 0x098D, 1077482, 0),
        new(new(920, 597, -6), 0x0B48, 1112815, 0x497),
        new(new(926, 602, -6), 0x241D, 1112816, 0),
        new(new(926, 594, -4), 0x241E, 1112817, 0),
        new(new(915, 589, -14), 0x102E, 1024142, 0),
    ];

    private static readonly int[] _ingredientLabels = _props.Select(prop => prop.Label).Distinct().ToArray();

    internal static int NextIngredient() => _ingredientLabels[Utility.Random(_ingredientLabels.Length)];

    public static void Configure() => MLQuestSystem.Register(new PerfectTiming(), typeof(Sutek));

    public static void Initialize() =>
        CommandSystem.Register("PlaceSutekWorkshop", AccessLevel.Administrator, args =>
        {
            var actor = args.Mobile;
            if (!IsInWorkshop(actor) || !Map.TerMur.CanFit(actor.Location, 16, checkMobiles: false))
            {
                actor.SendMessage("Stand on a clear tile in Sutek’s workshop.");
                return;
            }

            Place(actor.Location);
            actor.SendMessage("Sutek and the workshop ingredients are ready.");
        });

    public static bool IsInWorkshop(Mobile mobile) =>
        mobile.Map == Map.TerMur && mobile.Region.IsPartOf(RegionName);

    private static void Place(Point3D keeperSpot)
    {
        var hasKeeper = false;
        foreach (var keeper in Map.TerMur.GetMobilesInRange<Sutek>(Home, 42))
        {
            if (IsInWorkshop(keeper))
            {
                hasKeeper = true;
                break;
            }
        }
        if (!hasKeeper)
        {
            new Sutek { Home = keeperSpot, RangeHome = 5 }.MoveToWorld(keeperSpot, Map.TerMur);
        }

        foreach (var prop in _props)
        {
            var exists = false;
            foreach (var item in Map.TerMur.GetItemsAt(prop.Location))
            {
                if (item is SutekWorkshopIngredient ingredient && ingredient.Location == prop.Location &&
                    ingredient.ItemID == prop.Graphic && ingredient.LabelNumber == prop.Label)
                {
                    exists = true;
                    break;
                }
            }
            if (!exists)
            {
                new SutekWorkshopIngredient(prop.Graphic, prop.Label, prop.Hue).MoveToWorld(prop.Location, Map.TerMur);
            }
        }
    }
}

public sealed class PerfectTiming : MLQuest
{
    public PerfectTiming()
    {
        Activated = true;
        Title = 1112870;
        Description = 1112873;
        RefusalMessage = 1112875;
        InProgressMessage = 1112877;
        CompletionMessage = 1112878;
        Objectives.Add(new CollectObjective(1, typeof(CompletedTrainingAssembly), "completed clockwork assembly"));
        Rewards.Add(new ItemReward(1112874, typeof(MechanicalLifeManual)));
        Rewards.Add(new ItemReward(1115722, typeof(SuteksDirtyGear)));
    }

    public override bool CanOffer(IQuestGiver quester, PlayerMobile player, MLQuestContext context, bool message) =>
        Core.SA && MLQuestSystem.Enabled && context?.FindInstance(typeof(PerfectTiming)) == null &&
        base.CanOffer(quester, player, context, message);

    public override void OnAccept(IQuestGiver quester, PlayerMobile player)
    {
        if (quester is Sutek sutek && player is { Alive: true, Backpack: { } pack } &&
            player.Map == sutek.Map && player.InRange(sutek, 2) && player.InLOS(sutek) &&
            CanOffer(quester, player, true))
        {
            var mechanism = new SutekTrainingMechanism();
            if (!pack.TryDropItem(player, mechanism, true))
            {
                mechanism.Delete();
                return;
            }
            base.OnAccept(quester, player);
        }
    }

    public override void OnCancel(MLQuestInstance instance)
    {
        instance.Player.Backpack?.FindItemByType<SutekTrainingMechanism>()?.Delete();
        instance.Player.Backpack?.FindItemByType<CompletedTrainingAssembly>()?.Delete();
    }

    public static bool IsActive(PlayerMobile player) =>
        MLQuestSystem.GetContext(player)?.FindInstance(typeof(PerfectTiming)) is { Failed: false, ClaimReward: false };
}
