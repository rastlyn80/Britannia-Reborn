// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class Kepetch : BaseCreature, ICarvable
{
    [SerializableField(0)]
    private bool _gatheredFur;

    [Constructible]
    public Kepetch() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 726;
        SetStr(337, 380);
        SetDex(184, 194);
        SetInt(30, 50);
        SetHits(300, 400);
        SetDamage(7, 17);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 55, 75);
        SetResistance(ResistanceType.Fire, 40, 60);
        SetResistance(ResistanceType.Cold, 40, 50);
        SetResistance(ResistanceType.Poison, 50, 70);
        SetResistance(ResistanceType.Energy, 60, 70);
        SetSkill(SkillName.Anatomy, 119.7, 124.1);
        SetSkill(SkillName.MagicResist, 89.9, 97.4);
        SetSkill(SkillName.Tactics, 117.4, 123.5);
        SetSkill(SkillName.Wrestling, 107.7, 113.9);
        SetSkill(SkillName.DetectHidden, 25.0);
        SetSkill(SkillName.Parry, 60.0, 70.0);
        Fame = 6000;
        Karma = -6000;
    }

    public override string DefaultName => "a kepetch";
    public override string CorpseName => "a kepetch corpse";
    public override int Meat => 5;
    public override int Hides => 14;
    public override HideType HideType => HideType.Spined;
    public override FoodType FavoriteFood => FoodType.FruitsAndVeggies | FoodType.GrainsAndHay;
    public override int GetIdleSound() => 1545;
    public override int GetAngerSound() => 1542;
    public override int GetHurtSound() => 1544;
    public override int GetDeathSound() => 1543;
    public override void GenerateLoot() => AddLoot(LootPack.Average, 2);

    public void Carve(Mobile from, Item item) => KepetchFur.Gather(from, ref _gatheredFur, this);

    public override void OnGaveMeleeAttack(Mobile defender, int damage)
    {
        base.OnGaveMeleeAttack(defender, damage);
        if (damage <= 0 || !defender.Alive || Utility.RandomDouble() >= 0.10 || !defender.BeginAction<Kepetch>())
        {
            return;
        }

        Mana = Math.Max(0, Mana - 20);
        defender.SendMessage("The creature gives you a vicious bite.");
        defender.PlaySound(0x1324);
        Effects.SendLocationParticles(
            EffectItem.Create(defender.Location, defender.Map, EffectItem.DefaultDuration), 0x37CC, 1, 40, 97, 3, 9917, 0
        );
        Timer.DelayCall(TimeSpan.FromSeconds(20), () => Fester(defender, 1));
    }

    private void Fester(Mobile defender, int tick)
    {
        if (!defender.Deleted && defender.Alive && !defender.IsDeadBondedPet)
        {
            AOS.Damage(defender, this, tick * 5, true, 0, 0, 0, 0, 0, direct: 100);
            defender.SendLocalizedMessage(1112473);
            if (tick < 20 && defender.Alive)
            {
                Timer.DelayCall(TimeSpan.FromSeconds(20), () => Fester(defender, tick + 1));
                return;
            }
        }

        defender.EndAction<Kepetch>();
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
