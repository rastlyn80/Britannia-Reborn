// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Collections;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class AbyssRenownedCreature : BaseCreature
{
    protected static Item CreateSharedArtifact() => Utility.Random(3) switch
    {
        0 => new AnimatedLegsoftheInsaneTinker(),
        1 => new PillarOfStrength(),
        _ => new StormCaller()
    };

    protected AbyssRenownedCreature(int body, int hue, int sound, AIType ai = AIType.AI_Mage) : base(ai, FightMode.Closest, 18, 1)
    {
        Body = body;
        Hue = hue;
        BaseSoundID = sound;
        Title = "[Renowned]";
    }

    public override bool OnBeforeDeath()
    {
        if (!base.OnBeforeDeath())
        {
            return false;
        }

        if (!NoKillAwards)
        {
            var roll = Utility.RandomDouble();
            var artifact = roll < 0.05 ? RollUniqueArtifact() : roll < 0.15 ? RollSharedArtifact() : null;
            if (artifact != null)
            {
                AwardArtifact(artifact);
            }
        }
        return true;
    }

    protected virtual Item? RollUniqueArtifact() => null;
    protected virtual Item? RollSharedArtifact() => null;

    private void AwardArtifact(Item artifact)
    {
        using var eligible = PooledRefList<DamageStore>.Create();
        var total = 0;
        foreach (var entry in GetLootingRights(DamageEntries, HitsMax))
        {
            var player = entry.m_Mobile;
            if (entry.m_Damage > 0 && player is PlayerMobile { Alive: true } && player.Map == Map &&
                player.InRange(Location, 32) && player.Backpack?.CheckHold(player, artifact, false) == true)
            {
                eligible.Add(entry);
                total += entry.m_Damage;
            }
        }

        if (total > 0)
        {
            var selection = Utility.Random(total);
            foreach (var entry in eligible)
            {
                selection -= entry.m_Damage;
                if (selection < 0)
                {
                    var player = entry.m_Mobile;
                    if (player.Backpack?.TryDropItem(player, artifact, false) == true)
                    {
                        player.PlaySound(0x5B4);
                        player.SendLocalizedMessage(1062317);
                        return;
                    }
                    break;
                }
            }
        }
        artifact.Delete();
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.1;
        passiveSpeed = 0.2;
    }
}

[SerializationGenerator(0)]
public sealed partial class FireDaemonRenowned : AbyssRenownedCreature
{
    [Constructible]
    public FireDaemonRenowned() : base(40, 243, 357)
    {
        SetStr(800, 1199);
        SetDex(200, 250);
        SetInt(202, 336);
        SetHits(1111, 1478);
        SetDamage(22, 29);
        SetDamageType(ResistanceType.Physical, 50);
        SetDamageType(ResistanceType.Fire, 25);
        SetDamageType(ResistanceType.Energy, 25);
        SetResistance(ResistanceType.Physical, 60, 93);
        SetResistance(ResistanceType.Fire, 60, 100);
        SetResistance(ResistanceType.Cold, 40, 70);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 37, 50);
        SetSkill(SkillName.MagicResist, 110.1, 132.6);
        SetSkill(SkillName.Tactics, 86.9, 95.5);
        SetSkill(SkillName.Wrestling, 42.2, 98.8);
        SetSkill(SkillName.Magery, 97.1, 100.8);
        SetSkill(SkillName.EvalInt, 91.1, 91.8);
        SetSkill(SkillName.Meditation, 45.4, 94.1);
        SetSkill(SkillName.Anatomy, 45.4, 74.1);
        Fame = 7000;
        Karma = -10000;
        VirtualArmor = 55;
    }

    public override string DefaultName => "Fire Daemon";
    public override string CorpseName => "Fire Daemon [Renowned] corpse";
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.ConcussionBlow;
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 2);
    protected override Item RollUniqueArtifact() => Utility.RandomBool()
        ? new MantleOfTheFallen() : new ResonantStaffofEnlightenment();
}

[SerializationGenerator(0)]
public sealed partial class PixieRenowned : AbyssRenownedCreature
{
    [Constructible]
    public PixieRenowned() : base(128, 0, 0x467)
    {
        SetStr(350, 380);
        SetDex(450, 600);
        SetInt(700, 850);
        SetHits(9100, 9200);
        SetStam(450, 600);
        SetMana(700, 800);
        SetDamage(9, 15);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 70, 90);
        SetResistance(ResistanceType.Fire, 60, 70);
        SetResistance(ResistanceType.Cold, 70, 80);
        SetResistance(ResistanceType.Poison, 60, 70);
        SetResistance(ResistanceType.Energy, 60, 70);
        SetSkill(SkillName.EvalInt, 100.0);
        SetSkill(SkillName.Magery, 90.1, 110.0);
        SetSkill(SkillName.Meditation, 100.0);
        SetSkill(SkillName.MagicResist, 110.5, 150.0);
        SetSkill(SkillName.Tactics, 100.1, 120.0);
        SetSkill(SkillName.Wrestling, 100.1, 120.0);
        Fame = 7000;
        Karma = 7000;
        VirtualArmor = 100;
    }

    public override string DefaultName => "Pixie";
    public override string CorpseName => "Pixie [Renowned] corpse";
    public override bool InitialInnocent => true;
    public override HideType HideType => HideType.Spined;
    public override int Hides => 5;
    public override int Meat => 1;
    public override OppositionGroup OppositionGroup => OppositionGroup.FeyAndUndead;
    public override void GenerateLoot() => AddLoot(LootPack.UltraRich, 2);
    protected override Item RollUniqueArtifact() => Utility.RandomBool()
        ? new DemonHuntersStandard() : new DragonJadeEarrings();
    protected override Item RollSharedArtifact() => Utility.RandomBool()
        ? new PillarOfStrength() : new SwordOfShatteredHopes();
}

