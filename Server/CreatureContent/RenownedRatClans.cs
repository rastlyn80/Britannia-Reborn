// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Misc;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class RenownedRatClan : AbyssRenownedCreature
{
    protected RenownedRatClan(int body, AIType ai) : base(body, 0, 437, ai)
    {
        SetDamageType(ResistanceType.Physical, 100);
    }

    public override InhumanSpeech SpeechType => InhumanSpeech.Ratman;
    public override bool CanRummageCorpses => true;
    public override int Hides => 8;
    public override HideType HideType => HideType.Spined;
}

[SerializationGenerator(0)]
public sealed partial class RakktaviRenowned : RenownedRatClan
{
    [Constructible]
    public RakktaviRenowned() : base(142, AIType.AI_Archer)
    {
        SetStr(119);
        SetDex(279);
        SetInt(327);
        SetHits(50000);
        SetMana(327);
        SetStam(279);
        SetDamage(8, 10);
        SetResistance(ResistanceType.Physical, 20, 30);
        SetResistance(ResistanceType.Fire, 10, 25);
        SetResistance(ResistanceType.Cold, 30, 40);
        SetResistance(ResistanceType.Poison, 10, 20);
        SetResistance(ResistanceType.Energy, 10, 20);
        SetSkill(SkillName.Archery, 80.1, 90.0);
        SetSkill(SkillName.MagicResist, 66.0);
        SetSkill(SkillName.Tactics, 68.1);
        SetSkill(SkillName.Wrestling, 85.5);
        Fame = 6500;
        Karma = -6500;
        VirtualArmor = 56;
        AddItem(new Bow());
        PackItem(new Arrow(Utility.RandomMinMax(10, 30)));
    }

    public override string DefaultName => "Rakktavi";
    public override string CorpseName => "Rakktavi [Renowned] corpse";
    public override void GenerateLoot() => AddLoot(LootPack.UltraRich, 3);
}

[SerializationGenerator(0)]
public sealed partial class TikitaviRenowned : RenownedRatClan
{
    [Constructible]
    public TikitaviRenowned() : base(42, AIType.AI_Melee)
    {
        SetStr(315, 354);
        SetDex(139, 177);
        SetInt(243, 288);
        SetHits(50000);
        SetMana(243, 288);
        SetStam(139, 177);
        SetDamage(7, 9);
        SetResistance(ResistanceType.Physical, 26, 28);
        SetResistance(ResistanceType.Fire, 22, 25);
        SetResistance(ResistanceType.Cold, 30, 38);
        SetResistance(ResistanceType.Poison, 14, 17);
        SetResistance(ResistanceType.Energy, 15, 18);
        SetSkill(SkillName.MagicResist, 40.4);
        SetSkill(SkillName.Tactics, 73.6);
        SetSkill(SkillName.Wrestling, 66.5);
        Fame = 1500;
        Karma = -1500;
        VirtualArmor = 28;
    }

    public override string DefaultName => "Tikitavi";
    public override string CorpseName => "Tikitavi [Renowned] corpse";
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 3);
    protected override Item? RollSharedArtifact() => Utility.RandomBool() ? new MysticsGarb() : null;
}

[SerializationGenerator(0)]
public sealed partial class VitaviRenowned : RenownedRatClan
{
    [Constructible]
    public VitaviRenowned() : base(143, AIType.AI_Mage)
    {
        SetStr(300, 350);
        SetDex(250, 300);
        SetInt(300, 350);
        SetHits(45000, 50000);
        SetDamage(7, 14);
        SetResistance(ResistanceType.Physical, 50, 60);
        SetResistance(ResistanceType.Fire, 30, 50);
        SetResistance(ResistanceType.Cold, 60, 80);
        SetResistance(ResistanceType.Poison, 20, 30);
        SetResistance(ResistanceType.Energy, 30, 40);
        SetSkill(SkillName.EvalInt, 70.1, 80.0);
        SetSkill(SkillName.Magery, 70.1, 80.0);
        SetSkill(SkillName.MagicResist, 75.1, 100.0);
        SetSkill(SkillName.Tactics, 70.1, 75.0);
        SetSkill(SkillName.Wrestling, 50.1, 75.0);
        Fame = 7500;
        Karma = -7500;
        VirtualArmor = 44;
    }

    public override string DefaultName => "Vitavi";
    public override string CorpseName => "Vitavi [Renowned] corpse";
    public override int Meat => 1;
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 3);
}
