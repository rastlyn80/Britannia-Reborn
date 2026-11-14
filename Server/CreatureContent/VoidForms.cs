// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class Korpre : VoidCreature
{
    [Constructible]
    public Korpre() : base(AIType.AI_Melee)
    {
        Body = 51;
        BaseSoundID = 456;
        Hue = 2071;
        SetStr(22, 34);
        SetDex(16, 21);
        SetInt(16, 20);
        SetHits(50, 60);
        SetDamage(1, 5);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 5, 10);
        SetResistance(ResistanceType.Poison, 15, 20);
        SetSkill(SkillName.Poisoning, 36.0, 49.1);
        SetSkill(SkillName.Anatomy, 0);
        SetSkill(SkillName.MagicResist, 15.9, 18.9);
        SetSkill(SkillName.Tactics, 24.6, 26.1);
        SetSkill(SkillName.Wrestling, 24.9, 26.1);
        Fame = 300;
        Karma = -300;
        VirtualArmor = 8;
    }

    public override string DefaultName => "Korpre";
    public override string CorpseName => "a korpre corpse";
    public override VoidLineage Lineage => VoidLineage.None;
    public override int Stage => 0;
    public override Poison PoisonImmune => Poison.Regular;
    public override Poison HitPoison => Poison.Regular;
    public override FoodType FavoriteFood => FoodType.Fish;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Poor);
        AddLoot(LootPack.Gems);
    }
}

[SerializationGenerator(0)]
public partial class Anzuanord : VoidCreature
{
    [Constructible]
    public Anzuanord() : base(AIType.AI_Mage)
    {
        Body = 74;
        Hue = 2071;
        BaseSoundID = 422;
        SetStr(705);
        SetDex(900, 910);
        SetInt(900, 1000);
        SetHits(180);
        SetDamage(8, 10);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 0, 10);
        SetResistance(ResistanceType.Poison, 15, 20);
        SetResistance(ResistanceType.Physical, 15, 10);
        SetResistance(ResistanceType.Poison, 0, 20);
        SetResistance(ResistanceType.Physical, 100);
        SetSkill(SkillName.Anatomy, 5.0, 10.0);
        SetSkill(SkillName.MagicResist, 40.0, 50.0);
        SetSkill(SkillName.Tactics, 40.0, 50.0);
        SetSkill(SkillName.Wrestling, 40.0, 50.0);
        SetSkill(SkillName.Magery, 70.0, 80.0);
        SetSkill(SkillName.EvalInt, 80.0, 90.0);
        SetSkill(SkillName.Meditation, 50.0, 60.0);
        Fame = 2500;
        Karma = -2500;
        PackItem(new DaemonBone(5));
        VirtualArmor = 50;
    }

    public override string DefaultName => "an Anzuanord";
    public override string CorpseName => "an anzuanord corpse";
    public override VoidLineage Lineage => VoidLineage.Survival;
    public override int Stage => 1;
    public override bool BardImmune => true;
    public override int Meat => 1;
    public override int Hides => 7;
    public override HideType HideType => HideType.Spined;
    public override FoodType FavoriteFood => FoodType.Meat;
    public override PackInstinct PackInstinct => PackInstinct.Daemon;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Meager);
        AddLoot(LootPack.MedScrolls, 2);
    }
}

[SerializationGenerator(0)]
public partial class Relanord : VoidCreature
{
    [Constructible]
    public Relanord() : base(AIType.AI_Melee)
    {
        Body = 0x2F4;
        Hue = 2071;
        SetStr(700, 800);
        SetDex(60, 100);
        SetInt(60, 100);
        SetHits(400, 500);
        SetDamage(10, 15);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 45, 60);
        SetResistance(ResistanceType.Fire, 40, 60);
        SetResistance(ResistanceType.Cold, 25, 35);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 30, 60);
        SetSkill(SkillName.MagicResist, 30.2, 50.0);
        SetSkill(SkillName.Tactics, 40.2, 60.0);
        SetSkill(SkillName.Wrestling, 50.2, 70.0);
        Fame = 10000;
        Karma = -10000;
        VirtualArmor = 50;
        PackItem(new DaemonBone(15));
    }

    public override string DefaultName => "a relanord";
    public override string CorpseName => "a relanord corpse";
    public override VoidLineage Lineage => VoidLineage.Survival;
    public override int Stage => 2;
    public override bool AutoDispel => true;
    public override bool BardImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override int GetIdleSound() => 0xFD;
    public override int GetAngerSound() => 0x26C;
    public override int GetDeathSound() => 0x211;
    public override int GetAttackSound() => 0x23B;
    public override int GetHurtSound() => 0x140;

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich);
}

