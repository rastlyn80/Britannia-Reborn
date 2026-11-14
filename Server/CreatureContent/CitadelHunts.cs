// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Mobiles;

namespace Server.Engines.MLQuests.Definitions;

public sealed class NewLeadership : MLQuest
{
    public NewLeadership()
    {
        Activated = true;
        Title = 1072905;
        Description = 1072963;
        RefusalMessage = 1072973;
        InProgressMessage = 1072974;
        var citadel = new QuestArea(1074804, "The Citadel");
        Objectives.Add(new KillObjective(1, [typeof(SerpentsFangHighExecutioner)], "Serpent's Fang High Executioner", citadel));
        Objectives.Add(new KillObjective(1, [typeof(TigersClawMaster)], "Tiger's Claw Master Thief", citadel));
        Objectives.Add(new KillObjective(1, [typeof(DragonsFlameGrandMage)], "Dragon's Flame Grand Mage", citadel));
        Rewards.Add(ItemReward.Strongbox);
    }
}

public abstract class CitadelSectHunt : MLQuest
{
    protected CitadelSectHunt(int title, int description, Type target, string objective)
    {
        Activated = true;
        Title = title;
        Description = description;
        RefusalMessage = 1072979;
        InProgressMessage = 1072980;
        Objectives.Add(new CitadelMaleSectObjective(target, objective));
        Rewards.Add(ItemReward.BagOfTreasure);
    }
}

public sealed class ExAssassins() :
    CitadelSectHunt(1072917, 1072969, typeof(SerpentsFangAssassin), "male Serpent's Fang assassins");

public sealed class CrimeAndPunishment() :
    CitadelSectHunt(1072914, 1072968, typeof(TigersClawThief), "male Tiger's Claw thieves");

public sealed class ExtinguishingTheFlame() :
    CitadelSectHunt(1072911, 1072966, typeof(DragonsFlameMage), "male Dragon's Flame mages");

// Stock kill objectives match type and region. These three also need a sex check.
// Credit runs from the sect creature's stock looting-rights callback and uses the native saved kill counter.
internal sealed class CitadelMaleSectObjective(Type target, string name) :
    KillObjective(10, [], name, new QuestArea(1074804, "The Citadel"))
{
    public override BaseObjectiveInstance CreateInstance(MLQuestInstance instance) =>
        new Counter(this, instance);

    internal static void Credit(BaseCreature slain, Mobile killer)
    {
        if (slain.Female || killer is not PlayerMobile player || !MLQuestSystem.Enabled ||
            MLQuestSystem.GetContext(player) is not { } context)
        {
            return;
        }

        var quests = context.QuestInstances;
        for (var index = quests.Count - 1; index >= 0; index--)
        {
            var instance = quests[index];
            if (instance.ClaimReward || instance.Failed || instance.Quest is not CitadelSectHunt ||
                instance.Objectives[0] is not Counter counter)
            {
                continue;
            }
            counter.Credit(slain);
        }
    }

    private sealed class Counter(CitadelMaleSectObjective objective, MLQuestInstance instance)
        : KillObjectiveInstance(objective, instance)
    {
        internal void Credit(BaseCreature slain)
        {
            if (Expired || IsCompleted() || slain.GetType() != objective._target || !objective.Area.Contains(slain))
            {
                return;
            }

            Slain++;
            var remaining = objective.DesiredAmount - Slain;
            if (remaining == 0)
            {
                Instance.Player.SendLocalizedMessage(1075050);
                CheckComplete();
            }
            else
            {
                Instance.Player.SendLocalizedMessage(1075051, $"{remaining}");
            }
        }
    }

    private readonly Type _target = target;
}
