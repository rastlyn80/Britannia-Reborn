// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class MaddeningHorror : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [new MaddeningManaDrain()];

    [Constructible]
    public MaddeningHorror() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 721;
        SetStr(270, 290);
        SetDex(80, 100);
        SetInt(850);
        SetHits(660);
        SetDamage(15, 27);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Cold, 40);
        SetDamageType(ResistanceType.Energy, 40);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 50, 60);
        SetResistance(ResistanceType.Poison, 40, 50);
        SetResistance(ResistanceType.Energy, 50, 60);
        SetSkill(SkillName.EvalInt, 120, 130);
        SetSkill(SkillName.Magery, 120, 130);
        SetSkill(SkillName.Meditation, 100, 110);
        SetSkill(SkillName.MagicResist, 180, 195);
        SetSkill(SkillName.Tactics, 95, 100);
        SetSkill(SkillName.Wrestling, 80, 85);
        SetSkill(SkillName.Poisoning, 110);
        SetSkill(SkillName.DetectHidden, 100);
        SetSkill(SkillName.Necromancy, 120);
        SetSkill(SkillName.SpiritSpeak, 120);
        Fame = 23000;
        Karma = -23000;
    }

    public override string DefaultName => "a maddening horror";
    public override string CorpseName => "a maddening horror corpse";
    public override int GetAngerSound() => 1550;
    public override int GetDeathSound() => 1551;
    public override int GetHurtSound() => 1552;
    public override int GetIdleSound() => 1553;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (Utility.RandomDouble() < 0.20)
        {
            corpse.DropItem(new VileTentacles());
        }
    }
}

internal sealed class MaddeningManaDrain : MonsterAbility
{
    public override MonsterAbilityTrigger AbilityTrigger => MonsterAbilityTrigger.TakeMeleeDamage | MonsterAbilityTrigger.GiveMeleeDamage;
    public override double ChanceToTrigger => 0.10;
    public override TimeSpan MinTriggerCooldown => TimeSpan.FromSeconds(30);
    public override TimeSpan MaxTriggerCooldown => MinTriggerCooldown;

    public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile opponent)
    {
        if (!source.Alive || source.Map is not { } map || map == Map.Internal)
        {
            return;
        }

        base.Trigger(trigger, source, opponent);
        source.Animate(12, 8, 1, true, false, 0);
        foreach (var target in map.GetMobilesInRange<Mobile>(source.Location, 8))
        {
            if (target == source || !target.Alive || target.IsDeadBondedPet ||
                target is PlayerMobile { NetState: null } || !source.CanBeHarmful(target, false) ||
                !source.CanSee(target) || !source.InLOS(target) ||
                !(target.Player || target == opponent || target is BaseCreature { Controlled: true } or BaseCreature { Summoned: true }))
            {
                continue;
            }

            var drain = Math.Min(target.Mana, Utility.RandomMinMax(40, 60));
            source.DoHarmful(target);
            target.FixedParticles(0x374A, 10, 15, 5013, 0x496, 0, EffectLayer.Waist);
            target.PlaySound(0x231);
            target.SendMessage("You feel your mana drain away.");
            target.Mana -= drain;
            source.Mana += drain;
        }
    }
}
