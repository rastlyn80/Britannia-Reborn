// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.MLQuests.Definitions;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class DragonsFlameMage : BaseCreature
{
    [Constructible]
    public DragonsFlameMage() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        const int clothHue = 0x51D;
        Female = Utility.RandomBool();
        Body = Race.Human.Body(this);
        Hue = Race.RandomSkinHue();
        Title = "of the Dragon's Flame Sect";
        Utility.AssignRandomHair(this);
        Race.RandomFacialHair(this);

        AddItem(new NinjaTabi());
        AddItem(new FancyShirt(clothHue));
        AddItem(new Hakama(clothHue));
        AddItem(new Kasa(clothHue));

        Fame = 13000;
        Karma = -13000;
        VirtualArmor = 58;
        SetStr(340, 360);
        SetDex(200, 215);
        SetInt(400, 415);
        SetHits(600, 615);
        SetDamage(13, 15);
        SetDamageType(ResistanceType.Physical, 10);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Energy, 50);
        SetResistance(ResistanceType.Physical, 40, 50);
        SetResistance(ResistanceType.Fire, 30, 50);
        SetResistance(ResistanceType.Cold, 55, 60);
        SetResistance(ResistanceType.Poison, 50, 60);
        SetResistance(ResistanceType.Energy, 60, 70);
        SetSkill(SkillName.EvalInt, 70.1, 80.0);
        SetSkill(SkillName.Magery, 90.1, 100.0);
        SetSkill(SkillName.MagicResist, 85.1, 95.0);
        SetSkill(SkillName.Tactics, 70.1, 80.0);
        SetSkill(SkillName.Wrestling, 60.1, 80.0);
    }

    public override string DefaultName => "Black Order Mage";
    public override string CorpseName => "a black order mage corpse";
    public override bool AlwaysMurderer => true;
    public override bool ShowFameTitle => false;
    protected virtual double SectBadgeChance => 0.30;

    public override void OnKilledBy(Mobile killer)
    {
        base.OnKilledBy(killer);
        CitadelMaleSectObjective.Credit(this, killer);
    }

    public override void AlterSpellDamageFrom(Mobile from, ref int damage)
    {
        base.AlterSpellDamageFrom(from, ref damage);
        if (from != null && damage >= 2)
        {
            from.Damage(damage / 2, from);
        }
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (Utility.RandomDouble() < SectBadgeChance)
        {
            corpse.DropItem(new DragonFlameSectBadge());
        }
    }

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 4);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
