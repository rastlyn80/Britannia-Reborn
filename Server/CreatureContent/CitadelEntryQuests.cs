// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Definitions;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;
using Server.Mobiles;

namespace Server;

public static class CitadelEntryQuests
{
    public static void Configure()
    {
        MLQuestSystem.Register(new BlackOrderBadges(), typeof(Sarakki));
        MLQuestSystem.Register(new CitadelEvidence(), typeof(Sarakki));
        RegisterAcobQuest<NewLeadership>();
        RegisterAcobQuest<ExAssassins>();
        RegisterAcobQuest<ExtinguishingTheFlame>();
        RegisterAcobQuest<CrimeAndPunishment>();

        var ninjaQuest = MLQuestSystem.FindQuest(typeof(DeathToTheNinja));
        if (ninjaQuest is { Objectives.Count: 1 } && ninjaQuest.Objectives[0] is KillObjective objective)
        {
            ninjaQuest.Description = 1072967;
            objective.AcceptedTypes = [typeof(EliteNinja), typeof(EliteNinjaWarrior)];
        }
    }

    private static void RegisterAcobQuest<T>() where T : MLQuest, new()
    {
        // The pinned MLQuests.cfg already names these types. Also support runtimes with an older list.
        if (MLQuestSystem.FindQuest(typeof(T)) == null)
        {
            MLQuestSystem.Register(new T(), typeof(ElderAcob));
        }
    }

    internal static bool AllowsEntry(PlayerMobile player)
    {
        if (!MLQuestSystem.Enabled || MLQuestSystem.GetContext(player) is not { } context)
        {
            return false;
        }

        return context.FindInstance(typeof(BlackOrderBadges)) is { Failed: false } ||
               context.FindInstance(typeof(CitadelEvidence)) is { Failed: false } ||
               context.FindInstance(typeof(DeathToTheNinja)) is { Failed: false } ||
               context.FindInstance(typeof(NewLeadership)) is { Failed: false } ||
               context.FindInstance(typeof(ExAssassins)) is { Failed: false } ||
               context.FindInstance(typeof(ExtinguishingTheFlame)) is { Failed: false } ||
               context.FindInstance(typeof(CrimeAndPunishment)) is { Failed: false };
    }
}

public sealed class BlackOrderBadges : MLQuest
{
    public BlackOrderBadges()
    {
        Activated = true;
        Title = 1072903;
        Description = 1072962;
        RefusalMessage = 1072971;
        InProgressMessage = 1072972;
        Objectives.Add(new CollectObjective(5, typeof(SerpentFangSectBadge), "Serpent Fang badges"));
        Objectives.Add(new CollectObjective(5, typeof(TigerClawSectBadge), "Tiger Claw badges"));
        Objectives.Add(new CollectObjective(5, typeof(DragonFlameSectBadge), "Dragon Flame badges"));
        Rewards.Add(ItemReward.BagOfTreasure);
    }
}

public sealed class CitadelEvidence : MLQuest
{
    public CitadelEvidence()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1072906;
        Description = 1072964;
        RefusalMessage = 1072975;
        InProgressMessage = 1072976;
        Objectives.Add(new CollectObjective(1, typeof(OrdersFromMinax), "Orders from Minax"));
        Rewards.Add(ItemReward.Strongbox);
    }
}
