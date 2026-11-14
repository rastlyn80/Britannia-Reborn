// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class AbyssGoblin : BaseCreature
{
    protected AbyssGoblin(AIType ai, int hue) : base(ai, FightMode.Closest, 10, 1)
    {
        Body = 723;
        Hue = hue;
        SetDamage(5, 7);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 40, 50);
        Fame = 1500;
        Karma = -1500;
        VirtualArmor = 28;

        Item? weapon = Utility.Random(20) switch
        {
            0 => new Scimitar(),
            1 => new Katana(),
            2 => new WarMace(),
            3 => new WarHammer(),
            4 => new Kryss(),
            5 => new Pitchfork(),
            _ => null
        };
        if (weapon != null)
        {
            PackItem(weapon);
        }

        PackItem(new ThighBoots());
        PackItem(Utility.Random(3) switch
        {
            0 => new Ribs(),
            1 => new Shaft(),
            _ => new Candle()
        });

        if (Utility.RandomDouble() < 0.2)
        {
            PackItem(new BolaBall());
        }
    }

    public override string CorpseName => "a goblin corpse";
    public override int GetAngerSound() => 0x600;
    public override int GetIdleSound() => 0x600;
    public override int GetAttackSound() => 0x5FD;
    public override int GetHurtSound() => 0x5FF;
    public override int GetDeathSound() => 0x5FE;
    public override bool CanRummageCorpses => true;
    public override int TreasureMapLevel => 1;
    public override int Meat => 1;
    public override void GenerateLoot() => AddLoot(LootPack.Meager);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}

[SerializationGenerator(0)]
public sealed partial class GreenGoblin : AbyssGoblin
{
    [Constructible]
    public GreenGoblin() : base(AIType.AI_Melee, 0)
    {
        SetStr(252, 343);
        SetDex(60, 74);
        SetInt(117, 148);
        SetHits(162, 208);
        SetStam(60, 74);
        SetMana(117, 148);
        SetResistance(ResistanceType.Fire, 30, 39);
        SetResistance(ResistanceType.Cold, 27, 35);
        SetResistance(ResistanceType.Poison, 11, 20);
        SetResistance(ResistanceType.Energy, 10, 20);
        SetSkill(SkillName.MagicResist, 120.5, 128.8);
        SetSkill(SkillName.Tactics, 80.9, 89.9);
        SetSkill(SkillName.Anatomy, 83.1, 89.6);
        SetSkill(SkillName.Wrestling, 93.0, 108.3);
    }

    public override string DefaultName => "a green goblin";
}

[SerializationGenerator(0)]
public sealed partial class GreenGoblinAlchemist : AbyssGoblin
{
    [Constructible]
    public GreenGoblinAlchemist() : base(AIType.AI_Melee, 0)
    {
        SetStr(282, 331);
        SetDex(62, 79);
        SetInt(100, 149);
        SetHits(163, 197);
        SetStam(62, 79);
        SetMana(100, 149);
        SetResistance(ResistanceType.Fire, 45, 55);
        SetResistance(ResistanceType.Cold, 30, 40);
        SetResistance(ResistanceType.Poison, 35, 45);
        SetResistance(ResistanceType.Energy, 11, 20);
        SetSkill(SkillName.MagicResist, 120.3, 129.2);
        SetSkill(SkillName.Tactics, 81.9, 87.1);
        SetSkill(SkillName.Anatomy, 0.0, 0.0);
        SetSkill(SkillName.Wrestling, 94.8, 106.9);
    }

    public override string DefaultName => "a green goblin alchemist";
}

[SerializationGenerator(0)]
public sealed partial class GrayGoblin : AbyssGoblin
{
    [Constructible]
    public GrayGoblin() : base(AIType.AI_Melee, 1900)
    {
        SetStr(258, 327);
        SetDex(62, 80);
        SetInt(103, 150);
        SetHits(159, 194);
        SetStam(62, 80);
        SetMana(103, 150);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 25, 32);
        SetResistance(ResistanceType.Poison, 10, 19);
        SetResistance(ResistanceType.Energy, 10, 20);
        SetSkill(SkillName.MagicResist, 120.9, 129.1);
        SetSkill(SkillName.Tactics, 80.6, 89.4);
        SetSkill(SkillName.Anatomy, 80.3, 89.4);
        SetSkill(SkillName.Wrestling, 96.1, 105.5);
    }

    public override string DefaultName => "a gray goblin";
}

[SerializationGenerator(0)]
public sealed partial class GrayGoblinMage : AbyssGoblin
{
    [Constructible]
    public GrayGoblinMage() : base(AIType.AI_Mage, 1900)
    {
        SetStr(227, 285);
        SetDex(70, 88);
        SetInt(451, 499);
        SetHits(129, 151);
        SetStam(70, 88);
        SetMana(451, 499);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 25, 32);
        SetResistance(ResistanceType.Poison, 10, 19);
        SetResistance(ResistanceType.Energy, 10, 20);
        SetSkill(SkillName.MagicResist, 141.9, 147.1);
        SetSkill(SkillName.Tactics, 80.7, 86.9);
        SetSkill(SkillName.Anatomy, 81.9, 89.4);
        SetSkill(SkillName.Wrestling, 90.5, 104.2);
        SetSkill(SkillName.Magery, 105.5, 119.1);
        SetSkill(SkillName.EvalInt, 94.9, 107.7);
    }

    public override string DefaultName => "a gray goblin mage";
    public override string CorpseName => "a goblin mage corpse";
}
