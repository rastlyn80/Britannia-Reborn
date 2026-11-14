// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("Egwexem (Royal City)")]
[SerializationGenerator(0)]
public sealed partial class Egwexem : BaseCreature
{
    public static readonly Point3D HomeTile = new(837, 3512, -47);

    [Constructible]
    public Egwexem() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Title = "the Noble";
        Race = Race.Gargoyle;
        Body = Race.AliveBody(this);
        HairItemID = 0x425B;
        HairHue = 1801;
        CantWalk = true;
        InitStats(100, 100, 25);
        AddItem(new Backpack());
        AddItem(new GargishClothChestType1());
        AddItem(new GargishClothKiltType1());
        AddItem(new GargishClothLegsType1 { Hue = Utility.RandomNeutralHue() });
    }

    public override string DefaultName => "Egwexem";
    public override bool IsInvulnerable => true;

    public static void Initialize() =>
        CommandSystem.Register("PlaceEgwexem", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var staff = args.Mobile;
        var map = Map.TerMur;
        if (staff.Map != map || !staff.InRange(HomeTile, 8) || !map.CanFit(HomeTile, 16, checkMobiles: false))
        {
            staff.SendMessage("Stand by Egwexem's steps at the Royal City entrance.");
            return;
        }

        foreach (var existing in map.GetMobilesInRange<Egwexem>(HomeTile, 12))
        {
            staff.SendMessage($"Egwexem is already at {existing.Location}.");
            return;
        }
        new Egwexem().MoveToWorld(HomeTile, map);
        staff.SendMessage($"Egwexem placed at {HomeTile}.");
    }
}

public sealed class RumorsAbound : MLQuest
{
    public RumorsAbound()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1112514;
        Description = 1112515;
        RefusalMessage = 1112516;
        InProgressMessage = 1112517;
        CompletionMessage = 1112519;
        Objectives.Add(new DeliverObjective(typeof(EgwexemWrit), 1, "Egwexem's Writ", typeof(Naxatilor)));
        Rewards.Add(new ReassuranceReward());
    }

    public override bool CanOffer(IQuestGiver quester, PlayerMobile player, MLQuestContext context, bool message) =>
        !AbyssAdmission.HasAccess(player) && base.CanOffer(quester, player, context, message);

    private sealed class ReassuranceReward() : BaseReward(1112731)
    {
        public override void AddRewardItems(PlayerMobile player, List<Item> rewards)
        {
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class EgwexemWrit : Item
{
    [Constructible]
    public EgwexemWrit() : base(0x0E34) => LootType = LootType.Blessed;

    public override int LabelNumber => 1112520;
}
