// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class ChickenLizardBase : BaseCreature
{
    [SerializableField(0)]
    [SerializedCommandProperty(AccessLevel.GameMaster)]
    private DateTime _nextEggAttempt;

    [SerializableField(1)]
    private DateTime _oldestRecentEgg;

    [SerializableField(2)]
    private DateTime _latestEgg;

    protected ChickenLizardBase() : base(AIType.AI_Animal, FightMode.Aggressor, 10, 1)
    {
        Body = 716;
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 15, 20);
        SetResistance(ResistanceType.Fire, 5, 15);
        ControlSlots = 1;
        Tamable = true;
        MinTameSkill = 0;
    }

    public override string CorpseName => "a chicken lizard corpse";
    public override int Meat => 3;
    public override MeatType MeatType => MeatType.Bird;
    public override FoodType FavoriteFood => FoodType.GrainsAndHay;
    public override bool CheckFoodPreference(Item food) => food is SheafOfHay;
    public override int GetAngerSound() => 1508;
    public override int GetDeathSound() => 1509;
    public override int GetHurtSound() => 1510;
    public override int GetIdleSound() => 1511;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override bool CheckFeed(Mobile from, Item food)
    {
        var bonded = IsBonded;
        if (from.Map == null || from.Map == Map.Internal || !base.CheckFeed(from, food))
        {
            return false;
        }

        if (from != ControlMaster || !IsBonded)
        {
            return true;
        }

        var now = Core.Now;
        if (!bonded)
        {
            NextEggAttempt = now.AddDays(1);
            return true;
        }

        if (now >= _nextEggAttempt)
        {
            NextEggAttempt = now.AddDays(1);
            if ((_oldestRecentEgg == DateTime.MinValue || now - _oldestRecentEgg >= TimeSpan.FromDays(7)) &&
                Utility.RandomBool())
            {
                var egg = new ChickenLizardEgg();
                if (from.Backpack?.TryDropItem(from, egg, false) != true)
                {
                    egg.MoveToWorld(from.Location, from.Map);
                }
                OldestRecentEgg = _latestEgg;
                LatestEgg = now;
                from.SendLocalizedMessage(1112485);
            }
        }

        return true;
    }
}

[SerializationGenerator(0)]
public partial class ChickenLizard : ChickenLizardBase
{
    [Constructible]
    public ChickenLizard()
    {
        SetStr(74, 95);
        SetDex(78, 95);
        SetInt(6, 10);
        SetHits(74, 95);
        SetStam(78, 95);
        SetMana(6, 10);
        SetDamage(2, 5);
        SetSkill(SkillName.MagicResist, 25.1, 29.6);
        SetSkill(SkillName.Tactics, 30.1, 44.9);
        SetSkill(SkillName.Wrestling, 26.2, 38.2);
    }

    public override string DefaultName => "a chicken lizard";

    public override void GenerateLoot(bool spawning)
    {
        base.GenerateLoot(spawning);
        if (!spawning && !Controlled && !Summoned && Utility.RandomDouble() < 0.05)
        {
            PackItem(new ChickenLizardEgg());
        }
    }
}

[SerializationGenerator(0)]
public partial class BattleChickenLizard : ChickenLizardBase
{
    private bool _wildFleeing;
    [Constructible]
    public BattleChickenLizard()
    {
        SetStr(94, 177);
        SetDex(78, 124);
        SetInt(6, 13);
        SetHits(94, 177);
        SetDamage(4, 7);
        SetSkill(SkillName.MagicResist, 30.0, 53.0);
        SetSkill(SkillName.Tactics, 50.0, 62.0);
        SetSkill(SkillName.Wrestling, 50.0, 62.0);
    }

    public override string DefaultName => "a battle chicken lizard";

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = Controlled ? 0.2 : 0.05;
        passiveSpeed = Controlled ? 0.4 : 0.1;
    }

    public override void OnCombatantChange()
    {
        base.OnCombatantChange();
        if (!Controlled && Combatant != null && !CheckFlee() && Utility.RandomDouble() >= 0.05)
        {
            _wildFleeing = true;
            BeginFlee(TimeSpan.FromSeconds(30));
        }
    }

    public override void OnThink()
    {
        if (Controlled && (_wildFleeing || ActiveSpeed != 0.2))
        {
            _wildFleeing = false;
            StopFlee();
            ActiveSpeed = 0.2;
            PassiveSpeed = 0.4;
        }
        base.OnThink();
    }
}
