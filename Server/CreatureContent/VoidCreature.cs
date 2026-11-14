// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using System.Collections.Generic;
using System.Linq;
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.Spawners;
using Server.Items;

namespace Server.Mobiles;

public enum VoidLineage
{
    None,
    Survival,
    Grouping,
    Killing
}

[SerializationGenerator(0)]
public abstract partial class VoidCreature : BaseCreature
{
    [SerializableField(0)]
    [SerializedCommandProperty(AccessLevel.GameMaster)]
    private DateTime _nextEvolution;

    [SerializableField(1)]
    [SerializedCommandProperty(AccessLevel.GameMaster)]
    private bool _groupEvolution;

    private Mobile? _lastCombatant;

    protected VoidCreature(AIType ai) : base(ai, FightMode.Closest, 10, 1)
    {
        _nextEvolution = Core.Now.AddMinutes(Utility.RandomMinMax(30, 120));
        _groupEvolution = true;
    }

    public abstract VoidLineage Lineage { get; }
    public abstract int Stage { get; }
    public override bool AlwaysMurderer => true;
    public override bool PlayerRangeSensitive => Lineage != VoidLineage.Killing && Stage < 3;

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    public override bool IsEnemy(Mobile target) =>
        base.IsEnemy(target) &&
        (target.Karma >= 0 ||
         Aggressors.Any(aggression => aggression.Attacker == target) ||
         Aggressed.Any(aggression => aggression.Defender == target));

    public override void OnGaveMeleeAttack(Mobile defender, int damage)
    {
        base.OnGaveMeleeAttack(defender, damage);
        if (Stage < 3 && WasKilled(defender))
        {
            CheckKillAfterDamage(defender);
        }
    }

    public override void DoHarmful(Mobile target, bool indirect = false)
    {
        base.DoHarmful(target, indirect);
        if (CanEvolve && target != this)
        {
            CheckKillAfterDamage(target);
        }
    }

    private void CheckKillAfterDamage(Mobile target)
    {
        // Damage and secondary effects finish before the attacker leaves the world.
        Timer.DelayCall(TimeSpan.Zero, () =>
        {
            if (WasKilled(target))
            {
                Evolve(VoidLineage.Killing);
            }
        });
    }

    public override void OnThink()
    {
        base.OnThink();
        if (Stage >= 3 || !CanEvolve)
        {
            return;
        }

        if (WasKilled(Combatant) || WasKilled(_lastCombatant) ||
            Aggressed.Any(aggression => WasKilled(aggression.Defender)))
        {
            Evolve(VoidLineage.Killing);
            return;
        }
        _lastCombatant = Combatant;

        if (_nextEvolution <= Core.Now && !EvolveWithGroup())
        {
            Evolve(VoidLineage.Survival);
        }
    }

    private bool CanEvolve => Alive && Stage < 3 && Map != null && Map != Map.Internal && !Controlled && !Summoned;

    private bool WasKilled(Mobile? target) =>
        target is { Alive: false } && target.LastKiller == this &&
        (target.Deleted || target.Map == Map);

    private bool EvolveWithGroup()
    {
        if (!_groupEvolution)
        {
            return false;
        }

        var neighbors = new List<VoidCreature>();
        foreach (var neighbor in Map.GetMobilesInRange<VoidCreature>(Location, 12))
        {
            if (neighbor != this && neighbor.Alive && neighbor._groupEvolution && !neighbor.Controlled &&
                !neighbor.Summoned && (Stage > 0 || neighbor.Stage == 0))
            {
                neighbors.Add(neighbor);
            }
        }
        if (neighbors.Count < 2)
        {
            return false;
        }

        Evolve(VoidLineage.Grouping);
        foreach (var neighbor in neighbors)
        {
            neighbor.Evolve(VoidLineage.Grouping);
        }

        return true;
    }

