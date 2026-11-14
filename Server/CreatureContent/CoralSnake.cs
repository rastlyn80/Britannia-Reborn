// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class CoralSnake : BaseCreature
{
    [Constructible]
    public CoralSnake() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 52;
        Hue = 33;
        BaseSoundID = 0xDB;
        SetStr(205, 340);
        SetDex(248, 300);
        SetInt(28, 35);
        SetHits(132, 200);
        SetMana(28, 35);
        SetDamage(5, 21);

        SetDamageType(ResistanceType.Physical, 50);
        SetDamageType(ResistanceType.Poison, 50);
        // The reference's second physical roll supplies the effective resistance.
        SetResistance(ResistanceType.Physical, 5, 20);
        SetResistance(ResistanceType.Fire, 5, 20);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 5, 20);
        SetSkill(SkillName.Poisoning, 99.7, 110.9);
        SetSkill(SkillName.MagicResist, 98.1, 105.0);
        SetSkill(SkillName.Tactics, 82.0, 98.0);
        SetSkill(SkillName.Wrestling, 90.3, 105.0);

        Fame = 300;
        Karma = -300;
        VirtualArmor = 16;
    }

    public override string DefaultName => "a coral snake";
    public override string CorpseName => "a snake corpse";
    public override Poison PoisonImmune => Poison.Lesser;
    public override Poison HitPoison => Poison.Deadly;
    public override int Meat => 1;
    public override FoodType FavoriteFood => FoodType.Eggs;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
