// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Collections;
using Server.ContextMenus;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class SutekConstruct : BaseCreature
{
    protected SutekConstruct(AIType ai, FightMode mode) : base(ai, mode, 10, 1)
    {
    }

    public override bool IsScaredOfScaryThings => false;
    public override bool IsScaryToPets => true;
    public override bool IsBondable => false;
    public override bool AutoDispel => !Controlled;
    public override bool BleedImmune => true;
    public override bool DeleteOnRelease => true;
    public override bool BardImmune => !Core.AOS || Controlled;
    public override FoodType FavoriteFood => FoodType.Meat;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnHeal(ref int amount, Mobile from)
    {
        if (amount > 0)
        {
            amount = 0;
            from?.SendLocalizedMessage(500951);
        }
    }

    public override void GetContextMenuEntries(Mobile from, ref PooledRefList<ContextMenuEntry> list)
    {
        base.GetContextMenuEntries(from, ref list);
        ClockworkScorpion.AddMechanicalRepairEntry(this, from, ref list);
    }
}

[SerializationGenerator(0)]
public partial class Vollem : SutekConstruct
{
    private static readonly MonsterAbility[] _abilities = [MonsterAbilities.FireBreath];

    [Constructible]
    public Vollem() : base(AIType.AI_Mage, FightMode.Closest)
    {
        Body = 293;
        ControlSlots = 2;
        SetStr(496, 524);
        SetDex(88, 105);
        SetInt(94, 117);
        SetHits(300, 315);
        SetDamage(16, 22);
        SetDamageType(ResistanceType.Physical, 40);
        SetDamageType(ResistanceType.Fire, 40);
        SetDamageType(ResistanceType.Energy, 20);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 30, 40);
        SetResistance(ResistanceType.Poison, 30, 40);
        SetResistance(ResistanceType.Energy, 20, 30);
        SetSkill(SkillName.MagicResist, 90.4, 97.8);
        SetSkill(SkillName.Tactics, 99.0, 99.5);
        SetSkill(SkillName.Wrestling, 84.2, 87.7);
        SetSkill(SkillName.EvalInt, 21.9, 43.3);
        SetSkill(SkillName.Magery, 25.6, 38.6);
    }

    public override string DefaultName => "a vollem";
    public override string CorpseName => "a vollem corpse";
    public override int Meat => 5;
    public override int Hides => 10;
    public override Poison PoisonImmune => Poison.Lethal;
    public override int GetAngerSound() => 541;
    public override int GetIdleSound() => Controlled ? base.GetIdleSound() : 542;
    public override int GetDeathSound() => Controlled ? base.GetDeathSound() : 545;
    public override int GetAttackSound() => 562;
    public override int GetHurtSound() => Controlled ? 320 : base.GetHurtSound();
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;

    public override void OnDamage(int amount, Mobile from, bool willKill)
    {
        ClockworkScorpion.RedirectDamageToController(this, amount);
        base.OnDamage(amount, from, willKill);
    }
}

[SerializationGenerator(0)]
public partial class LeatherWolf : SutekConstruct
{
    [SerializableField(0)]
    private List<LeatherWolfFellow> _fellows = [];

    private TimerExecutionToken _packTimer;

