// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class WolfSpider : BaseCreature
{
    [Constructible]
    public WolfSpider() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 736;
        SetStr(225, 268);
        SetDex(145, 165);
        SetInt(285, 310);
        SetHits(150, 160);
        SetMana(285, 310);
        SetStam(145, 165);
        SetDamage(15, 18);

        SetDamageType(ResistanceType.Physical, 70);
        SetDamageType(ResistanceType.Poison, 30);
        SetResistance(ResistanceType.Physical, 30, 35);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 25, 35);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 25, 35);
        SetSkill(SkillName.Anatomy, 80.0, 90.0);
        SetSkill(SkillName.MagicResist, 60.0, 75.0);
        SetSkill(SkillName.Poisoning, 62.3, 77.2);
        SetSkill(SkillName.Tactics, 84.1, 95.9);
        SetSkill(SkillName.Wrestling, 80.2, 90.0);
        SetSkill(SkillName.Hiding, 105.0, 110.0);
        SetSkill(SkillName.Stealth, 105.0, 110.0);

        Tamable = true;
        ControlSlots = 2;
        MinTameSkill = 59.1;
    }

    public override string DefaultName => "a wolf spider";
    public override string CorpseName => "a wolf spider corpse";
    public override FoodType FavoriteFood => FoodType.Meat;
    public override PackInstinct PackInstinct => PackInstinct.Arachnid;
    public override Poison PoisonImmune => Poison.Regular;
    public override Poison HitPoison => Poison.Regular;
    public override int GetIdleSound() => 1605;
    public override int GetAngerSound() => 1602;
    public override int GetHurtSound() => 1604;
    public override int GetDeathSound() => 1603;

    public override void GenerateLoot()
    {
        PackItem(new SpidersSilk(8));
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.Gems, 2);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
