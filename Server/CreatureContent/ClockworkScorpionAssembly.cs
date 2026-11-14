// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.Craft;
using Server.Items;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class MechanicalLifeManual : Item
{
    [Constructible]
    public MechanicalLifeManual() : base(0xFF4)
    {
    }

    public override int LabelNumber => 1112874;

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not PlayerMobile { Alive: true } player)
        {
            return;
        }
        if (!IsChildOf(player.Backpack))
        {
            player.SendLocalizedMessage(1042001);
            return;
        }
        if (!Core.SA || player.NetState?.SupportsExpansion(Expansion.SA) != true)
        {
            player.SendLocalizedMessage(1112943);
            return;
        }
        if (player.Skills.Tinkering.Base < 100.0)
        {
            player.SendLocalizedMessage(1112255);
            return;
        }
        if (!MechanicalLifeKnowledge.Learn(player))
        {
            player.SendLocalizedMessage(1080066);
            return;
        }

        player.SendLocalizedMessage(1112942);
        Delete();
    }
}

[SerializationGenerator(0)]
public partial class VoidEssence : Item
{
    [Constructible]
    public VoidEssence() : this(1)
    {
    }

    [Constructible]
    public VoidEssence(int amount) : base(0x4007)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1112327;
}

[SerializationGenerator(0)]
public partial class ClockworkScorpionAssembly : Item
{
    private static readonly Type[] _parts = [typeof(BronzeIngot), typeof(Gears)];
    private static readonly int[] _amounts = [100, 10];

    [Constructible]
    public ClockworkScorpionAssembly() : base(0x1EA8)
    {
    }

    public override int LabelNumber => 1113032;
    public override double DefaultWeight => 5.0;

    public override void OnDoubleClick(Mobile from) =>
        MechanicalAssembly.Construct(this, from, 1, _parts, _amounts, [1113060, 1113061], () => new ClockworkScorpion());
}

internal static class MechanicalAssembly
{
    public static void Construct(Item assembly, Mobile from, int slots, Type[] parts, int[] amounts,
        int[] missingMessages, Func<BaseCreature> createPet)
    {
        if (from is not PlayerMobile { Alive: true, Backpack: { } pack } player)
        {
            return;
        }
        if (!assembly.IsChildOf(pack))
        {
            player.SendLocalizedMessage(1071944);
            return;
        }
        if (!Core.SA || player.NetState?.SupportsExpansion(Expansion.SA) != true)
        {
            player.SendLocalizedMessage(1112943);
            return;
        }
        if (!MechanicalLifeKnowledge.IsKnownBy(player))
        {
            player.SendLocalizedMessage(1113034);
            return;
        }
        if (player.Skills.Tinkering.Value < 60.0)
        {
            player.SendLocalizedMessage(1113054);
            return;
        }
        if (MechanicalLifeKnowledge.IsRecovering(player))
        {
            player.SendMessage("You are too drained to construct another mechanical pet yet.");
            return;
        }
        if (player.Followers + slots > player.FollowersMax)
        {
            player.SendLocalizedMessage(1049607);
            return;
        }

        var pet = createPet();
        if (!pet.SetControlMaster(player))
        {
            pet.Delete();
            return;
        }

        var missing = pack.ConsumeTotal(parts, amounts);
        if (missing >= 0)
        {
            pet.Delete();
            player.SendLocalizedMessage(missingMessages[missing]);
            return;
        }

        pet.MoveToWorld(player.Location, player.Map);
        MechanicalLifeKnowledge.StartRecovery(player);
        assembly.Delete();
        player.PlaySound(0x241);
    }
}

[SerializationGenerator(0)]
public partial class LeatherWolfAssembly : Item
{
    private static readonly Type[] _parts = [typeof(Leather), typeof(OilFlask)];
    private static readonly int[] _amounts = [100, 1];
    private static readonly int[] _missing = [1113058, 1113059];

    [Constructible]
    public LeatherWolfAssembly() : base(0x1EA8)
    {
    }

    public override int LabelNumber => 1113031;
    public override double DefaultWeight => 5.0;
    public override void OnDoubleClick(Mobile from) =>
        MechanicalAssembly.Construct(this, from, 1, _parts, _amounts, _missing, () => new LeatherWolf());
}

[SerializationGenerator(0)]
public partial class VollemAssembly : Item
{
    private static readonly Type[] _parts = [typeof(Leather), typeof(WhiteScales)];
    private static readonly int[] _amounts = [50, 25];
    private static readonly int[] _missing = [1113058, 1113062];

    [Constructible]
    public VollemAssembly() : base(0x1EA8)
    {
    }

    public override int LabelNumber => 1113033;
    public override double DefaultWeight => 5.0;
    public override void OnDoubleClick(Mobile from) =>
        MechanicalAssembly.Construct(this, from, 2, _parts, _amounts, _missing, () => new Vollem());
}

public sealed class CraftClockworkScorpionAssembly(
    Mobile from, CraftItem craftItem, CraftSystem craftSystem, Type typeRes, BaseTool tool, int quality
) : CustomCraft(from, craftItem, craftSystem, typeRes, tool, quality)
{
    public static void Configure() => EventSink.ServerStarted += RegisterRecipe;

    private static void RegisterRecipe()
    {
        if (!Core.SA || DefTinkering.CraftSystem is not { } craft)
        {
            return;
        }

        var index = craft.AddCraft(typeof(CraftClockworkScorpionAssembly), 1044051, 1113032, 0x1EA8,
            90.0, 115.0, typeof(ClockworkAssembly), 1073426, 1, 502910);
        craft.AddRes(index, typeof(PowerCrystal), 1112811, 1, 502910);
        craft.AddRes(index, typeof(VoidEssence), 1112327, 1, 502910);
        craft.ForceNonExceptional(index);
        AddAdvancedRecipe(craft, 1113031, 2);
        AddAdvancedRecipe(craft, 1113033, 3);
    }

    private static void AddAdvancedRecipe(CraftSystem craft, int label, int essence)
    {
        var index = craft.AddCraft(typeof(CraftClockworkScorpionAssembly), 1044051, label, 0x1EA8,
            90.0, 115.0, typeof(ClockworkAssembly), 1073426, 1, 502910);
        craft.AddRes(index, typeof(PowerCrystal), 1112811, 1, 502910);
        craft.AddRes(index, typeof(VoidEssence), 1112327, essence, 502910);
        craft.ForceNonExceptional(index);
    }

    public override void EndCraftAction()
    {
        if (From is not PlayerMobile { Alive: true } player || !MechanicalLifeKnowledge.IsKnownBy(player))
        {
            From.SendLocalizedMessage(1113034);
            return;
        }

        CraftItem.CompleteCraft(Quality, false, From, CraftSystem, TypeRes, Tool, this);
    }

    public override Item CompleteCraft(out int message)
    {
        message = 0;
        return CraftItem.NameNumber switch
        {
            1113031 => new LeatherWolfAssembly(),
            1113033 => new VollemAssembly(),
            _ => new ClockworkScorpionAssembly()
        };
    }
}
