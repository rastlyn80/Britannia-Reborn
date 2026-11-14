// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Items;
using Server.Network;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class BloodWorm : BaseCreature
{
    private static readonly TimeSpan AnemiaDuration = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan AnemiaTick = TimeSpan.FromSeconds(2);
    private long _nextDrain;

    [Constructible]
    public BloodWorm() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 287;
        SetStr(401, 473);
        SetDex(80);
        SetInt(18, 19);
        SetHits(374, 422);
        SetDamage(11, 17);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Poison, 40);
        SetResistance(ResistanceType.Physical, 52, 55);
        SetResistance(ResistanceType.Fire, 42, 50);
        SetResistance(ResistanceType.Cold, 29, 31);
        SetResistance(ResistanceType.Poison, 69, 75);
        SetResistance(ResistanceType.Energy, 26, 27);
        SetSkill(SkillName.MagicResist, 35.0);
        SetSkill(SkillName.Tactics, 100.0);
        SetSkill(SkillName.Wrestling, 100.0);
    }

    public override string DefaultName => "a bloodworm";
    public override string CorpseName => "a bloodworm corpse";
    public override int GetIdleSound() => 1503;
    public override int GetAngerSound() => 1500;
    public override int GetHurtSound() => 1502;
    public override int GetDeathSound() => 1501;

    public override void GenerateLoot()
    {
        AddLoot(LootPack.Rich);
        AddLoot(LootPack.Average);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnGaveMeleeAttack(Mobile defender, int damage)
    {
        base.OnGaveMeleeAttack(defender, damage);
        TryDrain(defender, damage);
    }

    public override void OnGotMeleeAttack(Mobile attacker, int damage)
    {
        base.OnGotMeleeAttack(attacker, damage);
        TryDrain(attacker, damage);
    }

    public override bool Move(Direction direction)
    {
        if (!base.Move(direction))
        {
            return false;
        }
        if (Alive && Hits < HitsMax && Utility.RandomDouble() < 0.25)
        {
            foreach (var item in Map.GetItemsInRange(Location, 1))
            {
                if (item is Corpse { ItemID: 0x2006 } corpse && Math.Abs(corpse.Z - Z) <= 4 && InLOS(corpse))
                {
                    corpse.Direction = Direction.North;
                    corpse.TurnToBones();
                    Hits = HitsMax;
                    PublicOverheadMessage(MessageType.Regular, 0x3B2, 1111699);
                    break;
                }
            }
        }
        return true;
    }

    private void TryDrain(Mobile target, int damage)
    {
        var now = Core.TickCount;
        if (damage <= 0 || !Alive || !target.Alive || target.IsDeadBondedPet || target.Map != Map ||
            target.AccessLevel > AccessLevel.Player || !InRange(target, 1) || !CanBeHarmful(target, false) ||
            now < _nextDrain || Utility.RandomDouble() >= 0.10)
        {
            return;
        }
        _nextDrain = now + 30000;
        if (!target.CanBeginAction(typeof(BloodWorm)))
        {
            target.PublicOverheadMessage(MessageType.Regular, 0x25, 1111668);
            return;
        }
        target.PublicOverheadMessage(MessageType.Regular, 0x25, 1111698);
        Hits = Math.Min(HitsMax, Hits + Utility.RandomMinMax(50, 70));
        if (Utility.RandomDouble() < 0.25 && target.BeginAction(typeof(BloodWorm)))
        {
            Infect(target);
        }
    }

    private static void Infect(Mobile target)
    {
        target.SendLocalizedMessage(1111669);
        target.FixedParticles(0x373A, 1, 15, 0x26B9, EffectLayer.Head);
        target.PlaySound(0x1ED);
        var strength = target.RawStr / 3;
        var dexterity = target.RawDex / 3;
        var intelligence = target.RawInt / 3;
        target.AddStatMod(new StatMod(StatType.Str, "BloodWorm_Str", -strength, AnemiaDuration));
        target.AddStatMod(new StatMod(StatType.Dex, "BloodWorm_Dex", -dexterity, AnemiaDuration));
        target.AddStatMod(new StatMod(StatType.Int, "BloodWorm_Int", -intelligence, AnemiaDuration));
        if (target is PlayerMobile player)
        {
            player.AddBuff(new BuffInfo(BuffIcon.BloodwormAnemia, 1153797, 1153824, AnemiaDuration,
                $"{strength}\t{intelligence}\t{dexterity}"));
        }
        new AnemiaTimer(target).Start();
    }

    private sealed class AnemiaTimer(Mobile target) : Timer(AnemiaTick, AnemiaTick)
    {
        private readonly DateTime _expires = Core.Now + AnemiaDuration;

        protected override void OnTick()
        {
            if (!target.Deleted && target.Alive && !target.IsDeadBondedPet && Core.Now < _expires)
            {
                if (target.Stam >= 2)
                {
                    target.Stam -= Utility.RandomMinMax(2, 5);
                }
                return;
            }
            Stop();
            target.EndAction(typeof(BloodWorm));
            target.RemoveStatMod("BloodWorm_Str");
            target.RemoveStatMod("BloodWorm_Dex");
            target.RemoveStatMod("BloodWorm_Int");
            if (target is PlayerMobile affected)
            {
                affected.RemoveBuff(BuffIcon.BloodwormAnemia);
            }
            if (!target.Deleted)
            {
                target.SendLocalizedMessage(1111670);
            }
        }
    }
}
