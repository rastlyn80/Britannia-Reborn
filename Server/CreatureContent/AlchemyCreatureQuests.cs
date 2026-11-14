// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;
using Server.Mobiles;

namespace Server;

public sealed class AlchemyCreatureQuests : GenericPersistence
{
    public enum Tier : byte
    {
        Apprentice,
        Specialist,
        Alchemist,
        Master
    }

    private static readonly Dictionary<(Serial Player, Tier Tier), int> _completions = [];

    public AlchemyCreatureQuests() : base("BritanniaRebornAlchemyCreatureQuests", 10)
    {
    }

    public static void Configure()
    {
        _ = new AlchemyCreatureQuests();
        MLQuestSystem.Register(new AllThatGlitters(), typeof(Thepem));
        MLQuestSystem.Register(new TastyTreats(), typeof(Thepem));
        MLQuestSystem.Register(new MetalHead(), typeof(Thepem));
        MLQuestSystem.Register(new PinkIsTheNewBlack(), typeof(Thepem));
        MLQuestSystem.Register(new DabblingOnTheDarkSide(), typeof(Zosilem));
        MLQuestSystem.Register(new ArmorUp(), typeof(Zosilem));
    }

    internal static bool HasAccess(PlayerMobile player, Tier tier) => tier switch
    {
        Tier.Apprentice => true,
        Tier.Specialist => Count(player, Tier.Apprentice) >= 5,
        Tier.Alchemist => Count(player, Tier.Specialist) >= 5,
        Tier.Master => Count(player, Tier.Alchemist) >= 10,
        _ => false
    };

    private static int Count(PlayerMobile player, Tier tier) =>
        _completions.GetValueOrDefault((player.Serial, tier));

    internal static void Record(PlayerMobile player, Tier tier)
    {
        var cap = tier == Tier.Apprentice || tier == Tier.Specialist ? 5 : tier == Tier.Alchemist ? 10 : 20;
        _completions[(player.Serial, tier)] = Math.Min(Count(player, tier) + 1, cap);
    }

    public override void Serialize(IGenericWriter writer)
    {
        writer.WriteEncodedInt(0);
        writer.WriteEncodedInt(_completions.Count);
        foreach (var ((player, tier), count) in _completions)
        {
            writer.Write(player.Value);
            writer.Write((byte)tier);
            writer.WriteEncodedInt(count);
        }
    }

    public override void Deserialize(IGenericReader reader)
    {
        if (reader.ReadEncodedInt() != 0)
        {
            throw new InvalidOperationException("Unsupported alchemist quest progression save version.");
        }
        _completions.Clear();
        var count = reader.ReadEncodedInt();
        for (var i = 0; i < count; i++)
        {
            var serial = (Serial)reader.ReadUInt();
            var tier = (Tier)reader.ReadByte();
            _completions[(serial, tier)] = reader.ReadEncodedInt();
        }
    }
}

public abstract class AlchemyCreatureQuest : MLQuest
{
    private readonly AlchemyCreatureQuests.Tier _tier;

    protected AlchemyCreatureQuest(AlchemyCreatureQuests.Tier tier, int title, int description, int refusal, int progress, int completion)
    {
        _tier = tier;
        Activated = true;
        HasRestartDelay = true;
        Title = title;
        Description = description;
        RefusalMessage = refusal;
        InProgressMessage = progress;
        CompletionMessage = completion;
    }

    public override TimeSpan GetRestartDelay() =>
        _tier is AlchemyCreatureQuests.Tier.Apprentice or AlchemyCreatureQuests.Tier.Alchemist
            ? TimeSpan.FromMinutes(30)
            : TimeSpan.FromHours(2);

    public override bool CanOffer(IQuestGiver quester, PlayerMobile player, MLQuestContext? context, bool message)
    {
        if (quester is not AlchemistInspector inspector || player.Map != inspector.Map ||
            !player.InRange(inspector, 2) || !player.InLOS(inspector) || !AlchemyCreatureQuests.HasAccess(player, _tier))
        {
            if (message)
            {
                MLQuestSystem.Tell(quester, player, 1080107);
            }
            return false;
        }
        return context?.IsDoingQuest(this) != true && base.CanOffer(quester, player, context, message);
    }

