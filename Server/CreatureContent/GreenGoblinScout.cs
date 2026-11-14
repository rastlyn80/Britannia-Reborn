// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Spells;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class GreenGoblinScout : AbyssGoblin
{
    [Constructible]
    public GreenGoblinScout() : base(AIType.AI_Melee, 0, clanSupplies: false)
    {
        SetStr(276, 309);
        SetDex(65, 79);
        SetInt(107, 146);
        SetHits(174, 198);
        SetStam(65, 79);
        SetMana(107, 146);
        SetResistance(ResistanceType.Physical, 41, 49);
        SetResistance(ResistanceType.Fire, 33, 39);
        SetResistance(ResistanceType.Cold, 26, 33);
        SetResistance(ResistanceType.Poison, 14, 20);
        SetResistance(ResistanceType.Energy, 11, 20);
        SetSkill(SkillName.MagicResist, 90.7, 98.8);
        SetSkill(SkillName.Tactics, 80.9, 86.3);
        SetSkill(SkillName.Wrestling, 107.7, 119.5);
        SetSkill(SkillName.Anatomy, 80.3, 88.2);
        SetSkill(SkillName.DetectHidden, 80.0);
        SetSkill(SkillName.Hiding, 100.0);
        SetSkill(SkillName.Stealth, 80.0);
        VirtualArmor = 0;
    }

    public override string DefaultName => "a green goblin scout";
    protected override double LuckyCoinChance => 0.01;
    protected override BaseAI ForcedAI => new GoblinScoutAI(this);

    public override void OnThink()
    {
        base.OnThink();
        if (!Alive || Map == null || Core.TickCount - NextSkillTime < 0 || Utility.RandomDouble() >= 0.20)
        {
            return;
        }

        foreach (var mobile in Map.GetMobilesInRange<PlayerMobile>(Location, RangePerception))
        {
            if (mobile is { Alive: true, Hidden: true, AccessLevel: AccessLevel.Player } &&
                InLOS(mobile) && UseSkill(SkillName.DetectHidden))
            {
                Target?.Invoke(this, this);
                PlaySound(0x340);
                break;
            }
        }
    }

    private sealed class GoblinScoutAI(GreenGoblinScout scout) : MeleeAI(scout)
    {
        public override bool DoActionWander()
        {
            TryHide();
            return base.DoActionWander();
        }

        public override bool DoActionFlee()
        {
            TryHide();
            return base.DoActionFlee();
        }

        public override bool DoActionCombat()
        {
            if (Utility.RandomDouble() < 0.04)
            {
                TryRetreat();
            }
            return base.DoActionCombat();
        }

        private void TryHide()
        {
            var chance = scout.Poisoned ? 0.01 : scout.Hits < 20 ? 0.10 : 0.05;
            if (scout.Hidden || !scout.Alive || Core.TickCount - scout.NextSkillTime < 0 ||
                Utility.RandomDouble() >= chance)
            {
                return;
            }

            scout.FixedParticles(0x3728, 10, 10, 2023, EffectLayer.Waist);
            scout.PlaySound(0x22F);
            scout.Hidden = true;
            scout.UseSkill(SkillName.Stealth);
        }

        private void TryRetreat()
        {
            if (scout.Combatant is not PlayerMobile { Alive: true, Hidden: false } threat ||
                threat.Combatant != scout || !scout.InRange(threat, scout.RangePerception))
            {
                return;
            }

            var dx = scout.X - threat.X;
            var dy = scout.Y - threat.Y;
            var distance = Math.Sqrt(dx * dx + dy * dy);
            var length = Utility.RandomMinMax(4, 6);
            var x = scout.X + (distance == 0 ? length : (int)(length * dx / distance));
            var y = scout.Y + (distance == 0 ? 0 : (int)(length * dy / distance));
            var map = scout.Map;
            for (var oy = -1; oy <= 1; oy++)
            {
                for (var ox = -1; ox <= 1; ox++)
                {
                    var tile = new Point3D(x + ox, y + oy, map.GetAverageZ(x + ox, y + oy));
                    if (Math.Abs(tile.Z - scout.Z) > 4 || !map.CanSpawnMobile(tile) ||
                        !scout.InLOS(tile) || SpellHelper.CheckMulti(tile, map))
                    {
                        continue;
                    }
                    scout.FixedParticles(0x376A, 9, 32, 0x13AF, EffectLayer.Waist);
                    scout.PlaySound(0x1FE);
                    scout.Location = tile;
                    return;
                }
            }
        }
    }
}
