// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Spells;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class FireAnt : BaseCreature
{
    [SerializableField(0)]
    private DateTime _nextGoo;

    [Constructible]
    public FireAnt() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 738;
        SetStr(225);
        SetDex(108);
        SetInt(25);
        SetHits(299);
        SetDamage(15, 18);
        SetDamageType(ResistanceType.Physical, 40);
        SetDamageType(ResistanceType.Fire, 60);
        SetResistance(ResistanceType.Physical, 52);
        SetResistance(ResistanceType.Fire, 96);
        SetResistance(ResistanceType.Cold, 36);
        SetResistance(ResistanceType.Poison, 40);
        SetResistance(ResistanceType.Energy, 36);
        SetSkill(SkillName.Anatomy, 8.7);
        SetSkill(SkillName.MagicResist, 53.1);
        SetSkill(SkillName.Tactics, 77.2);
        SetSkill(SkillName.Wrestling, 75.4);
    }

    public override string DefaultName => "a fire ant";
    public override string CorpseName => "a fire ant corpse";
    public override int TreasureMapLevel => 3;
    public override int GetIdleSound() => 846;
    public override int GetAngerSound() => 849;
    public override int GetHurtSound() => 852;
    public override int GetDeathSound() => 850;
    public override void GenerateLoot() => AddLoot(LootPack.Average, 2);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (Utility.RandomDouble() < 0.25)
        {
            corpse.DropItem(new SearedFireAntGoo());
        }
    }

    public override void OnActionCombat()
    {
        base.OnActionCombat();
        if (_nextGoo > Core.Now || BardPacified || Combatant is not Mobile target ||
            !CanHitWithGoo(target) || !InRange(target, 3))
        {
            return;
        }

        _nextGoo = Core.Now + TimeSpan.FromSeconds(30);
        this.MarkDirty();
        Mana = Math.Max(0, Mana - 30);
        FixedParticles(0x3709, 10, 15, 2724, 0, 9907, EffectLayer.LeftFoot);
        PlaySound(0x348);
        Timer.DelayCall(TimeSpan.FromSeconds(1), ApplyGoo);
    }

    private bool CanHitWithGoo(Mobile target) =>
        target != this && target.Alive && !target.Deleted && !target.IsDeadBondedPet &&
        target.Map == Map && CanBeHarmful(target, false) && InLOS(target) &&
        (target == Combatant || (!Controlled && !Summoned && target.Player && CanSee(target)) ||
         SpellHelper.ValidIndirectTarget(this, target));

    private void ApplyGoo()
    {
        if (Deleted || !Alive || Map == null || Map == Map.Internal)
        {
            return;
        }

        foreach (var target in GetMobilesInRange<Mobile>(5))
        {
            if (CanHitWithGoo(target))
            {
                Timer.DelayCall(TimeSpan.FromMilliseconds(Utility.RandomMinMax(10, 1000)), () => IgniteGoo(target));
            }
        }
    }

    private void IgniteGoo(Mobile target)
    {
        if (Deleted || !Alive || !CanHitWithGoo(target))
        {
            return;
        }

        for (var x = -1; x <= 1; x++)
        {
            for (var y = -1; y <= 1; y++)
            {
                Effects.SendLocationEffect(new Point3D(target.X + x, target.Y + y, target.Z), Map, 0x3728, 13, 1921, 3);
            }
        }

        DoHarmful(target);
        AOS.Damage(target, this, Utility.RandomMinMax(30, 40), 0, 100, 0, 0, 0);
        target.SendLocalizedMessage(1112366);
    }
}
