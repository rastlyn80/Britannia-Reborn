// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class Rotworm : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [new RotwormBloodDisease()];

    [Constructible]
    public Rotworm() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 732;
        SetStr(200, 300);
        SetDex(80);
        SetInt(15, 20);
        SetHits(200, 250);
        SetStam(50);
        SetDamage(1, 5);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 35, 45);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 25, 35);
        SetResistance(ResistanceType.Poison, 65, 75);
        SetResistance(ResistanceType.Energy, 25, 35);
        SetSkill(SkillName.MagicResist, 25.0);
        SetSkill(SkillName.Tactics, 25.0);
        SetSkill(SkillName.Wrestling, 50.0);
        Fame = 500;
        Karma = -500;
    }

    public override string DefaultName => "a rotworm";
    public override string CorpseName => "a rotworm corpse";
    public override int Meat => 2;
    public override FoodType FavoriteFood => FoodType.Fish;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
    public override int GetAngerSound() => 0x62D;
    public override int GetIdleSound() => 0x62D;
    public override int GetAttackSound() => 0x62A;
    public override int GetHurtSound() => 0x62C;
    public override int GetDeathSound() => 0x62B;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.25;
        passiveSpeed = 0.5;
    }

    public override void GenerateLoot() => AddLoot(LootPack.Meager);

    public override void GenerateLoot(bool spawning)
    {
        base.GenerateLoot(spawning);
        if (!spawning && !Summoned)
        {
            Item remains = Utility.Random(8) switch
            {
                0 => new LeftArm(),
                1 => new RightArm(),
                2 => new Torso(),
                3 => new RightLeg(),
                4 => new LeftLeg(),
                5 => new Bone(),
                6 => new RibCage(),
                _ => new BonePile()
            };
            PackItem(remains);
        }
    }

    public override void OnCarve(Mobile from, Corpse corpse, Item with)
    {
        // The pinned server has no Rotworm entry in its built-in meat switch.
        if (Summoned || IsBonded || corpse.Animated || corpse.Carved)
        {
            base.OnCarve(from, corpse, with);
            return;
        }

        var amount = corpse.Map == Map.Felucca && Core.ML ? Meat * 2 : Meat;
        new Blood(0x122D).MoveToWorld(corpse.Location, corpse.Map);
        corpse.AddCarvedItem(new RawRotwormMeat(amount), from);
        corpse.Carved = true;
        from.SendLocalizedMessage(500467);
        if (corpse.IsCriminalAction(from))
        {
            from.CriminalAction(true);
        }
    }
}
