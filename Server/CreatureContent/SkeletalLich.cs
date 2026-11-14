// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class SkeletalLich : BaseCreature
{
    [Constructible]
    public SkeletalLich() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 309;
        Hue = 1345;
        BaseSoundID = 0x48D;
        SetStr(301, 350);
        SetDex(75);
        SetInt(151, 200);
        SetHits(1200);
        SetStam(150);
        SetMana(0);
        SetDamage(8, 10);
        SetDamageType(ResistanceType.Physical, 0);
        SetDamageType(ResistanceType.Cold, 50);
        SetDamageType(ResistanceType.Poison, 50);
        SetResistance(ResistanceType.Physical, 35, 45);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 50, 70);
        SetResistance(ResistanceType.Poison, 40, 50);
        SetResistance(ResistanceType.Energy, 20, 30);
        SetSkill(SkillName.EvalInt, 127.2);
        SetSkill(SkillName.Magery, 127.2);
        SetSkill(SkillName.Necromancy, 100.0, 120.0);
        SetSkill(SkillName.MagicResist, 187.1);
        SetSkill(SkillName.Tactics, 91.7);
        SetSkill(SkillName.Wrestling, 98.5);
        Fame = 6000;
        Karma = -6000;
        VirtualArmor = 40;
    }

    public override string DefaultName => "a skeletal lich";
    public override string CorpseName => "a skeletal corpse";
    public override bool BleedImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override int TreasureMapLevel => 1;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.Dismount;
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 2);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
