// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Items;
using Server.Targeting;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class NavreyNightEyes : BaseCreature
{
    private static readonly MonsterAbility[] _abilities = [new NavreyWebAttack()];

    [Constructible]
    public NavreyNightEyes() : base(AIType.AI_Mage, FightMode.Closest, 10, 1)
    {
        Body = 735;
        BaseSoundID = 389;
        SetStr(1000, 1500);
        SetDex(200, 250);
        SetInt(150, 200);
        SetHits(30000, 35000);
        SetDamage(25, 40);
        SetDamageType(ResistanceType.Physical, 50);
        SetDamageType(ResistanceType.Fire, 25);
        SetDamageType(ResistanceType.Energy, 25);
        SetResistance(ResistanceType.Physical, 55, 65);
        SetResistance(ResistanceType.Fire, 45, 55);
        SetResistance(ResistanceType.Cold, 60, 70);
        SetResistance(ResistanceType.Poison, 100);
        SetResistance(ResistanceType.Energy, 65, 80);
        SetSkill(SkillName.Anatomy, 50.0, 80.0);
        SetSkill(SkillName.EvalInt, 90.0, 100.0);
        SetSkill(SkillName.Magery, 90.0, 100.0);
        SetSkill(SkillName.MagicResist, 100.0, 130.0);
        SetSkill(SkillName.Meditation, 80.0, 100.0);
        SetSkill(SkillName.Poisoning, 100.0);
        SetSkill(SkillName.Tactics, 90.0, 100.0);
        SetSkill(SkillName.Wrestling, 91.6, 98.2);
        Fame = 24000;
        Karma = -24000;
        VirtualArmor = 90;
    }

    public override string DefaultName => "Navrey Night-Eyes";
    public override string CorpseName => "a navrey corpse";
    public override bool AlwaysMurderer => true;
    public override Poison PoisonImmune => Poison.Lethal;
    public override Poison HitPoison => Poison.Lethal;
    public override int Meat => 1;
    public override MonsterAbility[] GetMonsterAbilities() => _abilities;
    public override void GenerateLoot() => AddLoot(LootPack.AosSuperBoss, 3);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        UnderworldFortune.DropCoin(corpse, 0.10);
    }
}

internal sealed class NavreyWebAttack : MonsterAbility
{
    public override MonsterAbilityTrigger AbilityTrigger =>
        MonsterAbilityTrigger.GiveMeleeDamage | MonsterAbilityTrigger.TakeMeleeDamage;

    public override double ChanceToTrigger => 0.10;
    public override TimeSpan MinTriggerCooldown => TimeSpan.FromSeconds(30);
    public override TimeSpan MaxTriggerCooldown => MinTriggerCooldown;

    public override void Trigger(MonsterAbilityTrigger trigger, BaseCreature source, Mobile opponent)
    {
        if (source.Summoned || source.Map is not { } map || map == Map.Internal)
        {
            return;
        }

        var candidates = new List<PlayerMobile>();
        foreach (var player in map.GetMobilesInRange<PlayerMobile>(source.Location, 12))
        {
            if (player.NetState != null && player.Alive && !player.Frozen && source.CanBeHarmful(player, false) &&
                source.CanSee(player) && source.InLOS(player))
            {
                candidates.Add(player);
            }
        }

        if (candidates.Count == 0)
        {
            return;
        }

        var target = candidates[Utility.Random(candidates.Count)];
        base.Trigger(trigger, source, target);
        source.DoHarmful(target);
        source.Direction = source.GetDirectionTo(target);
        source.Animate(19, 13, 1, true, false, 0);
        var web = new NavreyWeb(target);
        Timer.StartTimer(TimeSpan.FromSeconds(0.35), () =>
        {
            if (!source.Deleted && source.Map == map && target.NetState != null && target.Map == map && !web.Deleted)
            {
                Effects.SendMovingParticles(source, target, web.ItemID, 12, 0, false, false, 0, 0, 9502, 1, 0, 0x100);
            }
        });
    }
}

[SerializationGenerator(0)]
public sealed partial class NavreyWeb : Item
{
    private PlayerMobile? _victim;
    private readonly Map? _map;
    private TimerExecutionToken _arrival;
    private TimerExecutionToken _release;
    private static readonly TimeSpan _duration = TimeSpan.FromSeconds(10);

    public NavreyWeb(PlayerMobile victim) : base(0xEE3 + Utility.Random(4))
    {
        _victim = victim;
        _map = victim.Map;
        Movable = false;
        victim.RevealingAction();
        victim.Frozen = true;
        victim.SendLocalizedMessage(1113247);
        victim.AddBuff(new BuffInfo(BuffIcon.Webbing, 1153789, 1153825, _duration));
        Timer.StartTimer(TimeSpan.FromSeconds(0.85), Arrive, out _arrival);
        Timer.StartTimer(_duration, Delete, out _release);
    }

    public override bool BlocksFit => true;

    private void Arrive()
    {
        if (_victim is not { Alive: true, Deleted: false, NetState: not null } victim || victim.Map != _map)
        {
            Delete();
            return;
        }

        MoveToWorld(victim.Location, victim.Map);
    }

    public override void OnDelete()
    {
        _arrival.Cancel();
        _release.Cancel();
        if (_victim is { Deleted: false } victim)
        {
            victim.Frozen = false;
            victim.RemoveBuff(BuffIcon.Webbing);
            if (victim.Alive)
            {
                victim.SendLocalizedMessage(1113248);
            }
        }

        _victim = null;
        base.OnDelete();
    }

    [AfterDeserialization]
    private void ExpireAfterLoad() => Delete();
}

[SerializationGenerator(0)]
public sealed partial class NavreyAcidPopper : Item
{
    [Constructible]
    public NavreyAcidPopper() : base(0x2808)
    {
        Hue = 0x3F;
        Stackable = true;
    }

    public override int LabelNumber => 1095058;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Backpack is not { } pack || !IsChildOf(pack))
        {
            from.SendLocalizedMessage(1042664);
            return;
        }

        from.BeginTarget(1, false, TargetFlags.None, (player, selected) =>
        {
            if (!Deleted && player.Backpack is { } bag && IsChildOf(bag) &&
                selected is NavreyWeb { Deleted: false } web && web.Map == player.Map &&
                player.InRange(web.Location, 1) && player.InLOS(web))
            {
                player.SendLocalizedMessage(1113240);
                player.FixedEffect(0x374A, 1, 10);
                player.PlaySound(0x3E);
                player.PlaySound(0x22F);
                web.Delete();
                Consume();
            }
        });
    }
}
