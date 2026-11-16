// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class Medusa : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [new MedusaGaze()];

    [Constructible]
    public Medusa() : base(AIType.AI_Archer, FightMode.Closest, 12, 5)
    {
        Body = 728;
        SetStr(1235, 1391);
        SetDex(128, 139);
        SetInt(537, 664);
        SetHits(60000);
        SetDamage(21, 28);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 55, 65);
        SetResistance(ResistanceType.Cold, 55, 65);
        SetResistance(ResistanceType.Poison, 80, 90);
        SetResistance(ResistanceType.Energy, 60, 75);
        SetSkill(SkillName.Anatomy, 110.6, 116.1);
        SetSkill(SkillName.Archery, 111.9, 120.0);
        SetSkill(SkillName.EvalInt, 100.0, 114.4);
        SetSkill(SkillName.Magery, 100.0);
        SetSkill(SkillName.Meditation, 118.2, 127.8);
        SetSkill(SkillName.MagicResist, 120.0);
        SetSkill(SkillName.Tactics, 111.9, 134.5);
        SetSkill(SkillName.Wrestling, 119.7, 128.9);
        Fame = 22000;
        Karma = -22000;
        VirtualArmor = 60;
        AddItem(new CompositeBow { Movable = false, Layer = Layer.TwoHanded });
        PackItem(new Arrow(Utility.RandomMinMax(100, 200)));
    }

    public override string DefaultName => "Medusa";
    public override string CorpseName => "a medusa corpse";
    public override bool AutoDispel => true;
    public override double AutoDispelChance => 1.0;
    public override bool BardImmune => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override Poison HitPoison => Utility.RandomDouble() < .8 ? Poison.Deadly : Poison.Lethal;
    public override int GetAngerSound() => 1554;
    public override int GetDeathSound() => 1555;
    public override int GetHurtSound() => 1556;
    public override int GetIdleSound() => 1557;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.MortalStrike;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.1;
        passiveSpeed = 0.2;
    }
}

internal sealed class MedusaGaze : MonsterAbility
{
    private const int StoneHue = 761;
    public override MonsterAbilityTrigger AbilityTrigger => MonsterAbilityTrigger.CombatAction;
    public override TimeSpan MinTriggerCooldown => TimeSpan.FromSeconds(45);
    public override TimeSpan MaxTriggerCooldown => TimeSpan.FromSeconds(75);

    public override bool CanTrigger(BaseCreature source, MonsterAbilityTrigger trigger) =>
        !source.BardPacified && !source.Summoned && base.CanTrigger(source, trigger);

    public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile opponent)
    {
        if (!source.Alive || source.Map is not { } map || map == Map.Internal)
        {
            return;
        }

        Mobile? target = null;
        var eligible = 0;
        foreach (var candidate in map.GetMobilesInRange<Mobile>(source.Location, 12))
        {
            if (candidate == source || !candidate.Alive || candidate.Frozen || candidate.Blessed ||
                candidate.IsDeadBondedPet || candidate.AccessLevel > AccessLevel.Player ||
                !(candidate is PlayerMobile { NetState: not null } ||
                  candidate is BaseCreature pet && pet.GetMaster() is PlayerMobile { NetState: not null }) ||
                !source.CanBeHarmful(candidate, false) || !source.CanSee(candidate) || !source.InLOS(candidate))
            {
                continue;
            }
            if (Utility.Random(++eligible) == 0)
            {
                target = candidate;
            }
        }
        if (target == null)
        {
            return;
        }

        base.Trigger(trigger, source, target);
        source.DoHarmful(target);
        source.Direction = source.GetDirectionTo(target);
        source.Animate(12, 9, 1, true, false, 0);
        var previousHue = target.SolidHueOverride;
        target.Frozen = true;
        target.Blessed = true;
        target.SolidHueOverride = StoneHue;
        var duration = TimeSpan.FromSeconds(Utility.RandomMinMax(5, 10));
        target.SendLocalizedMessage(1112768);
        var player = target as PlayerMobile;
        player?.AddBuff(new BuffInfo(BuffIcon.MedusaStone, 1153790, 1153825, duration));
        Timer.StartTimer(duration, () =>
        {
            if (target.Deleted)
            {
                return;
            }
            target.Frozen = false;
            target.Blessed = false;
            if (target.SolidHueOverride == StoneHue)
            {
                target.SolidHueOverride = previousHue;
            }
            player?.RemoveBuff(BuffIcon.MedusaStone);
        });
    }
}