    public override void OnRewardClaimed(MLQuestInstance instance) =>
        AlchemyCreatureQuests.Record(instance.Player, _tier);

    protected void Require<T>(int amount, string label) where T : Item =>
        Objectives.Add(new CollectObjective(amount, typeof(T), label));

    protected void RequireInspected(CraftResource resource, string label) =>
        Objectives.Add(new InspectedObjective(resource, label));

    private sealed class InspectedObjective(CraftResource resource, string label)
        : CollectObjective(1, typeof(InspectedAlchemyGoods), label)
    {
        public override bool CheckItem(Item item)
        {
            var (hue, localized, name) = InspectedAlchemyGoods.ForResource(resource);
            return item.ItemID == 0x1BEA && item.Hue == hue && item.Name == name &&
                (localized == 0 || item.LabelNumber == localized);
        }
    }
}

public sealed class AllThatGlitters : AlchemyCreatureQuest
{
    public AllThatGlitters() : base(AlchemyCreatureQuests.Tier.Apprentice, 1112775, 1112948, 1112949, 1112950, 1112951)
    {
        Require<CongealedSlugAcid>(5, "Congealed Slug Acid");
        RequireInspected(CraftResource.Gold, "Inspected Gold Ingots");
        Rewards.Add(new ItemReward(1113012, typeof(ElixirOfGoldConversion)));
    }
}

public sealed class TastyTreats : AlchemyCreatureQuest
{
    public TastyTreats() : base(AlchemyCreatureQuests.Tier.Apprentice, 1112774, 1112944, 1112945, 1112946, 1112947)
    {
        Require<BouraSkin>(5, "Boura Skins");
        Require<Dough>(1, "Dough");
        Rewards.Add(new ItemReward("1 Tasty Treat", typeof(AlchemyTastyTreat)));
    }
}

public sealed class MetalHead : AlchemyCreatureQuest
{
    public MetalHead() : base(AlchemyCreatureQuests.Tier.Specialist, 1112776, 1112952, 1112957, 1112954, 1112955)
    {
        Require<UndamagedIronBeetleScale>(10, "Undamaged Iron Beetle Scales");
        RequireInspected(CraftResource.DullCopper, "Inspected Dull Copper Ingots");
        RequireInspected(CraftResource.ShadowIron, "Inspected Shadow Iron Ingots");
        RequireInspected(CraftResource.Copper, "Inspected Copper Ingots");
        RequireInspected(CraftResource.Bronze, "Inspected Bronze Ingots");
        Rewards.Add(new ItemReward(1113016, typeof(ElixirOfMetalConversion)));
    }
}

public sealed class PinkIsTheNewBlack : AlchemyCreatureQuest
{
    public PinkIsTheNewBlack() : base(AlchemyCreatureQuests.Tier.Specialist, 1112777, 1112956, 1112957, 1112958, 1112959)
    {
        Require<SearedFireAntGoo>(5, "Seared Fire Ant Goo");
        RequireInspected(CraftResource.Agapite, "Inspected Agapite Ingots");
        Rewards.Add(new ItemReward(1113013, typeof(ElixirOfAgapiteConversion)));
    }
}

public sealed class DabblingOnTheDarkSide : AlchemyCreatureQuest
{
    public DabblingOnTheDarkSide() : base(AlchemyCreatureQuests.Tier.Alchemist, 1112778, 1112963, 1112964, 1112965, 1112966)
    {
        Require<BouraSkin>(5, "Boura Skins");
        Require<FairyDragonWing>(10, "Fairy Dragon Wings");
        Require<Dough>(1, "Dough");
        Rewards.Add(new ItemReward("2 Deliciously Tasty Treats", typeof(AlchemyDeliciousTreat), 2));
    }
}

public sealed class ArmorUp : AlchemyCreatureQuest
{
    public ArmorUp() : base(AlchemyCreatureQuests.Tier.Master, 1112780, 1112971, 1112972, 1112973, 1112974)
    {
        Require<BouraSkin>(5, "Boura Skins");
        Require<LeatherWolfSkin>(10, "Leather Wolf Skins");
        Require<UndamagedIronBeetleScale>(10, "Undamaged Iron Beetle Scales");
        Rewards.Add(new ItemReward(1113017, typeof(VialOfArmorEssence)));
    }
}
