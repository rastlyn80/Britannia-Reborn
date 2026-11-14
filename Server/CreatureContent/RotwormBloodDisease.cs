// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using System.Collections.Generic;
using Server.Engines.BuffIcons;

namespace Server.Mobiles;

internal sealed class RotwormBloodDisease : MonsterAbilitySingleTarget
{
    private static readonly HashSet<Mobile> _infected = [];

    public override MonsterAbilityTrigger AbilityTrigger =>
        MonsterAbilityTrigger.GiveMeleeDamage | MonsterAbilityTrigger.TakeMeleeDamage;

    public override double ChanceToTrigger => 0.25;

    protected override bool CanEffectTarget(MonsterAbilityTrigger trigger, BaseCreature source, Mobile target) =>
        target != null && source.InRange(target, 1) && base.CanEffectTarget(trigger, source, target);

    protected override void OnTarget(MonsterAbilityTrigger trigger, BaseCreature source, Mobile defender)
    {
        if (!_infected.Add(defender))
        {
            return;
        }

        defender.SendLocalizedMessage(1111672, "", 0x25);
        defender.PlaySound(0x213);
        defender.FixedParticles(0x373A, 1, 15, 0x26B9, EffectLayer.Head);
        if (defender is PlayerMobile player)
        {
            player.AddBuff(new BuffInfo(BuffIcon.RotwormBloodDisease, 1153798, 1153798, TimeSpan.FromSeconds(18)));
        }

        var pulses = 0;
        TimerExecutionToken timer = default;
        Timer.StartTimer(TimeSpan.FromSeconds(4), TimeSpan.FromSeconds(2), () =>
        {
            if (defender.Deleted || !defender.Alive || defender is BaseCreature { IsDeadBondedPet: true } || pulses == 7)
            {
                timer.Cancel();
                _infected.Remove(defender);
                if (!defender.Deleted)
                {
                    defender.SendLocalizedMessage(1111673);
                    (defender as PlayerMobile)?.RemoveBuff(BuffIcon.RotwormBloodDisease);
                }
                return;
            }

            pulses++;
            AOS.Damage(defender, source.Deleted ? null : source, Utility.RandomMinMax(10, 20), 0, 0, 0, 100, 0);
            defender.Combatant = null;
        }, out timer);
    }
}