[SerializationGenerator(0)]
public partial class Vasanord : VoidCreature
{
    [Constructible]
    public Vasanord() : base(AIType.AI_Mage)
    {
        Body = 780;
        SetStr(805, 869);
        SetDex(51, 64);
        SetInt(38, 48);
        SetHits(5000, 5200);
        SetMana(40, 70);
        SetStam(50, 80);
        SetDamage(10, 23);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 30, 50);
        SetResistance(ResistanceType.Fire, 20, 50);
        SetResistance(ResistanceType.Cold, 20, 40);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 20, 50);
        SetSkill(SkillName.MagicResist, 72.8, 77.7);
        SetSkill(SkillName.Tactics, 50.7, 110.0);
        SetSkill(SkillName.EvalInt, 99.5, 120.0);
        SetSkill(SkillName.Magery, 95.5, 106.9);
        SetSkill(SkillName.Wrestling, 53.6, 98.6);
        Fame = 15000;
        Karma = -15000;
        VirtualArmor = 28;
        PackItem(new DaemonBone(30));
    }

    public override string DefaultName => "vasanord";
    public override string CorpseName => "a plant corpse";
    public override VoidLineage Lineage => VoidLineage.Survival;
    public override int Stage => 3;
    public override bool BardImmune => !Core.AOS;
    public override Poison PoisonImmune => Poison.Lethal;
    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.6;
        passiveSpeed = 1.2;
    }

    public override void GenerateLoot() => AddLoot(LootPack.UltraRich, 2);

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (corpse is { Deleted: false } && !Controlled && !Summoned && Utility.RandomDouble() < 0.6)
        {
            corpse.DropItem(new TaintedSeeds());
            corpse.DropItem(new TaintedSeeds());
        }
    }
}

[SerializationGenerator(0)]
public partial class Anlorzen : VoidCreature
{
    [Constructible]
    public Anlorzen() : base(AIType.AI_Melee)
    {
        Body = 11;
        BaseSoundID = 1170;
        SetStr(600, 750);
        SetDex(666, 800);
        SetInt(850, 1000);
        SetHits(300, 400);
        SetDamage(15, 18);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 40, 50);
        SetResistance(ResistanceType.Fire, 40, 50);
        SetResistance(ResistanceType.Cold, 30, 50);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 40, 60);
        SetSkill(SkillName.MagicResist, 30.1, 60.0);
        SetSkill(SkillName.Tactics, 30.1, 70.0);
        SetSkill(SkillName.Wrestling, 50.1, 70.0);
        Fame = 5000;
        Karma = -5000;
        VirtualArmor = 56;
        PackItem(new DaemonBone(5));
    }

    public override string DefaultName => "an anlorzen";
    public override string CorpseName => "an anlorzen corpse";
    public override VoidLineage Lineage => VoidLineage.Grouping;
    public override int Stage => 1;
    public override Poison PoisonImmune => Poison.Lethal;
    public override Poison HitPoison => Poison.Lethal;
    public override bool BardImmune => true;

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich);
}

[SerializationGenerator(0)]
public partial class Anlorlem : VoidCreature
{
    [Constructible]
    public Anlorlem() : base(AIType.AI_Mage)
    {
        Body = 72;
        Hue = 2071;
        BaseSoundID = 644;
        SetStr(900, 1000);
        SetDex(1000, 1200);
        SetInt(900, 950);
        SetHits(500, 650);
        SetDamage(18, 22);
        SetDamageType(ResistanceType.Physical, 50);
        SetDamageType(ResistanceType.Poison, 50);
        SetResistance(ResistanceType.Physical, 45, 55);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 35, 45);
        SetResistance(ResistanceType.Poison, 90, 100);
        SetResistance(ResistanceType.Energy, 35, 45);
        SetSkill(SkillName.MagicResist, 40.1, 70.0);
        SetSkill(SkillName.Tactics, 90.1, 100.0);
        SetSkill(SkillName.Wrestling, 90.1, 100.0);
        Fame = 16000;
        Karma = -16000;
        VirtualArmor = 50;
        PackItem(new DaemonBone(15));
    }

    public override string DefaultName => "an Anlorlem";
    public override string CorpseName => "an Anlorlem corpse";
    public override VoidLineage Lineage => VoidLineage.Grouping;
    public override int Stage => 2;
    public override int TreasureMapLevel => 3;
    public override bool BardImmune => !Core.AOS;
    public override bool Unprovokable => true;
    public override bool ReacquireOnMovement => true;
    public override Poison PoisonImmune => Poison.Greater;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich);
        AddLoot(LootPack.Average, 2);
        AddLoot(LootPack.MedScrolls, 2);
    }
}

