// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("Naxatilor (Holy City)")]
[TypeAlias("Server.Mobiles.Naxatillor")]
[SerializationGenerator(0)]
public sealed partial class Naxatilor : BaseCreature
{
    public static readonly Point3D HomeTile = new(1016, 3935, -42);

    [Constructible]
    public Naxatilor() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Title = "the Seer";
        Race = Race.Gargoyle;
        Body = Race.AliveBody(this);
        HairItemID = 0x425B;
        HairHue = 1801;
        CantWalk = true;
        InitStats(100, 100, 25);
        AddItem(new Backpack());
        AddItem(new GargishClothChestType1 { Hue = Utility.RandomNeutralHue() });
        AddItem(new GargishClothKiltType1 { Hue = Utility.RandomNeutralHue() });
        AddItem(new GargishClothLegsType1 { Hue = Utility.RandomNeutralHue() });
    }

    public override string DefaultName => "Naxatilor";
    public override bool IsInvulnerable => true;
}

public sealed class TheArisen : MLQuest
{
    public TheArisen()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1112538;
        Description = 1112539;
        RefusalMessage = 1112540;
        InProgressMessage = 1112541;
        CompletionMessage = 1112543;
        ObjectiveType = ObjectiveType.Any;
        var holyCity = new QuestArea("Holy City", "Holy City", Map.TerMur);
        Objectives.Add(new KillObjective(10, [typeof(EffeteUndeadGargoyle)], "Effete Undead Gargoyles", holyCity));
        Objectives.Add(new KillObjective(10, [typeof(EffetePutridGargoyle)], "Effete Putrid Gargoyles", holyCity));
        Objectives.Add(new TombShadeHuntObjective());
        Rewards.Add(new ItemReward(1113137, typeof(NecklaceOfDiligence)));
    }

    public static bool IsUnderwayFor(PlayerMobile player)
    {
        var progress = MLQuestSystem.GetContext(player);
        return progress != null && (progress.FindInstance(typeof(TheArisen)) != null ||
            progress.HasDoneQuest(typeof(TheArisen)));
    }

    public static bool IsCompletedBy(PlayerMobile player) =>
        MLQuestSystem.GetContext(player)?.HasDoneQuest(typeof(TheArisen)) == true;

    public override bool CanOffer(IQuestGiver quester, PlayerMobile pm, MLQuestContext context, bool message)
    {
        if (AbyssAdmission.HasAccess(pm))
        {
            if (message)
            {
                MLQuestSystem.Tell(quester, pm, 1075454);
            }
            return false;
        }

        return context?.HasDoneQuest(typeof(RumorsAbound)) == true && base.CanOffer(quester, pm, context, message);
    }

    private sealed class TombShadeHuntObjective() : KillObjective(10, [], "Gargoyle Shades")
    {
        public static bool IsValidSite(Mobile mobile)
        {
            return mobile.Map == Map.TerMur && (mobile.Region.IsPartOf("Holy City") ||
                (mobile.X is >= 16 and <= 52 && mobile.Y is >= 37 and <= 241));
        }
    }

    internal static void CreditShade(GargoyleShade shade, Mobile killer)
    {
        if (!MLQuestSystem.Enabled || killer is not PlayerMobile player || !TombShadeHuntObjective.IsValidSite(shade) ||
            MLQuestSystem.GetContext(player)?.FindInstance(typeof(TheArisen)) is not { ClaimReward: false, Failed: false } instance ||
            instance.Objectives[2] is not KillObjectiveInstance counter || counter.IsCompleted() || counter.Expired)
        {
            return;
        }

        counter.Slain++;
        var remaining = counter.Objective.DesiredAmount - counter.Slain;
        if (remaining == 0)
        {
            player.SendLocalizedMessage(1075050);
            counter.CheckComplete();
        }
        else
        {
            player.SendLocalizedMessage(1075051, $"{remaining}");
        }
    }
}

public static class NaxatilorPlacement
{
    public static void Configure()
    {
        MLQuestSystem.Register(new RumorsAbound(), typeof(Egwexem));
        MLQuestSystem.Register(new TheArisen(), typeof(Naxatilor));
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceNaxatilor", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        var home = Naxatilor.HomeTile;
        if (actor.Map != map || !actor.InRange(home, 8) ||
            !Region.Find(home, map).IsPartOf("Holy City") || !map.CanFit(home, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand close to Naxatilor's home in the Holy City.");
            return;
        }

        foreach (var existing in map.GetMobilesInRange<Naxatilor>(home, 12))
        {
            actor.SendMessage($"Naxatilor is already at {existing.Location}.");
            return;
        }

        new Naxatilor().MoveToWorld(home, map);
        actor.SendMessage($"Naxatilor placed at {home}.");
    }
}

[SerializationGenerator(0)]
public sealed partial class NecklaceOfDiligence : Necklace
{
    [Constructible]
    public NecklaceOfDiligence()
    {
        Attributes.BonusInt = 5;
        Attributes.RegenMana = 1;
    }

    public override int LabelNumber => 1113137;
}
