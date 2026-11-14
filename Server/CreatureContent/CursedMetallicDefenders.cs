// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class CursedMetallicDefender : BaseCreature
{
    protected CursedMetallicDefender(AIType ai) : base(ai, FightMode.Closest, 10)
    {
        BaseSoundID = 451;
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 50, 60);
        SetResistance(ResistanceType.Poison, 20, 30);
        SetResistance(ResistanceType.Energy, 30, 40);
        Fame = 3000;
        Karma = -3000;
    }

    public override bool BleedImmune => true;
    public override OppositionGroup OppositionGroup => OppositionGroup.FeyAndUndead;
}

[SerializationGenerator(0)]
public sealed partial class CursedMetallicKnight : CursedMetallicDefender
{
    [Constructible]
    public CursedMetallicKnight() : base(AIType.AI_Melee)
    {
        Body = 147;
        Hue = 2127;
        VirtualArmor = 40;
        SetStr(196, 250);
        SetDex(76, 95);
        SetInt(36, 60);
        SetHits(118, 150);
        SetDamage(8, 18);
        SetDamageType(ResistanceType.Physical, 40);
        SetDamageType(ResistanceType.Cold, 60);
        SetResistance(ResistanceType.Physical, 35, 45);
        SetSkill(SkillName.MagicResist, 65.1, 80.0);
        SetSkill(SkillName.Tactics, 85.1, 100.0);
        SetSkill(SkillName.Wrestling, 85.1, 95.0);
    }

    public override string DefaultName => "a cursed metallic knight";
    public override string CorpseName => "a cursed metallic knight corpse";
}

[SerializationGenerator(0)]
public sealed partial class CursedMetallicMage : CursedMetallicDefender
{
    [Constructible]
    public CursedMetallicMage() : base(AIType.AI_Mage)
    {
        Body = 148;
        Hue = 2121;
        VirtualArmor = 38;
        SetStr(78, 91);
        SetDex(69, 74);
        SetInt(194, 201);
        SetHits(49, 56);
        SetDamage(3, 7);
        SetDamageType(ResistanceType.Physical, 0);
        SetDamageType(ResistanceType.Cold, 100);
        SetResistance(ResistanceType.Physical, 35, 40);
        SetSkill(SkillName.Wrestling, 46.6, 49.3);
        SetSkill(SkillName.Tactics, 46.2, 57.2);
        SetSkill(SkillName.MagicResist, 58.5, 63.2);
        SetSkill(SkillName.Magery, 68.4, 68.8);
        SetSkill(SkillName.EvalInt, 60.8, 69.4);
        SetSkill(SkillName.Necromancy, 89.0, 99.1);
        SetSkill(SkillName.SpiritSpeak, 90.0, 99.0);
    }

    public override string DefaultName => "a cursed metallic mage";
    public override string CorpseName => "a cursed metallic mage corpse";
}