[SerializationGenerator(0)]
public partial class Anlorvaglem : VoidCreature
{
    [Constructible]
    public Anlorvaglem() : base(AIType.AI_Melee)
    {
        Hue = 2071;
        Body = 152;
        SetStr(1000, 1200);
        SetDex(1000, 1200);
        SetInt(100, 1200);
        SetHits(3205);
        SetDamage(11, 13);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 20, 50);
        SetResistance(ResistanceType.Fire, 20, 60);
        SetResistance(ResistanceType.Cold, 20, 58);
        SetResistance(ResistanceType.Poison, 80, 100);
        SetResistance(ResistanceType.Energy, 30, 50);
        SetSkill(SkillName.Wrestling, 75.8, 100.0);
        SetSkill(SkillName.Tactics, 50.0, 100.0);
        SetSkill(SkillName.MagicResist, 50.9, 90.0);
        Fame = 8000;
        Karma = -8000;
        VirtualArmor = 48;
        PackItem(new DaemonBone(30));
    }

    public override string DefaultName => "anlorvaglem";
    public override string CorpseName => "an anlorvaglem corpse";
    public override VoidLineage Lineage => VoidLineage.Grouping;
    public override int Stage => 3;
    public override Poison PoisonImmune => Poison.Lethal;
    public override bool Unprovokable => true;
    public override bool BardImmune => true;
    public override bool ReacquireOnMovement => true;
    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.6;
        passiveSpeed = 1.2;
    }

    public override void GenerateLoot() => AddLoot(LootPack.UltraRich);
}

[SerializationGenerator(0)]
public partial class Betballem : VoidCreature
{
    [Constructible]
    public Betballem() : base(AIType.AI_Melee)
    {
        Body = 776;
        Hue = 2071;
        BaseSoundID = 357;
        SetStr(270);
        SetDex(890);
        SetInt(80);
        SetHits(90, 100);
        SetDamage(5, 10);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 30, 40);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Fire, 10, 20);
        SetResistance(ResistanceType.Fire, 10, 20);
        SetResistance(ResistanceType.Fire, 100);
        SetSkill(SkillName.MagicResist, 40.0, 50.0);
        SetSkill(SkillName.Tactics, 20.1, 30.0);
        SetSkill(SkillName.Wrestling, 30.1, 40.0);
        SetSkill(SkillName.Anatomy, 0.0, 10.0);
        Fame = 500;
        Karma = -500;
        VirtualArmor = 38;
        AddItem(new LightSource());
        PackItem(new FertileDirt(Utility.RandomMinMax(1, 4)));
        PackItem(new DaemonBone(5));
    }

    public override string DefaultName => "a betballem";
    public override string CorpseName => "a betballem corpse";
    public override VoidLineage Lineage => VoidLineage.Killing;
    public override int Stage => 1;
    public override bool Unprovokable => true;
    public override bool BardImmune => true;
    public override bool CanRummageCorpses => true;
    public override bool BleedImmune => true;
    public override int GetIdleSound() => 338;
    public override int GetAngerSound() => 338;
    public override int GetDeathSound() => 338;
    public override int GetAttackSound() => 406;
    public override int GetHurtSound() => 194;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.Meager);
        AddLoot(LootPack.Gems);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (corpse is { Deleted: false } && !Controlled && !Summoned && Utility.RandomDouble() < 0.1)
        {
            corpse.DropItem(new AncientPotteryFragments());
        }
    }
}

