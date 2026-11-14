// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Collections;
using Server.ContextMenus;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class ClockworkScorpion : BaseCreature
{
    [Constructible]
    public ClockworkScorpion() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Body = 717;
        ControlSlots = 1;
        Fame = 3500;
        Karma = -3500;
        SetStr(225, 245);
        SetDex(80, 100);
        SetInt(30, 40);
        SetHits(151, 210);
        SetDamage(5, 10);
        SetDamageType(ResistanceType.Physical, 60);
        SetDamageType(ResistanceType.Poison, 40);
        SetResistance(ResistanceType.Physical, 80, 100);
        SetResistance(ResistanceType.Fire, 20, 30);
        SetResistance(ResistanceType.Cold, 60, 80);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 10, 25);
        SetSkill(SkillName.MagicResist, 30.1, 50.0);
        SetSkill(SkillName.Poisoning, 95.1, 100.0);
        SetSkill(SkillName.Tactics, 70.1, 90.0);
        SetSkill(SkillName.Wrestling, 50.1, 80.0);
    }

    public override string DefaultName => "a clockwork scorpion";
    public override string CorpseName => "a clockwork scorpion corpse";
    public override bool IsScaredOfScaryThings => false;
    public override bool IsScaryToPets => true;
    public override bool IsBondable => false;
    public override bool AutoDispel => !Controlled;
    public override bool BleedImmune => true;
    public override bool DeleteOnRelease => true;
    public override bool BardImmune => !Core.AOS || Controlled;
    public override Poison PoisonImmune => Poison.Lethal;
    // Use the pinned server's melee poison path for the construct's poisoning ability.
    public override Poison HitPoison => Poison.Deadly;
    public override FoodType FavoriteFood => FoodType.Meat;
    public override int GetAngerSound() => 541;
    public override int GetIdleSound() => Controlled ? base.GetIdleSound() : 542;
    public override int GetAttackSound() => 562;
    public override int GetHurtSound() => Controlled ? 320 : base.GetHurtSound();
    public override int GetDeathSound() => Controlled ? base.GetDeathSound() : 545;

    public override void GenerateLoot() => AddLoot(LootPack.Meager, 2);
    internal static void RedirectDamageToController(BaseCreature pet, int amount)
    {
        if (pet.GetMaster() is { Player: true } master && master.Map == pet.Map && master.InRange(pet.Location, 20))
        {
            var absorbed = System.Math.Min(master.Mana, amount);
            master.Mana -= absorbed;
            if (absorbed < amount)
            {
                master.Damage(amount - absorbed);
            }
        }
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
        AddMechanicalRepairEntry(this, from, ref list);
    }

    internal static void AddMechanicalRepairEntry(BaseCreature pet, Mobile from, ref PooledRefList<ContextMenuEntry> list)
    {
        if (pet.Controlled && pet.Alive && from.Alive && FindTinkerTool(from) != null)
        {
            list.Add(new RepairEntry());
        }
    }

    private static BaseTool? FindTinkerTool(Mobile from) =>
        from.Backpack?.FindItemByType<TinkerTools>(predicate: tool => tool.UsesRemaining > 0) ??
        (BaseTool?)from.Backpack?.FindItemByType<TinkersTools>(predicate: tool => tool.UsesRemaining > 0);

    private sealed class RepairEntry() : ContextMenuEntry(1011071, 2)
    {
        public override void OnClick(Mobile from, IEntity target)
        {
            if (target is ClockworkScorpion or Vollem or LeatherWolf)
            {
                BeginRepair((BaseCreature)target, from);
            }
        }
    }

    private static void BeginRepair(BaseCreature pet, Mobile from)
    {
        if (!CanRepair(pet, from))
        {
            return;
        }
        if (!from.BeginAction<RepairEntry>())
        {
            from.SendLocalizedMessage(1113611, pet.Name);
            return;
        }

        var delay = Math.Clamp(5.0 - from.Dex / 35.0, 1.0, 5.0);
        Timer.StartTimer(TimeSpan.FromSeconds(delay), () =>
        {
            try
            {
                if (CanRepair(pet, from))
                {
                    ApplyRepair(pet, from);
                }
            }
            finally
            {
                from.EndAction<RepairEntry>();
            }
        });
    }

    private static bool CanRepair(BaseCreature pet, Mobile from)
    {
        if (pet.Deleted || !pet.Alive || !pet.Controlled || !from.Alive || from.Map != pet.Map || !from.InRange(pet.Location, 2) ||
            !from.InLOS(pet) || !from.CanSee(pet) || FindTinkerTool(from) == null)
        {
            return false;
        }
        if (pet.ControlMaster is not { } owner || owner != from &&
            (owner.Map != from.Map || !owner.InRange(from.Location, 10)))
        {
            from.SendLocalizedMessage(1157045);
            return false;
        }
        if (pet.Hits >= pet.HitsMax)
        {
            from.SendLocalizedMessage(1113613, pet.Name);
            return false;
        }
        if (from.Skills.Tinkering.Value < 0.1)
        {
            from.SendLocalizedMessage(1113614, pet.Name);
            return false;
        }
        return from.CanBeBeneficial(pet, true);
    }

    private static void ApplyRepair(BaseCreature pet, Mobile from)
    {
        var skill = from.Skills.Tinkering.Value;
        var repair = Math.Min(pet.HitsMax - pet.Hits, Math.Max(12, (int)(skill * 0.6)));
        if (!from.CheckSkill(SkillName.Tinkering, 0.0, 100.0))
        {
            repair = Math.Max(1, repair / 6);
        }

        var metal = from.Backpack.ConsumeUpTo(typeof(IronIngot), (repair + 4) / 5);
        if (metal == 0)
        {
            from.SendLocalizedMessage(1044037);
            return;
        }

        pet.Hits += Math.Min(repair, metal * 5);
        from.DoBeneficial(pet);
        from.SendLocalizedMessage(1113616, pet.Name);
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.4;
        passiveSpeed = 0.8;
    }

    public override void OnDamage(int amount, Mobile from, bool willKill)
    {
        RedirectDamageToController(this, amount);
        base.OnDamage(amount, from, willKill);
    }
}