    [Constructible]
    public LeatherWolf() : base(AIType.AI_Melee, FightMode.Aggressor)
    {
        Body = 739;
        BaseSoundID = 0xE5;
        ControlSlots = 1;
        Fame = 4500;
        Karma = -4500;
        SetStr(104, 125);
        SetDex(102, 125);
        SetInt(20, 34);
        SetHits(291, 329);
        SetDamage(12, 23);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 40, 49);
        SetResistance(ResistanceType.Fire, 20, 29);
        SetResistance(ResistanceType.Cold, 30, 40);
        SetResistance(ResistanceType.Poison, 21, 29);
        SetResistance(ResistanceType.Energy, 20, 25);
        SetSkill(SkillName.MagicResist, 79.5, 94.9);
        SetSkill(SkillName.Tactics, 80.6, 89.4);
        SetSkill(SkillName.Wrestling, 70.9, 88.4);
    }

    public override string DefaultName => "a leather wolf";
    public override string CorpseName => "a wolf corpse";
    public override bool AlwaysMurderer => !Controlled;
    public override int Meat => 1;
    public override int Hides => 7;
    public override PackInstinct PackInstinct => PackInstinct.Canine;
    public override int GetIdleSound() => 1545;
    public override int GetAngerSound() => 1542;
    public override int GetHurtSound() => 1544;
    public override int GetDeathSound() => 1543;
    public override WeaponAbility GetWeaponAbility() => WeaponAbility.BleedAttack;
    public override void GenerateLoot() => AddLoot(LootPack.Meager, 2);

    public override void OnCombatantChange()
    {
        base.OnCombatantChange();
        if (Combatant is { Alive: true } && !_packTimer.Running)
        {
            SchedulePack(TimeSpan.Zero);
        }
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        ClearPack();
        if (corpse is { Deleted: false } && !Controlled && !Summoned && Utility.RandomDouble() < .20)
        {
            corpse.DropItem(new LeatherWolfSkin());
        }
    }

    public override void OnAfterDelete()
    {
        ClearPack();
        base.OnAfterDelete();
    }

    [AfterDeserialization]
    private void RestorePack()
    {
        _fellows ??= [];
        if (_fellows.Count != 0 || Combatant is { Alive: true })
        {
            SchedulePack(TimeSpan.FromSeconds(1));
        }
    }

    private void SchedulePack(TimeSpan delay) => Timer.StartTimer(delay, CheckPack, out _packTimer);

    private void CheckPack()
    {
        if (!Alive || Combatant is not { Alive: true } foe || Map is not { } map || map == Map.Internal ||
            foe.Map != map || !CanBeHarmful(foe, false))
        {
            ClearPack();
            return;
        }
        var changed = _fellows.RemoveAll(member => member.Deleted) != 0;
        var added = false;
        for (var attempt = 0; _fellows.Count < 3 && attempt < 24; attempt++)
        {
            var x = X + Utility.RandomMinMax(-6, 6);
            var y = Y + Utility.RandomMinMax(-6, 6);
            var location = new Point3D(x, y, map.GetAverageZ(x, y));
            if (!map.CanSpawnMobile(location))
            {
                continue;
            }
            var helper = new LeatherWolfFellow { Team = Team };
            helper.MoveToWorld(location, map);
            helper.Combatant = foe;
            _fellows.Add(helper);
            added = true;
        }
        if (added)
        {
            Say(1113132);
            PlaySound(0xE6);
        }
        if (added || changed)
        {
            this.MarkDirty();
        }
        SchedulePack(TimeSpan.FromSeconds(30));
    }

    private void ClearPack()
    {
        _packTimer.Cancel();
        if (_fellows.Count == 0)
        {
            return;
        }
        foreach (var member in _fellows)
        {
            member.Delete();
        }
        _fellows.Clear();
        this.MarkDirty();
    }
}

[SerializationGenerator(0)]
public partial class LeatherWolfFellow : BaseCreature
{
    [Constructible]
    public LeatherWolfFellow() : base(AIType.AI_Melee, FightMode.Aggressor, 10, 1)
    {
        Body = 739;
        BaseSoundID = 0xE5;
        Fame = 2500;
        Karma = -2500;
        SetStr(105, 115);
        SetDex(101, 114);
        SetInt(23, 34);
        SetHits(81, 110);
        SetDamage(9, 20);
        SetDamageType(ResistanceType.Physical, 100);
        SetResistance(ResistanceType.Physical, 36, 50);
        SetResistance(ResistanceType.Fire, 10, 18);
        SetResistance(ResistanceType.Cold, 23, 29);
        SetResistance(ResistanceType.Poison, 10, 17);
        SetResistance(ResistanceType.Energy, 10, 15);
        SetSkill(SkillName.MagicResist, 59.2, 75.0);
        SetSkill(SkillName.Tactics, 53.3, 64.8);
        SetSkill(SkillName.Wrestling, 64.0, 79.0);
    }

    public override string DefaultName => "a leather wolf";
    public override string CorpseName => "a wolf corpse";
    public override PackInstinct PackInstinct => PackInstinct.Canine;
}
