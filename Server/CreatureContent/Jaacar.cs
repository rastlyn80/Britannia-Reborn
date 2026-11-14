// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.Craft;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("Jaacar (Underworld)")]
[SerializationGenerator(0)]
public sealed partial class Jaacar : BaseCreature
{
    [Constructible]
    public Jaacar() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Body = 723;
        CantWalk = true;
        Direction = Direction.Down;
        InitStats(100, 100, 25);
    }

    public override string DefaultName => "Jaacar";
    public override bool IsInvulnerable => true;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Map != Map || !from.InRange(this, 2) || !from.InLOS(this))
        {
            from.SendLocalizedMessage(1019045);
            return;
        }

        base.OnDoubleClick(from);
    }
}

public sealed class BadCompany : MLQuest
{
    public BadCompany()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1095022;
        Description = 1095024;
        RefusalMessage = 1095025;
        InProgressMessage = 1095026;
        CompletionMessage = 1095030;
        Objectives.Add(new KillObjective(10, [typeof(GreenGoblin)], "Green Goblins",
            new QuestArea("Underworld", "Underworld", Map.TerMur)));
        Rewards.Add(new ItemReward("Bowl of Rotworm Stew Recipe", typeof(JaacarRewardBox)));
    }

    public override Type NextQuest => typeof(ATangledWeb);
}

public sealed class ATangledWeb : MLQuest
{
    public ATangledWeb()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1095032;
        Description = 1095034;
        RefusalMessage = 1095035;
        InProgressMessage = 1095036;
        CompletionMessage = 1095038;
        Objectives.Add(new KillObjective(12, [typeof(BloodWorm), typeof(BloodElemental)], "Blood Creatures",
            new QuestArea("Underworld", "Underworld", Map.TerMur)));
        Rewards.Add(ItemReward.LargeBagOfTreasure);
    }

    public override bool IsChainTriggered => true;
}

public static class JaacarQuests
{
    public static void Configure()
    {
        MLQuestSystem.Register(new BadCompany(), typeof(Jaacar));
        MLQuestSystem.Register(new ATangledWeb(), typeof(Jaacar));
    }

    [CallPriority(60)]
    public static void Initialize()
    {
        var cooking = DefCooking.CraftSystem;
        var index = cooking.AddCraft(typeof(BowlOfRotwormStew), 1044498, 1031706, 0.0, 100.0,
            typeof(RawRotwormMeat), 1031705, 1, 1044253);
        cooking.SetNeedHeat(index, true);
        cooking.SetUseAllRes(index, true);
        cooking.ForceNonExceptional(index);
        cooking.AddRecipe(index, JaacarRewardBox.RecipeId);
    }
}
