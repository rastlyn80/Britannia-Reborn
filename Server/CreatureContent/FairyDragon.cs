// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class FairyDragon : BaseCreature
{
    [Constructible]
    public FairyDragon() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 718;
        BaseSoundID = 362;
        SetStr(512, 558);
        SetDex(95, 105);
        SetInt(455, 501);
        SetHits(398, 403);
        SetDamage(15, 18);
        SetDamageType(ResistanceType.Fire, 20, 25);
        SetDamageType(ResistanceType.Cold, 20, 25);
        SetDamageType(ResistanceType.Poison, 20, 25);
        SetDamageType(ResistanceType.Energy, 20, 25);
        SetResistance(ResistanceType.Physical, 16, 30);
        SetResistance(ResistanceType.Fire, 41, 44);
        SetResistance(ResistanceType.Cold, 40, 49);
        SetResistance(ResistanceType.Poison, 40, 49);
        SetResistance(ResistanceType.Energy, 45, 47);
        SetSkill(SkillName.MagicResist, 99.1, 100.0);
        SetSkill(SkillName.Tactics, 60.6, 68.2);
        SetSkill(SkillName.Wrestling, 90.1, 92.5);
        SetSkill(SkillName.Mysticism, 101.8, 108.3);
        Fame = 15000;
        Karma = -15000;
        VirtualArmor = 39;
    }

    public override string DefaultName => "Fairy Dragon";
    public override string CorpseName => "a Fairy dragon corpse";
    protected override BaseAI ForcedAI => new AbyssMysticAI(this);
    public override bool AutoDispel => !Controlled;
    public override int TreasureMapLevel => 3;
    public override int Meat => 9;
    public override Poison HitPoison => Poison.Greater;
    public override double HitPoisonChance => 0.75;
    public override FoodType FavoriteFood => FoodType.Meat;
    public override int GetAttackSound() => 1513;
    public override int GetAngerSound() => 1558;
    public override int GetDeathSound() => 1514;
    public override int GetHurtSound() => 1515;
    public override int GetIdleSound() => 1516;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.MedScrolls, 2);
    }

    public override void OnDeath(Container corpse)
    {
        if (Utility.RandomDouble() < 0.25)
        {
            corpse.DropItem(new FairyDragonWing());
        }
        if (Utility.RandomDouble() < 0.10)
        {
            corpse.DropItem(new DraconicOrb());
        }

        base.OnDeath(corpse);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