[SerializationGenerator(0)]
public sealed partial class DevourerRenowned : AbyssRenownedCreature
{
    [Constructible]
    public DevourerRenowned() : base(303, 0, 357)
    {
        SetStr(801, 950);
        SetDex(126, 175);
        SetInt(201, 250);
        SetHits(2000);
        SetDamage(22, 26);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 45, 55);
        SetResistance(ResistanceType.Fire, 25, 35);
        SetResistance(ResistanceType.Cold, 15, 25);
        SetResistance(ResistanceType.Poison, 60, 70);
        SetResistance(ResistanceType.Energy, 40, 50);
        SetSkill(SkillName.Necromancy, 90.1, 100.0);
        SetSkill(SkillName.SpiritSpeak, 90.1, 100.0);
        SetSkill(SkillName.EvalInt, 90.1, 100.0);
        SetSkill(SkillName.Magery, 90.1, 100.0);
        SetSkill(SkillName.Meditation, 90.1, 100.0);
        SetSkill(SkillName.MagicResist, 90.1, 105.0);
        SetSkill(SkillName.Tactics, 75.1, 85.0);
        SetSkill(SkillName.Wrestling, 80.1, 100.0);
        Fame = 9500;
        Karma = -9500;
        VirtualArmor = 44;
    }

    public override string DefaultName => "Devourer of Souls";
    public override string CorpseName => "Devourer of Souls [Renowned] corpse";
    public override Poison PoisonImmune => Poison.Lethal;
    public override int Meat => 3;
    protected override Item RollSharedArtifact() => CreateSharedArtifact();
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 2);
}

[SerializationGenerator(0)]
public sealed partial class AcidElementalRenowned : AbyssRenownedCreature
{
    [Constructible]
    public AcidElementalRenowned() : base(158, 0, 278)
    {
        SetStr(450, 600);
        SetDex(120, 185);
        SetInt(361, 435);
        SetHits(2000, 2400);
        SetDamage(9, 15);
        SetDamageType(ResistanceType.Physical, 25);
        SetDamageType(ResistanceType.Poison, 50);
        SetDamageType(ResistanceType.Energy, 25);
        SetResistance(ResistanceType.Physical, 40, 70);
        SetResistance(ResistanceType.Fire, 30, 50);
        SetResistance(ResistanceType.Cold, 20, 40);
        SetResistance(ResistanceType.Poison, 10, 30);
        SetResistance(ResistanceType.Energy, 20, 50);
        SetSkill(SkillName.EvalInt, 80.1, 100.0);
        SetSkill(SkillName.Magery, 80.1, 100.0);
        SetSkill(SkillName.MagicResist, 65.2, 100.0);
        SetSkill(SkillName.Tactics, 90.1, 100.0);
        SetSkill(SkillName.Wrestling, 80.1, 100.0);
        Fame = 12500;
        Karma = -12500;
        VirtualArmor = 70;
    }

    public override string DefaultName => "Acid Elemental";
    public override string CorpseName => "Acid Elemental [Renowned] corpse";
    public override bool BleedImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override void GenerateLoot() => AddLoot(LootPack.Rich, 2);
    // The second reference result is the costume, which still needs its transformation route.
    protected override Item? RollUniqueArtifact() => Utility.RandomBool() ? new BreastplateOfTheBerserker() : null;
    protected override Item RollSharedArtifact() => new MysticsGarb();
}

[SerializationGenerator(0)]
public sealed partial class AncientLichRenowned : AbyssRenownedCreature
{
    [Constructible]
    public AncientLichRenowned() : base(78, 0, 412)
    {
        SetStr(250, 305);
        SetDex(96, 115);
        SetInt(966, 1045);
        SetHits(2000, 2500);
        SetDamage(15, 27);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Cold, 40);
        SetDamageType(ResistanceType.Energy, 40);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 25, 30);
        SetResistance(ResistanceType.Cold, 50, 60);
        SetResistance(ResistanceType.Poison, 50, 60);
        SetResistance(ResistanceType.Energy, 25, 30);
        SetSkill(SkillName.EvalInt, 120.1, 130.0);
        SetSkill(SkillName.Magery, 120.1, 130.0);
        SetSkill(SkillName.Meditation, 100.1, 101.0);
        SetSkill(SkillName.MagicResist, 175.2, 200.0);
        SetSkill(SkillName.Tactics, 90.1, 100.0);
        SetSkill(SkillName.Wrestling, 75.1, 100.0);
        Fame = 23000;
        Karma = -23000;
        VirtualArmor = 60;
    }

    public override string DefaultName => "Ancient Lich";
    public override string CorpseName => "Ancient Lich [Renowned] corpse";
    public override OppositionGroup OppositionGroup => OppositionGroup.FeyAndUndead;
    public override bool Unprovokable => true;
    public override bool BleedImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override int GetIdleSound() => 0x19D;
    public override int GetAngerSound() => 0x175;
    public override int GetDeathSound() => 0x108;
    public override int GetAttackSound() => 0xE2;
    public override int GetHurtSound() => 0x28B;
    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 2);
    protected override Item RollUniqueArtifact() => Utility.RandomBool()
        ? new DefenderOfTheMagus() : new SpinedBloodwormBracers();
    protected override Item RollSharedArtifact() => new SummonersKilt();
}