    private void Evolve(VoidLineage trigger)
    {
        if (!CanEvolve)
        {
            return;
        }

        var spawner = Spawner as BaseSpawner;
        SpawnerEntry? entry = null;
        var slot = -1;
        if (Spawner != null)
        {
            if (spawner?.Spawned?.TryGetValue(this, out entry) != true ||
                (slot = entry!.Spawned.IndexOf(this)) < 0)
            {
                // Retry later if the owner cannot safely transfer this spawn.
                _nextEvolution = Core.Now.AddMinutes(1);
                this.MarkDirty();
                return;
            }
        }

        var lineage = Stage == 0 ? trigger : Lineage;
        VoidCreature replacement = (lineage, Stage) switch
        {
            (VoidLineage.Survival, 0) => new Anzuanord(),
            (VoidLineage.Survival, 1) => new Relanord(),
            (VoidLineage.Survival, 2) => new Vasanord(),
            (VoidLineage.Grouping, 0) => new Anlorzen(),
            (VoidLineage.Grouping, 1) => new Anlorlem(),
            (VoidLineage.Grouping, 2) => new Anlorvaglem(),
            (VoidLineage.Killing, 0) => new Betballem(),
            (VoidLineage.Killing, 1) => new Ballem(),
            (VoidLineage.Killing, 2) => new UsagralemBallem(),
            _ => throw new InvalidOperationException("Invalid Void evolution.")
        };

        var map = Map;
        var position = Location;
        replacement._groupEvolution = _groupEvolution;
        replacement.Home = Home;
        replacement.RangeHome = RangeHome;
        replacement.Team = Team;
        replacement.Direction = Direction;
        if (entry != null && spawner != null)
        {
            entry.Spawned[slot] = replacement;
            spawner.Spawned.Remove(this);
            spawner.Spawned.Add(replacement, entry);
            replacement.Spawner = spawner;
            Spawner = null;
            spawner.MarkDirty();
        }

        var target = Combatant;
        replacement.OnBeforeSpawn(position, map);
        replacement.MoveToWorld(position, map);
        replacement.OnAfterSpawn();
        if (target is { Alive: true } && target.Map == map && replacement.CanBeHarmful(target, false))
        {
            replacement.Combatant = target;
        }
        Delete();

        for (var roll = 0; roll < 2; roll++)
        {
            if (Utility.RandomDouble() < 0.05)
            {
                SpawnOrtanord(map, position);
            }
        }
    }

    private static void SpawnOrtanord(Map map, Point3D origin)
    {
        for (var attempt = 0; attempt < 25; attempt++)
        {
            var x = origin.X + Utility.RandomMinMax(-5, 5);
            var y = origin.Y + Utility.RandomMinMax(-5, 5);
            var candidate = new Point3D(x, y, map.GetAverageZ(x, y));
            if (map.CanSpawnMobile(candidate))
            {
                var anomaly = new Ortanord();
                anomaly.OnBeforeSpawn(candidate, map);
                anomaly.MoveToWorld(candidate, map);
                anomaly.OnAfterSpawn();
                anomaly.BoltEffect(0);
                return;
            }
        }
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (corpse == null || corpse.Deleted || Controlled || Summoned)
        {
            return;
        }

        if (Stage > 0 && Utility.RandomDouble() < 0.02 * (Stage + 3))
        {
            corpse.DropItem(new VoidEssence());
        }
        if (Stage == 3 && Utility.RandomDouble() < 0.12)
        {
            corpse.DropItem(new VoidCore());
        }
        if (Utility.RandomDouble() < 0.05 * (Stage + 1))
        {
            corpse.DropItem(new VoidOrb());
        }
    }
}

public static class VoidEncounterPlacement
{
    public static void Initialize() =>
        CommandSystem.Register("PlaceKorpreGroup", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        if (actor.Map != Map.TerMur || !Map.TerMur.CanFit(actor.Location, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on a clear tile in Ter Mur.");
            return;
        }

        foreach (var nearby in Map.TerMur.GetItemsInRange<Spawner>(actor.Location, 12))
        {
            if (nearby.Entries.Any(entry => entry.SpawnedName.Equals(nameof(Korpre), StringComparison.OrdinalIgnoreCase)))
            {
                actor.SendMessage($"A Korpre spawner is already at {nearby.Location}.");
                return;
            }
        }

        var spawner = new Spawner(3, TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(10), spawnedNames: nameof(Korpre));
        spawner.MoveToWorld(actor.Location, Map.TerMur);
        spawner.HomeRange = 4;
        spawner.WalkingRange = 5;
        spawner.Respawn();
        spawner.Start();
        actor.SendMessage($"Korpre spawner placed at {spawner.Location}.");
    }
}
