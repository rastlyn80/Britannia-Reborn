// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class TombGuardian : BaseCreature
{
    protected TombGuardian() : base(AIType.AI_Melee, FightMode.Closest, 10)
    {
        Body = 722;
        SetResistance(ResistanceType.Cold, 50, 60);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Poison, 20, 30);
        SetResistance(ResistanceType.Energy, 30, 40);
        PackNecroReg(10, 15);
    }

    public override int GetIdleSound() => 1609;
    public override int GetAngerSound() => 1606;
    public override int GetHurtSound() => 1608;
    public override int GetDeathSound() => 1607;
    public override int Meat => 1;
}

[SerializationGenerator(0)]
public sealed partial class UndeadGuardian : TombGuardian
{
    [Constructible]
    public UndeadGuardian()
    {
        SetStr(201, 248);
        SetDex(76, 95);
        SetInt(38, 64);
        SetHits(118, 147);
        SetDamage(8, 18);
        SetDamageType(ResistanceType.Physical, 40);
        SetDamageType(ResistanceType.Cold, 60);
        SetResistance(ResistanceType.Physical, 35, 45);
        SetSkill(SkillName.Wrestling, 86.0, 94.4);
        SetSkill(SkillName.Tactics, 88.1, 99.0);
        SetSkill(SkillName.MagicResist, 66.4, 79.8);
    }

    public override string DefaultName => "an undead guardian";
    public override string CorpseName => "an undead guardian corpse";
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 3);
}

[SerializationGenerator(0)]
public sealed partial class PutridUndeadGuardian : TombGuardian
{
    [Constructible]
    public PutridUndeadGuardian()
    {
        SetStr(86, 98);
        SetDex(57, 66);
        SetInt(186, 205);
        SetHits(46, 60);
        SetDamage(3, 7);
        SetResistance(ResistanceType.Physical, 35, 40);
        SetSkill(SkillName.Wrestling, 47.9, 54.3);
        SetSkill(SkillName.Tactics, 45.2, 60.0);
        SetSkill(SkillName.MagicResist, 55.1, 69.8);
        Fame = 3000;
        Karma = -3000;
    }

    public override string DefaultName => "a putrid undead guardian";
    public override string CorpseName => "a putrid undead guardian corpse";
    public override void GenerateLoot() => AddLoot(LootPack.Average);
}

[SerializationGenerator(0)]
public sealed partial class GargoyleShade : BaseCreature
{
    [Constructible]
    public GargoyleShade() : base(AIType.AI_Mage, FightMode.Closest, 10)
    {
        Body = 4;
        Hue = 0x4001;
        BaseSoundID = 0x482;
        SetStr(79, 104);
        SetDex(78, 95);
        SetInt(42, 65);
        SetHits(61, 79);
        SetDamage(7, 14);
        SetResistance(ResistanceType.Physical, 40, 55);
        SetResistance(ResistanceType.Fire, 35, 45);
        SetResistance(ResistanceType.Cold, 15, 20);
        SetResistance(ResistanceType.Poison, 25, 35);
        SetSkill(SkillName.Wrestling, 40.1, 49.4);
        SetSkill(SkillName.Tactics, 41.1, 60.0);
        SetSkill(SkillName.MagicResist, 53.0, 65.0);
        SetSkill(SkillName.Magery, 50.5, 65.0);
        SetSkill(SkillName.EvalInt, 50.5, 63.4);
        Fame = 4000;
        Karma = -4000;
        VirtualArmor = 28;
        PackReg(10);
    }

    public override string DefaultName => "a gargoyle shade";
    public override string CorpseName => "a ghostly corpse";
    public override bool BleedImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override OppositionGroup OppositionGroup => OppositionGroup.FeyAndUndead;
    public override void GenerateLoot() => AddLoot(LootPack.Meager);

    public override void OnKilledBy(Mobile killer)
    {
        base.OnKilledBy(killer);
        TheArisen.CreditShade(this, killer);
    }
}

[SerializationGenerator(0)]
public sealed partial class EffeteUndeadGargoyle : BaseCreature
{
    [Constructible]
    public EffeteUndeadGargoyle() : base(AIType.AI_Melee, FightMode.Closest, 10)
    {
        Body = 722;
        BaseSoundID = 372;
        SetStr(58, 80);
        SetDex(56, 74);
        SetInt(19, 39);
        SetHits(67, 77);
        SetDamage(3, 7);
        SetResistance(ResistanceType.Physical, 15, 20);
        SetResistance(ResistanceType.Fire, 5, 10);
        SetResistance(ResistanceType.Cold, 25, 40);
        SetResistance(ResistanceType.Poison, 25, 35);
        SetResistance(ResistanceType.Energy, 5, 15);
        SetSkill(SkillName.Wrestling, 45.9, 54.1);
        SetSkill(SkillName.Tactics, 45.5, 59.1);
        SetSkill(SkillName.MagicResist, 50.1, 59.8);
        Fame = 500;
        Karma = -500;
    }

    public override string DefaultName => "an effete undead gargoyle";
    public override string CorpseName => "an effete undead gargoyle corpse";
    public override void GenerateLoot()
    {
        if (!m_Spawning)
        {
            PackGold(20, 40);
            PackItem(new Items.Bone());
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class EffetePutridGargoyle : BaseCreature
{
    [Constructible]
    public EffetePutridGargoyle() : base(AIType.AI_Mage, FightMode.Closest, 10)
    {
        Body = 4;
        BaseSoundID = 372;
        SetStr(215, 247);
        SetDex(90, 95);
        SetInt(40, 58);
        SetHits(110, 129);
        SetDamage(8, 18);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Cold, 40);
        SetResistance(ResistanceType.Physical, 30, 35);
        SetResistance(ResistanceType.Fire, 25, 35);
        SetResistance(ResistanceType.Cold, 5, 10);
        SetResistance(ResistanceType.Poison, 15, 25);
        SetSkill(SkillName.Wrestling, 69.6, 70.0);
        SetSkill(SkillName.Tactics, 65.7, 66.0);
        SetSkill(SkillName.MagicResist, 60.5, 65.0);
        SetSkill(SkillName.Magery, 55.0, 65.0);
        SetSkill(SkillName.EvalInt, 50.0, 60.0);
        Fame = 3500;
        Karma = -3500;
    }

    public override string DefaultName => "an effete putrid gargoyle";
    public override string CorpseName => "an effete putrid gargoyle corpse";
    public override void GenerateLoot()
    {
        AddLoot(LootPack.Average, 2);
        AddLoot(LootPack.MedScrolls);
        AddLoot(LootPack.Gems);
    }
}