[SerializationGenerator(0)]
public partial class Ballem : VoidCreature
{
    [Constructible]
    public Ballem() : base(AIType.AI_Melee)
    {
        Body = 304;
        Hue = 2071;
        BaseSoundID = 684;
        SetStr(991);
        SetDex(1001);
        SetInt(243);
        SetHits(500, 600);
        SetDamage(10, 15);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 30, 50);
        SetResistance(ResistanceType.Fire, 40, 50);
        SetResistance(ResistanceType.Cold, 20, 30);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 30, 40);
        SetSkill(SkillName.MagicResist, 70.0, 80.0);
        SetSkill(SkillName.Tactics, 50.1, 60.0);
        SetSkill(SkillName.Wrestling, 70.1, 80.0);
        SetSkill(SkillName.Anatomy, 0.0, 10.0);
        Fame = 1800;
        Karma = -1800;
        VirtualArmor = 54;
        PackItem(new DaemonBone(15));
    }

    public override string DefaultName => "a Ballem";
    public override string CorpseName => "a Ballem corpse";
    public override VoidLineage Lineage => VoidLineage.Killing;
    public override int Stage => 2;
    public override Poison PoisonImmune => Poison.Lethal;
    public override bool Unprovokable => true;
    public override bool BardImmune => true;
    public override bool CanRummageCorpses => true;
    public override bool BleedImmune => true;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.Average);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (corpse is { Deleted: false } && !Controlled && !Summoned && Utility.RandomDouble() < 0.1)
        {
            corpse.DropItem(new AncientPotteryFragments());
        }
    }
}

[SerializationGenerator(0)]
public partial class UsagralemBallem : VoidCreature
{
    [Constructible]
    public UsagralemBallem() : base(AIType.AI_Melee)
    {
        Hue = 2071;
        Body = 318;
        BaseSoundID = 0x165;
        SetStr(900, 1000);
        SetDex(1028);
        SetInt(1000, 1100);
        SetHits(2000, 2200);
        SetMana(5000);
        SetDamage(17, 21);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 30, 40);
        SetResistance(ResistanceType.Fire, 40, 60);
        SetResistance(ResistanceType.Cold, 40, 60);
        SetResistance(ResistanceType.Poison, 40, 60);
        SetResistance(ResistanceType.Energy, 40, 60);
        SetSkill(SkillName.MagicResist, 80.0, 90.0);
        SetSkill(SkillName.Tactics, 80.0, 90.0);
        SetSkill(SkillName.Wrestling, 80.0, 90.0);
        Fame = 18000;
        Karma = -18000;
        VirtualArmor = 64;
        PackItem(new DaemonBone(30));
    }

    public override string DefaultName => "an Usagrallem Ballem";
    public override string CorpseName => "an usagralem ballem corpse";
    public override VoidLineage Lineage => VoidLineage.Killing;
    public override int Stage => 3;
    public override bool IgnoreYoungProtection => Core.ML;
    public override bool BardImmune => !Core.SE;
    public override bool Unprovokable => Core.SE;
    public override bool AreaPeaceImmune => Core.SE;
    public override Poison PoisonImmune => Poison.Lethal;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.UltraRich);
        AddLoot(LootPack.FilthyRich, 2);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (corpse is { Deleted: false } && !Controlled && !Summoned && Utility.RandomDouble() < 0.3)
        {
            corpse.DropItem(new AncientPotteryFragments());
        }
    }
}

[SerializationGenerator(0)]
public partial class Ortanord : BaseCreature
{
    [Constructible]
    public Ortanord() : base(AIType.AI_Melee, FightMode.Aggressor, 10, 1)
    {
        Body = 58;
        Hue = 2071;
        BaseSoundID = 466;
        SetStr(50, 50);
        SetDex(50, 50);
        SetInt(51, 51);
        SetHits(100, 100);
        SetMana(1001, 1001);
        SetStam(50, 50);
        SetDamage(5, 8);
        SetDamageType(ResistanceType.Energy, 100);
        SetResistance(ResistanceType.Physical, 80, 90);
        SetResistance(ResistanceType.Fire, 80, 90);
        SetResistance(ResistanceType.Cold, 80, 90);
        SetResistance(ResistanceType.Poison, 80, 90);
        SetResistance(ResistanceType.Energy, 80, 90);
        SetSkill(SkillName.MagicResist, 104.4, 108.0);
        SetSkill(SkillName.Tactics, 19.0, 19.8);
        SetSkill(SkillName.Anatomy, 15.6, 16.8);
        SetSkill(SkillName.Wrestling, 15.4, 16.6);
        SetSkill(SkillName.Magery, 104.7, 107.3);
        SetSkill(SkillName.Meditation, 20.0, 20.0);
        Fame = 8000;
        Karma = -8000;
        VirtualArmor = 40;
        if (Utility.RandomDouble() < 0.25)
        {
            PackItem(new DaemonBone(10));
        }
    }

    public override string DefaultName => "Ortanord";
    public override string CorpseName => "an ortanord corpse";
    public override bool BardImmune => !Core.AOS;
    public override Poison PoisonImmune => Poison.Lethal;
    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.6;
        passiveSpeed = 1.2;
    }

    public override void GenerateLoot() => AddLoot(LootPack.Average, 2);
}
