// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class SlasherOfVeils : BaseCreature
{
    private const int FearRange = 8;
    private static readonly SlasherFear _fear = new();
    private static readonly MonsterAbility[] _abilities = [new SlasherAngryFire(), new MaddeningManaDrain()];

    [Constructible]
    public SlasherOfVeils() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 741;
        SetStr(901, 1010);
        SetDex(127, 153);
        SetInt(1078, 1263);
        SetHits(50000, 65000);
        SetMana(10000);
        SetDamage(10, 15);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Fire, 20);
        SetDamageType(ResistanceType.Cold, 20);
        SetDamageType(ResistanceType.Poison, 20);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 65, 80);
        SetResistance(ResistanceType.Fire, 70, 80);
        SetResistance(ResistanceType.Cold, 70, 80);
        SetResistance(ResistanceType.Poison, 70, 80);
        SetResistance(ResistanceType.Energy, 70, 80);
        SetSkill(SkillName.Anatomy, 110.8, 129.7);
        SetSkill(SkillName.EvalInt, 113.4, 130);
        SetSkill(SkillName.Magery, 111.7, 130);
        SetSkill(SkillName.Spellweaving, 111.1, 125);
        SetSkill(SkillName.Meditation, 113.5, 129.9);
        SetSkill(SkillName.MagicResist, 110, 129.8);
        SetSkill(SkillName.Tactics, 110.5, 126.3);
        SetSkill(SkillName.Wrestling, 110.1, 130);
        SetSkill(SkillName.DetectHidden, 127.1);
        Fame = 35000;
        Karma = -35000;
    }

    public override string DefaultName => "The Slasher of Veils";
    public override string CorpseName => "a slasher of veils corpse";
    public override bool AlwaysMurderer => true;
    public override int GetAngerSound() => 1586;
    public override int GetDeathSound() => 1587;
    public override int GetHurtSound() => 1588;
    public override int GetIdleSound() => 1589;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.ParalyzingBlow;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void GenerateLoot()
    {
        AddLoot(LootPack.AosSuperBoss, 4);
        AddLoot(LootPack.Gems, 8);
    }

    public override void OnMovement(Mobile target, Point3D previous)
    {
        base.OnMovement(target, previous);
        if (target is PlayerMobile { NetState: not null, AccessLevel: AccessLevel.Player, Alive: true, Frozen: false } &&
            target.Map == Map && !Utility.InRange(previous, Location, FearRange) && InRange(target, FearRange) &&
            CanBeHarmful(target, false) && CanSee(target) && InLOS(target) && !BardPacified &&
            _fear.CanTrigger(this, MonsterAbilityTrigger.Movement))
        {
            _fear.Trigger(MonsterAbilityTrigger.Movement, this, target);
        }
    }

    public override void OnDamagedBySpell(Mobile caster, int damage)
    {
        base.OnDamagedBySpell(caster, damage);
        if (Alive && caster != this && caster.Alive && Map is { } map && map != Map.Internal &&
            caster.Map == map && InRange(caster, 10) && CanBeHarmful(caster, false) &&
            Utility.RandomBool() && map.CanFit(caster.Location, 16, checkMobiles: false))
        {
            MoveToWorld(caster.Location, map);
            Combatant = caster;
            PlaySound(0x1FE);
        }
    }
}

internal sealed class SlasherFear : MonsterAbility
{
    public override MonsterAbilityTrigger AbilityTrigger => MonsterAbilityTrigger.Movement;
    public override double ChanceToTrigger => .10;
    public override TimeSpan MinTriggerCooldown => TimeSpan.FromMinutes(1);
    public override TimeSpan MaxTriggerCooldown => TimeSpan.FromMinutes(3);

    public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile target)
    {
        if (target is not PlayerMobile player || !player.Alive || player.Frozen)
        {
            return;
        }

        base.Trigger(trigger, source, player);
        source.Direction = source.GetDirectionTo(player);
        source.Animate(12, 8, 1, true, false, 0);
        var seconds = Math.Max(1, (int)(13 - player.Skills[SkillName.MagicResist].Value / 10));
        var message = seconds switch
        {
            <= 2 => 1080339,
            <= 4 => 1080340,
            <= 7 => 1080341,
            <= 10 => 1080342,
            _ => 1080343
        };
        var duration = TimeSpan.FromSeconds(seconds);
        player.SendLocalizedMessage(message, source.Name, 0x21);
        player.Frozen = true;
        player.AddBuff(new BuffInfo(BuffIcon.TrueFear, 1153791, 1153827, duration));
        Timer.StartTimer(duration, () =>
        {
            if (!player.Deleted)
            {
                player.Frozen = false;
                player.RemoveBuff(BuffIcon.TrueFear);
                player.SendLocalizedMessage(1005603);
            }
        });
    }
}

internal sealed class SlasherAngryFire : MonsterAbilitySingleTarget
{
    public override MonsterAbilityTrigger AbilityTrigger => MonsterAbilityTrigger.GiveMeleeDamage;
    public override double ChanceToTrigger => .10;
    public override TimeSpan MinTriggerCooldown => TimeSpan.FromSeconds(30);
    public override TimeSpan MaxTriggerCooldown => MinTriggerCooldown;

    public override bool CanTrigger(BaseCreature source, MonsterAbilityTrigger trigger) =>
        source.Mana >= 30 && base.CanTrigger(source, trigger);

    protected override void OnTarget(MonsterAbilityTrigger trigger, BaseCreature source, Mobile target)
    {
        source.Mana -= 30;
        source.Animate(27, 8, 1, true, false, 0);
        AOS.Damage(target, source, Utility.RandomMinMax(30, 40), 60, 20, 0, 0, 20);
        target.FixedParticles(0x3709, 10, 30, 5052, EffectLayer.LeftFoot);
        target.PlaySound(0x208);
        target.SendLocalizedMessage(1070823);
    }
}
