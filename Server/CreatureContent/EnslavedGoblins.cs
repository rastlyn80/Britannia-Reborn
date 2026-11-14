// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class EnslavedGoblin : AbyssGoblin
{
    protected EnslavedGoblin(int body, int strength, int dexterity, int intelligence, int health)
        : base(AIType.AI_Melee, 0)
    {
        Body = body;
        SetStr(strength);
        SetDex(dexterity);
        SetInt(intelligence);
        SetHits(health);
        SetStam(dexterity);
        SetMana(intelligence);
    }

    public override string CorpseName => "a goblin corpse";
    public override OppositionGroup OppositionGroup => OppositionGroup.SavagesAndOrcs;
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGoblinKeeper : EnslavedGoblin
{
    [Constructible]
    public EnslavedGoblinKeeper() : base(334, 297, 80, 118, 174)
    {
        SetResistance(ResistanceType.Physical, 47);
        SetResistance(ResistanceType.Fire, 37);
        SetResistance(ResistanceType.Cold, 29);
        SetResistance(ResistanceType.Poison, 10, 11);
        SetResistance(ResistanceType.Energy, 19);
        SetSkill(SkillName.MagicResist, 121.6, 122.2);
        SetSkill(SkillName.Tactics, 80.0, 82.8);
        SetSkill(SkillName.Anatomy, 82.0, 84.8);
        SetSkill(SkillName.Wrestling, 99.2, 100.7);
    }

    public override string DefaultName => "Enslaved Goblin Keeper";
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGoblinMage : EnslavedGoblin
{
    [Constructible]
    public EnslavedGoblinMage() : base(334, 297, 94, 510, 174)
    {
        SetResistance(ResistanceType.Physical, 22);
        SetResistance(ResistanceType.Fire, 36, 37);
        SetResistance(ResistanceType.Cold, 39);
        SetResistance(ResistanceType.Poison, 43);
        SetResistance(ResistanceType.Energy, 14);
        SetSkill(SkillName.MagicResist, 121.6, 149.7);
        SetSkill(SkillName.Tactics, 80.0, 85.2);
        SetSkill(SkillName.Anatomy, 82.0, 86.6);
        SetSkill(SkillName.Wrestling, 99.2, 106.4);
    }

    public override string DefaultName => "Enslaved Goblin Mage";
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGoblinScout : EnslavedGoblin
{
    [Constructible]
    public EnslavedGoblinScout() : base(334, 320, 74, 112, 182)
    {
        SetResistance(ResistanceType.Physical, 42);
        SetResistance(ResistanceType.Fire, 33);
        SetResistance(ResistanceType.Cold, 30);
        SetResistance(ResistanceType.Poison, 14);
        SetResistance(ResistanceType.Energy, 18);
        SetSkill(SkillName.MagicResist, 95.0);
        SetSkill(SkillName.Tactics, 80.0, 86.9);
        SetSkill(SkillName.Anatomy, 82.0, 89.3);
        SetSkill(SkillName.Wrestling, 99.2, 113.7);
    }

    public override string DefaultName => "Enslaved Goblin Scout";
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGrayGoblin : EnslavedGoblin
{
    [Constructible]
    public EnslavedGrayGoblin() : base(334, 321, 64, 147, 179)
    {
        SetResistance(ResistanceType.Physical, 50);
        SetResistance(ResistanceType.Fire, 38);
        SetResistance(ResistanceType.Cold, 32);
        SetResistance(ResistanceType.Poison, 12);
        SetResistance(ResistanceType.Energy, 11);
        SetSkill(SkillName.MagicResist, 121.6);
        SetSkill(SkillName.Tactics, 90.0);
        SetSkill(SkillName.Anatomy, 82.0);
        SetSkill(SkillName.Wrestling, 99.2);
    }

    public override string DefaultName => "Enslaved Gray Goblin";
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGreenGoblin : EnslavedGoblin
{
    [Constructible]
    public EnslavedGreenGoblin() : base(334, 326, 71, 126, 184)
    {
        SetResistance(ResistanceType.Physical, 40);
        SetResistance(ResistanceType.Fire, 38, 39);
        SetResistance(ResistanceType.Cold, 31, 32);
        SetResistance(ResistanceType.Poison, 12);
        SetResistance(ResistanceType.Energy, 10, 11);
        SetSkill(SkillName.MagicResist, 121.6, 122.9);
        SetSkill(SkillName.Tactics, 80.0, 81.2);
        SetSkill(SkillName.Anatomy, 82.0, 83.4);
        SetSkill(SkillName.Wrestling, 99.2, 99.4);
    }

    public override string DefaultName => "Enslaved Green Goblin";
}

[SerializationGenerator(0)]
public sealed partial class EnslavedGreenGoblinAlchemist : EnslavedGoblin
{
    [Constructible]
    public EnslavedGreenGoblinAlchemist() : base(723, 289, 72, 113, 196)
    {
        SetResistance(ResistanceType.Physical, 45, 49);
        SetResistance(ResistanceType.Fire, 50, 53);
        SetResistance(ResistanceType.Cold, 25, 30);
        SetResistance(ResistanceType.Poison, 40, 42);
        SetResistance(ResistanceType.Energy, 15, 18);
        SetSkill(SkillName.MagicResist, 124.1, 126.2);
        SetSkill(SkillName.Tactics, 75.3, 83.6);
        SetSkill(SkillName.Anatomy, 0.0);
        SetSkill(SkillName.Wrestling, 90.4, 94.7);
    }

    public override string DefaultName => "Green Goblin Alchemist";
}
