// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.MLQuests;
using Server.Engines.MLQuests.Objectives;
using Server.Engines.MLQuests.Rewards;
using Server.Items;

namespace Server.Mobiles;

[QuesterName("Agralem (Royal City)")]
[SerializationGenerator(0)]
public partial class Agralem : BaseCreature
{
    public static readonly Point3D HomeTile = new(808, 3425, 0);

    [Constructible]
    public Agralem() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Title = "the Bladeweaver";
        Race = Race.Gargoyle;
        Body = Race.AliveBody(this);
        Hue = 34536;
        HairItemID = 0x425D;
        HairHue = 0x31D;
        CantWalk = true;
        InitStats(100, 100, 25);
        SetSkill(SkillName.Anatomy, 65.0, 90.0);
        SetSkill(SkillName.MagicResist, 65.0, 90.0);
        SetSkill(SkillName.Tactics, 65.0, 90.0);
        SetSkill(SkillName.Throwing, 65.0, 90.0);
        AddItem(new Backpack());
        AddItem(new Cyclone());
        AddItem(new GargishLeatherKiltType1 { Hue = 2305 });
        AddItem(new GargishLeatherChestType1 { Hue = 2305 });
        AddItem(new GargishLeatherArmsType1 { Hue = 2305 });
    }

    public override string DefaultName => "Agralem";
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

public sealed class IntoTheVoid : MLQuest
{
    public IntoTheVoid()
    {
        Activated = true;
        OneTimeOnly = true;
        Title = 1112687;
        Description = 1112690;
        RefusalMessage = 1112691;
        InProgressMessage = 1112692;
        CompletionMessage = 1112693;
        Objectives.Add(new KillObjective(10, [typeof(VoidCreature), typeof(Ortanord)], 1112686));
        Rewards.Add(new AbyssReaverReward());
    }

    private sealed class AbyssReaverReward() : ItemReward(1112694, typeof(AbyssReaver))
    {
        public override Item CreateItem()
        {
            var weapon = new AbyssReaver();
            weapon.SkillBonuses.SetValues(0, SkillName.Throwing, 10);
            weapon.Attributes.WeaponDamage = 35;
            return weapon;
        }
    }
}

public static class AgralemQuestPlacement
{
    public static void Configure() => MLQuestSystem.Register(new IntoTheVoid(), typeof(Agralem));

    public static void Initialize() =>
        CommandSystem.Register("PlaceAgralem", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        var home = Agralem.HomeTile;
        if (actor.Map != map || !actor.InRange(home, 8) ||
            !Region.Find(home, map).IsPartOf("Royal City") || !map.CanFit(home, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand near Agralem's clear tile by the Royal City soulforge.");
            return;
        }

        foreach (var agralem in map.GetMobilesInRange<Agralem>(home, 12))
        {
            actor.SendMessage($"Agralem is already at {agralem.Location}.");
            return;
        }

        var quester = new Agralem();
        quester.MoveToWorld(home, map);
        actor.SendMessage($"Agralem placed at {home}.");
    }
}
