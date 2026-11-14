// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class RenownedGoblin : AbyssRenownedCreature
{
    protected RenownedGoblin(int hue, AIType ai) : base(723, hue, 0x600, ai)
    {
        SetDamage(5, 7);
        SetResistance(ResistanceType.Cold, 40, 50);
        SetResistance(ResistanceType.Poison, 40, 50);
        SetResistance(ResistanceType.Energy, 20, 25);
        SetSkill(SkillName.MagicResist, 120.0, 125.0);
        SetSkill(SkillName.Tactics, 95.0, 100.0);
        SetSkill(SkillName.Wrestling, 100.0, 110.0);
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
}

[SerializationGenerator(0)]
public sealed partial class GrayGoblinMageRenowned : RenownedGoblin
{
    [Constructible]
    public GrayGoblinMageRenowned() : base(1900, AIType.AI_Mage)
    {
        SetStr(550, 600);
        SetDex(70, 75);
        SetInt(500, 600);
        SetHits(1100, 1300);
        SetResistance(ResistanceType.Physical, 30, 35);
        SetResistance(ResistanceType.Fire, 45, 50);
        SetSkill(SkillName.EvalInt, 100.0, 120.0);
        SetSkill(SkillName.Meditation, 100.0, 105.0);
        SetSkill(SkillName.Magery, 100.0, 110.0);
    }

    public override string DefaultName => "Gray Goblin Mage";
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich);
    protected override Item RollSharedArtifact() => Utility.Random(4) switch
    {
        0 => new StormCaller(),
        1 => new TorcOfTheGuardians(),
        2 => new GiantSteps(),
        _ => new CavalrysFolly()
    };
}

[SerializationGenerator(0)]
public sealed partial class GreenGoblinAlchemistRenowned : RenownedGoblin
{
    [Constructible]
    public GreenGoblinAlchemistRenowned() : base(0, AIType.AI_Melee)
    {
        SetStr(600, 650);
        SetDex(50, 70);
        SetInt(100, 250);
        SetHits(1000, 1500);
        SetResistance(ResistanceType.Physical, 50, 55);
        SetResistance(ResistanceType.Fire, 55, 60);
    }

    public override string DefaultName => "Green Goblin Alchemist";
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 2);
    protected override Item RollUniqueArtifact() => Utility.RandomBool() ? new ObsidianEarrings() : new TheImpalersPick();
}

[SerializationGenerator(0)]
public sealed partial class SkeletalDragonRenowned : AbyssRenownedCreature
{
    private static readonly MonsterAbility[] Abilities = [new RenownedColdBreath()];

    [Constructible]
    public SkeletalDragonRenowned() : base(104, 906, 0x488)
    {
        SetStr(898, 1030);
        SetDex(100, 200);
        SetInt(488, 620);
        SetHits(558, 599);
        SetDamage(29, 35);
        SetDamageType(ResistanceType.Physical, 75);
        SetDamageType(ResistanceType.Fire, 25);
        SetResistance(ResistanceType.Physical, 75, 80);
        SetResistance(ResistanceType.Fire, 40, 60);
        SetResistance(ResistanceType.Cold, 40, 60);
        SetResistance(ResistanceType.Poison, 70, 80);
        SetResistance(ResistanceType.Energy, 40, 60);
        SetSkill(SkillName.EvalInt, 80.1, 100.0);
        SetSkill(SkillName.Magery, 80.1, 100.0);
        SetSkill(SkillName.MagicResist, 100.3, 130.0);
        SetSkill(SkillName.Tactics, 97.6, 100.0);
        SetSkill(SkillName.Wrestling, 97.6, 100.0);
        Fame = 22500;
        Karma = -22500;
        VirtualArmor = 80;
    }

    public override string DefaultName => "Skeletal Dragon";
    public override string CorpseName => "a skeletal dragon corpse";
    public override bool ReacquireOnMovement => true;
    public override double BonusPetDamageScalar => Core.SE ? 3.0 : 1.0;
    public override bool AutoDispel => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override bool BleedImmune => true;
    public override int Meat => 19;
    public override int Hides => 20;
    public override HideType HideType => HideType.Barbed;
    public override void GenerateLoot() => AddLoot(LootPack.Rich, 3);
    public override MonsterAbility[] GetMonsterAbilities() => Abilities;
    protected override Item RollSharedArtifact() => Utility.Random(4) switch
    {
        0 => new AxeOfAbandon(),
        1 => new DemonBridleRing(),
        2 => new VoidInfusedKilt(),
        _ => new BladeOfBattle()
    };

    private sealed class RenownedColdBreath : ColdBreath
    {
        public override double ChanceToTrigger => 0.10;
        public override int BreathRange(BaseCreature source) => 12;

        public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile target)
        {
            if (source.Mana >= 30 && CanFireBreathTarget(source, target))
            {
                source.Mana -= 30;
                source.RevealingAction();
                base.Trigger(trigger, source, target);
            }
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class FireElementalRenowned : AbyssRenownedCreature
{
    [Constructible]
    public FireElementalRenowned() : base(15, 1161, 838)
    {
        SetStr(450, 500);
        SetDex(200, 250);
        SetInt(300, 350);
        SetHits(1200, 1600);
        SetDamage(7, 9);
        SetDamageType(ResistanceType.Physical, 25);
        SetDamageType(ResistanceType.Fire, 75);
        SetResistance(ResistanceType.Physical, 45, 60);
        SetResistance(ResistanceType.Fire, 70, 80);
        SetResistance(ResistanceType.Cold, 5, 10);
        SetResistance(ResistanceType.Poison, 30, 50);
        SetResistance(ResistanceType.Energy, 40, 60);
        SetSkill(SkillName.EvalInt, 100.1, 110.0);
        SetSkill(SkillName.Magery, 105.1, 110.0);
        SetSkill(SkillName.MagicResist, 110.2, 120.0);
        SetSkill(SkillName.Tactics, 100.1, 105.0);
        SetSkill(SkillName.Wrestling, 90.1, 100.0);
        Fame = 4500;
        Karma = -4500;
        VirtualArmor = 40;
        PackItem(new SulfurousAsh(3));
        AddItem(new LightSource());
    }

    public override string DefaultName => "Fire Elemental";
    public override string CorpseName => "a fire elemental corpse";
    public override double DispelDifficulty => 117.5;
    public override double DispelFocus => 45.0;
    public override bool BleedImmune => true;
    public override int TreasureMapLevel => 2;
    public override void GenerateLoot() => AddLoot(LootPack.UltraRich);
    protected override Item RollUniqueArtifact() => new JadeWarAxe();
    protected override Item RollSharedArtifact() => Utility.Random(3) switch
    {
        0 => new TokenOfHolyFavor(),
        1 => new SwordOfShatteredHopes(),
        _ => new LegacyOfDespair()
    };
}
