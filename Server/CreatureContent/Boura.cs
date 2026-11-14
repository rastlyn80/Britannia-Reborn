// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Network;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class Boura : BaseCreature, ICarvable
{
    private static readonly MonsterAbility[] _abilities = [MonsterAbilities.ColossalBlow];

    [SerializableField(0)]
    private bool _furGathered;

    protected Boura(int controlSlots, double tamingSkill, int karma) : base(AIType.AI_Animal, FightMode.Aggressor, 10, 1)
    {
        Body = 715;
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 50, 60);
        SetResistance(ResistanceType.Fire, 35, 40);
        SetResistance(ResistanceType.Cold, 10, 20);
        SetResistance(ResistanceType.Poison, 30, 40);
        SetResistance(ResistanceType.Energy, 30, 40);
        Tamable = true;
        ControlSlots = controlSlots;
        MinTameSkill = tamingSkill;
        Fame = 5000;
        Karma = karma;
        VirtualArmor = 16;
    }

    protected abstract int FurHue { get; }
    public override string CorpseName => "a boura corpse";
    public override int Meat => 10;
    public override int Hides => 20;
    public override HideType HideType => HideType.Horned;
    public override FoodType FavoriteFood => FoodType.FruitsAndVeggies;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
    public override int GetIdleSound() => 1507;
    public override int GetAngerSound() => 1504;
    public override int GetHurtSound() => 1506;
    public override int GetDeathSound() => 1505;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public void Carve(Mobile from, Item with)
    {
        if (!Alive || Summoned || Deleted)
        {
            return;
        }

        if (_furGathered)
        {
            PrivateOverheadMessage(MessageType.Regular, 0x3B2, 1112354, from.NetState);
            return;
        }

        var fur = new BouraFur(FurHue, 30);
        if (from.Backpack?.TryDropItem(from, fur, false) != true)
        {
            fur.Delete();
            from.SendLocalizedMessage(1112352);
            return;
        }

        FurGathered = true;
        from.SendLocalizedMessage(1112353);
    }

    public override void OnCarve(Mobile from, Corpse corpse, Item with)
    {
        var wasCarved = corpse.Carved;
        base.OnCarve(from, corpse, with);
        if (!wasCarved && corpse.Carved)
        {
            corpse.AddCarvedItem(new DragonsBlood(8), from);
        }
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (!Controlled && !Summoned && corpse is { Deleted: false })
        {
            corpse.DropItem(new BouraSkin());
        }
    }
}

[SerializationGenerator(0)]
public partial class RuddyBoura : Boura
{
    [Constructible]
    public RuddyBoura() : base(2, 19.1, -2500)
    {
        SetStr(396, 480);
        SetDex(68, 82);
        SetInt(16, 20);
        SetHits(435, 509);
        SetStam(68, 82);
        SetMana(16, 20);
        SetDamage(16, 20);
        SetSkill(SkillName.Anatomy, 86.6, 88.8);
        SetSkill(SkillName.MagicResist, 69.7, 87.7);
        SetSkill(SkillName.Tactics, 83.3, 88.8);
        SetSkill(SkillName.Wrestling, 86.6, 87.9);
    }

    public override string DefaultName => "a ruddy boura";
    public override HideType HideType => HideType.Spined;
    protected override int FurHue => 1541;
}

[SerializationGenerator(0)]
public partial class HighPlainsBoura : Boura
{
    private static readonly MonsterAbility[] _abilities = [MonsterAbilities.TailSwipe, MonsterAbilities.ColossalBlow];

    [Constructible]
    public HighPlainsBoura() : base(3, 47.1, -5000)
    {
        SetStr(400, 435);
        SetDex(90, 96);
        SetInt(25, 30);
        SetHits(555, 618);
        SetDamage(20, 25);
        SetSkill(SkillName.Anatomy, 95.2, 105.4);
        SetSkill(SkillName.MagicResist, 60.7, 70.0);
        SetSkill(SkillName.Tactics, 95.4, 105.7);
        SetSkill(SkillName.Wrestling, 105.1, 115.3);
    }

    public override string DefaultName => "a high plains boura";
    public override int Hides => 22;
    protected override int FurHue => 153;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
}

[SerializationGenerator(0)]
public partial class LowlandBoura : Boura
{
    [Constructible]
    public LowlandBoura() : base(3, 19.1, -3500)
    {
        SetStr(337, 411);
        SetDex(82, 93);
        SetInt(23, 25);
        SetHits(438, 553);
        SetDamage(18, 23);
        SetSkill(SkillName.Anatomy, 81.2, 84.4);
        SetSkill(SkillName.MagicResist, 70.7, 75.0);
        SetSkill(SkillName.Tactics, 83.4, 86.7);
        SetSkill(SkillName.Wrestling, 95.1, 97.3);
    }

    public override string DefaultName => "a lowland boura";
    protected override int FurHue => 58;
}
