// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class AcidSlug : Slime
{
    // BaseWeapon recognizes Slime subclasses for native melee weapon corrosion.
    [Constructible]
    public AcidSlug()
    {
        Hue = Utility.Random(242, 4);
        RangePerception = 10;
        SetStr(213, 294);
        SetDex(80, 82);
        SetInt(18, 22);
        SetHits(333, 370);
        SetDamage(21, 28);
        SetResistance(ResistanceType.Physical, 10, 15);
        SetResistance(ResistanceType.Fire, 0);
        SetResistance(ResistanceType.Cold, 10, 15);
        SetResistance(ResistanceType.Poison, 60, 70);
        SetResistance(ResistanceType.Energy, 10, 15);
        SetSkill(SkillName.Poisoning, 0);
        SetSkill(SkillName.MagicResist, 25.0);
        SetSkill(SkillName.Tactics, 30.0, 50.0);
        SetSkill(SkillName.Wrestling, 30.0, 80.0);
        Tamable = false;
        ControlSlots = 0;
        MinTameSkill = 0;
        Fame = 0;
        Karma = 0;
        VirtualArmor = 0;
    }

    public override string DefaultName => "an acid slug";
    public override string CorpseName => "an acid slug corpse";
    public override FoodType FavoriteFood => FoodType.None;
    public override Poison? HitPoison => null;
    public override Poison? PoisonImmune => null;
    public override int GetAngerSound() => 1496;
    public override int GetDeathSound() => 1497;
    public override int GetHurtSound() => 1498;
    public override int GetIdleSound() => 1499;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override bool CheckMovement(Direction direction, out int newZ) =>
        base.CheckMovement(direction, out newZ) && (newZ <= Z || !Region.IsPartOf("Underworld"));

    public override void GenerateLoot() => AddLoot(LootPack.Average);

    public override void GenerateLoot(bool spawning)
    {
        base.GenerateLoot(spawning);
        if (spawning || Summoned)
        {
            return;
        }

        PackItem(new CongealedSlugAcid());
        if (Utility.RandomDouble() < 0.75)
        {
            PackItem(new AcidSac());
        }

        // The official ingredient list specifies this drop for the Passage of Tears spawn.
        if (Region.IsPartOf("Passage of Tears") && Utility.RandomDouble() < 0.33)
        {
            PackItem(new VialOfVitriol());
        }
    }
}
