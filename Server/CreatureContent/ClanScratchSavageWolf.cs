// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class ClanScratchSavageWolf : BaseCreature
{
    [Constructible]
    public ClanScratchSavageWolf() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 98;
        Hue = 0x2C;
        BaseSoundID = 229;
        SetStr(170);
        SetDex(244);
        SetInt(57);
        SetHits(65);
        SetDamage(8, 10);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Cold, 80);
        SetResistance(ResistanceType.Physical, 30, 35);
        SetResistance(ResistanceType.Cold, 40, 45);
        SetResistance(ResistanceType.Poison, 25, 30);
        SetResistance(ResistanceType.Energy, 20, 25);
        SetSkill(SkillName.Swords, 99.0, 100.0);
        SetSkill(SkillName.MagicResist, 41.5, 42.5);
        SetSkill(SkillName.Tactics, 65.1, 70.0);
        SetSkill(SkillName.Wrestling, 42.3, 45.5);
        Fame = 3400;
        Karma = -3400;
        VirtualArmor = 50;
    }

    public override string DefaultName => "Clan Scratch Savage Wolf";
    public override string CorpseName => "a clan scratch savage wolf corpse";
    public override int Meat => 1;
    public override FoodType FavoriteFood => FoodType.Meat;
    public override PackInstinct PackInstinct => PackInstinct.Canine;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.ParalyzingBlow;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Average);
        AddLoot(LootPack.Meager);
    }

    public override void GenerateLoot(bool spawning)
    {
        base.GenerateLoot(spawning);
        if (!spawning && !Summoned && !Controlled && Utility.RandomDouble() < 0.2)
        {
            PackItem(new ReflectiveWolfEye());
        }
    }
}
