// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class AbyssAmbusher : BaseCreature
{
    private long _nextHideRoll;

    protected AbyssAmbusher() : base(AIType.AI_Melee, FightMode.Closest, 10, 1) => Hidden = true;

    protected override BaseAI ForcedAI => new AmbushAI(this);

    public override void OnThink()
    {
        base.OnThink();
        var now = Core.TickCount;
        if (Hidden || Combatant is not { Alive: true } target || !InRange(target, RangePerception) ||
            BardPacified || now < _nextHideRoll || now < NextSkillTime)
        {
            return;
        }

        _nextHideRoll = now + 1000;
        var chance = Poisoned ? 0.01 : Hits < 20 ? 0.10 : 0.05;
        if (Utility.RandomDouble() < chance)
        {
            FixedParticles(0x3728, 10, 10, 2023, EffectLayer.Waist);
            PlaySound(0x22F);
            Combatant = null;
            Warmode = false;
            Hidden = true;
        }
    }

    public override void OnDamage(int amount, Mobile from, bool willKill)
    {
        RevealingAction();
        base.OnDamage(amount, from, willKill);
    }

    public override void OnDamagedBySpell(Mobile from, int damage)
    {
        RevealingAction();
        base.OnDamagedBySpell(from, damage);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    private sealed class AmbushAI(AbyssAmbusher mobile) : MeleeAI(mobile)
    {
        public override bool DoActionWander() => WaitForPrey() || base.DoActionWander();
        public override bool DoActionGuard() => WaitForPrey() || base.DoActionGuard();
        public override bool DoActionCombat() => WaitForPrey() || base.DoActionCombat();

        private bool WaitForPrey()
        {
            if (!Mobile.Hidden)
            {
                return false;
            }

            if (AcquireFocusMob(2, Mobile.FightMode, true, false, true) && Mobile.FocusMob is { } target &&
                Mobile.CanBeHarmful(target, false) && Mobile.InLOS(target))
            {
                Mobile.RevealingAction();
                Mobile.Combatant = target;
                Action = ActionType.Combat;
            }
            else
            {
                Mobile.Combatant = null;
                Mobile.Warmode = false;
                Action = ActionType.Wander;
            }

            return true;
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class KepetchAmbusher : AbyssAmbusher, ICarvable
{
    [SerializableField(0)]
    private bool _gatheredFur;

    [Constructible]
    public KepetchAmbusher()
    {
        Body = 726;
        SetStr(440, 446);
        SetDex(229, 254);
        SetInt(46);
        SetHits(533, 544);
        SetDamage(7, 17);
        SetDamageType(ResistanceType.Physical, 80);
        SetDamageType(ResistanceType.Poison, 20);
        SetResistance(ResistanceType.Physical, 73, 95);
        SetResistance(ResistanceType.Fire, 57, 70);
        SetResistance(ResistanceType.Cold, 50, 60);
        SetResistance(ResistanceType.Poison, 55, 65);
        SetResistance(ResistanceType.Energy, 70, 95);
        SetSkill(SkillName.Anatomy, 104.3, 114.1);
        SetSkill(SkillName.MagicResist, 94.6, 97.4);
        SetSkill(SkillName.Tactics, 110.4, 123.5);
        SetSkill(SkillName.Wrestling, 107.3, 113.9);
        SetSkill(SkillName.Stealth, 125.0);
        SetSkill(SkillName.Hiding, 125.0);
        Fame = 2500;
        Karma = -2500;
        PackItem(new RawRibs(5));
    }

    public override string DefaultName => "a kepetch ambusher";
    public override string CorpseName => "a kepetch corpse";
    public override FoodType FavoriteFood => FoodType.FruitsAndVeggies | FoodType.GrainsAndHay;
    public override int Meat => 7;
    public override int Hides => 12;
    public override HideType HideType => HideType.Horned;
    public override int GetIdleSound() => 1545;
    public override int GetAngerSound() => 1542;
    public override int GetHurtSound() => 1544;
    public override int GetDeathSound() => 1543;
    public override void GenerateLoot() => AddLoot(LootPack.Average, 2);

    public void Carve(Mobile from, Item item) => KepetchFur.Gather(from, ref _gatheredFur, this);

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (Utility.RandomDouble() < 0.10)
        {
            corpse.DropItem(new KepetchWax());
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class TrapdoorSpider : AbyssAmbusher
{
    [Constructible]
    public TrapdoorSpider()
    {
        Body = 737;
        SetStr(100, 104);
        SetDex(162, 165);
        SetInt(29, 50);
        SetHits(125, 144);
        SetDamage(15, 18);
        SetDamageType(ResistanceType.Physical, 20);
        SetDamageType(ResistanceType.Poison, 80);
        SetResistance(ResistanceType.Physical, 0);
        SetResistance(ResistanceType.Fire, 30, 35);
        SetResistance(ResistanceType.Cold, 30, 35);
        SetResistance(ResistanceType.Poison, 40, 45);
        SetResistance(ResistanceType.Energy, 95, 100);
        SetSkill(SkillName.Anatomy, 2.0, 3.8);
        SetSkill(SkillName.MagicResist, 47.5, 57.9);
        SetSkill(SkillName.Poisoning, 70.5, 73.5);
        SetSkill(SkillName.Tactics, 73.3, 78.9);
        SetSkill(SkillName.Wrestling, 92.5, 94.6);
        SetSkill(SkillName.Hiding, 110.3, 119.9);
        SetSkill(SkillName.Stealth, 110.5, 119.6);
    }

    public override string DefaultName => "a trapdoor spider";
    public override string CorpseName => "a trapdoor spider corpse";
    public override int TreasureMapLevel => 2;
    public override int GetIdleSound() => 1605;
    public override int GetAngerSound() => 1602;
    public override int GetHurtSound() => 1604;
    public override int GetDeathSound() => 1603;
    public override void GenerateLoot() => AddLoot(LootPack.Rich);
}
