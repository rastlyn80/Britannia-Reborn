// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Misc;
using Server.Spells;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class OrcScout : BaseCreature
{
    private long _nextDetection;
    private long _nextBandage;

    [Constructible]
    public OrcScout() : base(AIType.AI_Archer, FightMode.Closest, 10, 7)
    {
        Body = 0xB5;
        BaseSoundID = 0x45A;
        SetStr(96, 120);
        SetDex(101, 130);
        SetInt(36, 60);
        SetHits(58, 72);
        SetMana(30, 60);
        SetDamage(5, 7);
        SetResistance(ResistanceType.Physical, 25, 35);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 15, 25);
        SetResistance(ResistanceType.Poison, 15, 20);
        SetResistance(ResistanceType.Energy, 25, 30);
        SetSkill(SkillName.MagicResist, 50.1, 75.0);
        SetSkill(SkillName.Tactics, 55.1, 80.0);
        SetSkill(SkillName.Fencing, 50.1, 70.0);
        SetSkill(SkillName.Archery, 80.1, 120.0);
        SetSkill(SkillName.Parry, 40.1, 60.0);
        SetSkill(SkillName.Healing, 80.1, 100.0);
        SetSkill(SkillName.Anatomy, 50.1, 90.0);
        SetSkill(SkillName.DetectHidden, 100.1, 120.0);
        SetSkill(SkillName.Hiding, 100.0, 120.0);
        SetSkill(SkillName.Stealth, 80.1, 120.0);
        Fame = 1500;
        Karma = -1500;

        PackItem(new Apple(Utility.RandomMinMax(3, 5)));
        PackItem(new Arrow(Utility.RandomMinMax(60, 70)));
        PackItem(new Bandage(Utility.RandomMinMax(1, 15)));
        AddItem(Utility.RandomDouble() < 0.1 ? new OrcishBow() : new OrcScoutBow());
    }

    public override string DefaultName => "an orc scout";
    public override string CorpseName => "an orcish corpse";
    public override bool CanRummageCorpses => true;
    public override InhumanSpeech SpeechType => InhumanSpeech.Orc;
    public override OppositionGroup OppositionGroup => OppositionGroup.SavagesAndOrcs;
    public override int Meat => 1;
    protected override BaseAI ForcedAI => new ScoutAI(this);
    public override void GenerateLoot() => AddLoot(LootPack.Rich);

    public override bool IsEnemy(Mobile mobile) =>
        (!mobile.Player || mobile.FindItemOnLayer<OrcishKinMask>(Layer.Helm) == null) && base.IsEnemy(mobile);

    public override void AggressiveAction(Mobile aggressor, bool criminal)
    {
        base.AggressiveAction(aggressor, criminal);
        if (aggressor.FindItemOnLayer<OrcishKinMask>(Layer.Helm) is { } mask)
        {
            AOS.Damage(aggressor, 50, 0, 100, 0, 0, 0);
            mask.Delete();
            aggressor.FixedParticles(0x36BD, 20, 10, 5044, EffectLayer.Head);
            aggressor.PlaySound(0x307);
        }
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnThink()
    {
        base.OnThink();
        var now = Core.TickCount;
        if (now >= _nextBandage && (Poisoned || Hits < HitsMax - 10))
        {
            _nextBandage = now + 1000;
            if (BandageContext.GetContext(this) == null && Backpack?.FindItemByType<Bandage>() is { } bandage &&
                BandageContext.BeginHeal(this, this) != null)
            {
                bandage.Consume();
            }
        }
        if (now < _nextDetection || now < NextSkillTime)
        {
            return;
        }
        _nextDetection = now + 1000;
        foreach (var mobile in GetMobilesInRange(RangePerception))
        {
            if (mobile is PlayerMobile { Alive: true, Hidden: true, AccessLevel: AccessLevel.Player } && InLOS(mobile) &&
                UseSkill(SkillName.DetectHidden))
            {
                Target?.Invoke(this, this);
                PlaySound(0x340);
                break;
            }
        }
    }

    private sealed class ScoutAI(OrcScout scout) : ArcherAI(scout)
    {
        public override bool DoActionCombat()
        {
            if (Utility.RandomDouble() < 0.04)
            {
                Retreat();
            }
            return base.DoActionCombat();
        }

        public override bool DoActionWander()
        {
            TryHide();
            return base.DoActionWander();
        }

        public override bool DoActionFlee()
        {
            if (scout.Hits > scout.HitsMax / 2)
            {
                Action = ActionType.Guard;
                return true;
            }
            TryHide();
            return base.DoActionFlee();
        }

        private void TryHide()
        {
            var chance = scout.Poisoned ? 0.01 : scout.Hits < 20 ? 0.10 : 0.05;
            if (!scout.Hidden && Core.TickCount >= scout.NextSkillTime && Utility.RandomDouble() < chance)
            {
                scout.FixedParticles(0x3728, 10, 10, 2023, EffectLayer.Waist);
                scout.PlaySound(0x22F);
                scout.Hidden = true;
                scout.UseSkill(SkillName.Stealth);
            }
        }

        private void Retreat()
        {
            if (scout.Combatant is not PlayerMobile { Alive: true, Hidden: false } target ||
                target.Combatant != scout || target.Map != scout.Map || !scout.InRange(target, scout.RangePerception))
            {
                return;
            }
            var dx = scout.X - target.X;
            var dy = scout.Y - target.Y;
            var distance = Math.Sqrt(dx * dx + dy * dy);
            var length = Utility.RandomMinMax(4, 6);
            var x = scout.X + (distance > 0 ? (int)(dx * length / distance) : length);
            var y = scout.Y + (distance > 0 ? (int)(dy * length / distance) : 0);
            var map = scout.Map;
            for (var offsetY = -1; offsetY <= 1; offsetY++)
            {
                for (var offsetX = -1; offsetX <= 1; offsetX++)
                {
                    var tileX = x + offsetX;
                    var tileY = y + offsetY;
                    var tile = new Point3D(tileX, tileY, map.GetAverageZ(tileX, tileY));
                    if (Math.Abs(tile.Z - scout.Z) > 4 || !scout.InLOS(tile) ||
                        !map.CanSpawnMobile(tile) || SpellHelper.CheckMulti(tile, map))
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
