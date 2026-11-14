// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class LabyrinthAirElemental : BaseCreature
{
    protected LabyrinthAirElemental(int hue, int sound, int armor) : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 13;
        Hue = hue;
        BaseSoundID = sound;
        Fame = 4500;
        Karma = -4500;
        VirtualArmor = armor;
    }

    public override string CorpseName => $"the remains of {DefaultName}";
    public override bool GivesMLMinorArtifact => true;
    public override bool BleedImmune => true;
    public override double DispelDifficulty => 117.5;
    public override double DispelFocus => 45.0;
    public override int TreasureMapLevel => 2;

    protected void SetCombat(
        (int Min, int Max) physical, (int Min, int Max) fire, (int Min, int Max) cold,
        (int Min, int Max) poison, (int Min, int Max) energy,
        (double Min, double Max) eval, (double Min, double Max) magery, (double Min, double Max) resist,
        (double Min, double Max) tactics, (double Min, double Max) wrestling)
    {
        SetResistance(ResistanceType.Physical, physical.Min, physical.Max);
        SetResistance(ResistanceType.Fire, fire.Min, fire.Max);
        SetResistance(ResistanceType.Cold, cold.Min, cold.Max);
        SetResistance(ResistanceType.Poison, poison.Min, poison.Max);
        SetResistance(ResistanceType.Energy, energy.Min, energy.Max);
        SetSkill(SkillName.EvalInt, eval.Min, eval.Max);
        SetSkill(SkillName.Magery, magery.Min, magery.Max);
        SetSkill(SkillName.MagicResist, resist.Min, resist.Max);
        SetSkill(SkillName.Tactics, tactics.Min, tactics.Max);
        SetSkill(SkillName.Wrestling, wrestling.Min, wrestling.Max);
    }

    protected virtual LootPack PrimaryLoot => LootPack.Average;
    protected virtual int PrimaryLootCount => 1;

    public override void GenerateLoot()
    {
        AddLoot(PrimaryLoot, PrimaryLootCount);
        AddLoot(LootPack.Meager);
        AddLoot(LootPack.LowScrolls);
        AddLoot(LootPack.MedScrolls);
    }
}

[SerializationGenerator(0)]
public sealed partial class Flurry : LabyrinthAirElemental
{
    [Constructible]
    public Flurry() : base(3, 655, 54)
    {
        SetStr(149, 195);
        SetDex(218, 264);
        SetInt(130, 199);
        SetHits(474, 477);
        SetDamage(10, 15);
        SetDamageType(ResistanceType.Energy, 20);
        SetDamageType(ResistanceType.Cold, 80);
        SetCombat((56, 57), (38, 44), (40, 45), (31, 37), (39, 41),
            (99.1, 100.2), (105.1, 108.8), (104.0, 112.8), (113.1, 119.8), (105.6, 106.4));
        PackArcanceScroll(0.5);
    }

    public override string DefaultName => "Flurry";
    protected override LootPack PrimaryLoot => LootPack.Rich;
    protected override int PrimaryLootCount => 10;
}

[SerializationGenerator(0)]
public sealed partial class Mistral : LabyrinthAirElemental
{
    [Constructible]
    public Mistral() : base(924, 263, 40)
    {
        SetStr(134, 201);
        SetDex(226, 238);
        SetInt(126, 134);
        SetHits(386, 609);
        SetDamage(17, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetDamageType(ResistanceType.Cold, 40);
        SetDamageType(ResistanceType.Physical, 40);
        SetCombat((55, 64), (36, 40), (33, 39), (30, 39), (49, 53),
            (96.2, 97.8), (100.8, 112.9), (106.2, 111.2), (110.2, 117.1), (100.3, 104.0));
        PackArcanceScroll(0.5);
    }

    public override string DefaultName => "Mistral";
}

[SerializationGenerator(0)]
public sealed partial class Tempest : LabyrinthAirElemental
{
    [Constructible]
    public Tempest() : base(1175, 263, 40)
    {
        SetStr(116, 135);
        SetDex(166, 185);
        SetInt(101, 125);
        SetHits(602);
        SetDamage(18, 20);
        SetDamageType(ResistanceType.Energy, 80);
        SetDamageType(ResistanceType.Cold, 20);
        SetCombat((46, 46), (39, 39), (33, 33), (36, 36), (58, 58),
            (99.6, 99.6), (101, 101), (104.6, 104.6), (111.8, 111.8), (116, 116));
    }

    public override string DefaultName => "Tempest";
}

[SerializationGenerator(0)]
public sealed partial class Grim : Drake
{
    [Constructible]
    public Grim()
    {
        Hue = 1744;
        SetStr(527, 580);
        SetDex(284, 322);
        SetInt(249, 386);
        SetHits(1762, 2502);
        SetDamage(17, 25);
        SetResistance(ResistanceType.Physical, 55, 60);
        SetResistance(ResistanceType.Fire, 62, 68);
        SetResistance(ResistanceType.Cold, 52, 57);
        SetResistance(ResistanceType.Poison, 30, 40);
        SetResistance(ResistanceType.Energy, 40, 44);
        SetSkill(SkillName.MagicResist, 105.8, 115.6);
        SetSkill(SkillName.Tactics, 102.8, 120.8);
        SetSkill(SkillName.Wrestling, 111.7, 119.2);
        SetSkill(SkillName.Anatomy, 105.0, 128.4);
        Fame = 17500;
        Karma = -5500;
        VirtualArmor = 54;
        Tamable = false;
        PackArcanceScroll(0.5);
    }

    public override string DefaultName => "Grim";
    public override string CorpseName => "the remains of Grim";
    public override bool GivesMLMinorArtifact => true;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.CrushingBlow;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.FilthyRich, 3);
        AddLoot(LootPack.MedScrolls);
        AddLoot(LootPack.HighScrolls, 2);
    }
}
