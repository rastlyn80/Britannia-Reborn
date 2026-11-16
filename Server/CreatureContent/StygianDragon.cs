// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class StygianDragon : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [MonsterAbilities.FireBreath];

    [Constructible]
    public StygianDragon() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 826;
        BaseSoundID = 362;
        SetStr(702);
        SetDex(250);
        SetInt(180);
        SetHits(30000);
        SetStam(431);
        SetMana(180);
        SetDamage(33, 55);
        SetDamageType(ResistanceType.Physical, 25);
        SetDamageType(ResistanceType.Fire, 50);
        SetDamageType(ResistanceType.Energy, 25);
        SetResistance(ResistanceType.Physical, 80, 90);
        SetResistance(ResistanceType.Fire, 80, 90);
        SetResistance(ResistanceType.Cold, 60, 70);
        SetResistance(ResistanceType.Poison, 80, 90);
        SetResistance(ResistanceType.Energy, 80, 90);
        SetSkill(SkillName.Anatomy, 100.0);
        SetSkill(SkillName.MagicResist, 150.0, 155.0);
        SetSkill(SkillName.Tactics, 120.7, 125.0);
        SetSkill(SkillName.Wrestling, 115.0, 117.7);
        Fame = 15000;
        Karma = -15000;
        VirtualArmor = 60;
    }

    public override string DefaultName => "Stygian Dragon";
    public override string CorpseName => "a stygian dragon corpse";
    public override bool AlwaysMurderer => true;
    public override bool AutoDispel => !Controlled;
    public override bool CanFlee => false;
    public override int Meat => 19;
    public override int Hides => 30;
    public override HideType HideType => HideType.Barbed;
    public override int Scales => 7;
    public override ScaleType ScaleType => ScaleType.Red;

    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
    public override WeaponAbility GetWeaponAbility() =>
        Utility.RandomBool() ? WeaponAbility.Bladeweave : WeaponAbility.TalonStrike;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.3;
        passiveSpeed = 0.5;
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.AosSuperBoss, 4);
        AddLoot(LootPack.Gems, 8);
    }
}
