// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using System.Text.Json;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;
using Server.Network;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Only the disposable loopback harness supplies this constructor allow-list.
public static class CreatureFixtures
{
    private sealed record Candidate(int body, string[] classes);
    private static Candidate[] _allowed = [];
    private static readonly Dictionary<Mobile, BaseCreature> _creatures = [];
    private static readonly Dictionary<Mobile, Container> _corpses = [];

    [CallPriority(int.MaxValue)]
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false))
        {
            return;
        }
        var path = Path.Combine(AppContext.BaseDirectory, "Data", "creature-fixtures.local.json");
        if (!File.Exists(path))
        {
            return;
        }
        _allowed = JsonSerializer.Deserialize<Candidate[]>(File.ReadAllText(path)) ?? [];
        CommandSystem.Register("CreatureFixture", AccessLevel.Player, Execute);
    }

    private static void Cleanup(Mobile owner)
    {
        if (_creatures.Remove(owner, out var creature))
        {
            creature.Delete();
        }
        if (_corpses.Remove(owner, out var corpse))
        {
            corpse.Delete();
        }
    }

    private static BaseCreature? Construct(Type type, Mobile summoner, bool explicitlyRequested)
    {
        foreach (var constructor in type.GetConstructors())
        {
            var parameters = constructor.GetParameters();
            var values = new object?[parameters.Length];
            var supported = true;
            for (var i = 0; i < parameters.Length; i++)
            {
                if (parameters[i].HasDefaultValue)
                {
                    values[i] = parameters[i].DefaultValue;
                }
                else if (explicitlyRequested && typeof(BaseEnraged).IsAssignableFrom(type)
                    && parameters[i].ParameterType == typeof(Mobile) && parameters[i].Name == "summoner")
                {
                    // Native meer summons require a living master. The guarded
                    // fixture owner supplies it; no native body/stats are set.
                    values[i] = summoner;
                }
                else
                {
                    supported = false;
                    break;
                }
            }
            if (supported)
            {
                return constructor.Invoke(values) as BaseCreature;
            }
        }
        return null;
    }

    private static void Execute(CommandEventArgs args)
    {
        var owner = args.Mobile;
        if (owner.NetState is not { } state || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }
        var command = args.Length > 0 ? args.GetString(0) : "audit";
        if (command == "cleanup")
        {
            Cleanup(owner);
            owner.SendMessage("UCCREATURE|cleaned");
            return;
        }
        if (command == "prepare" && args.Length > 1)
        {
            Cleanup(owner);
            var body = args.GetInt32(1);
            var requested = args.Length > 2 ? args.GetString(2) : null;
            var candidate = Array.Find(_allowed, row => row.body == body &&
                (requested == null || Array.Exists(row.classes, name => name == requested)));
            if (candidate == null)
            {
                owner.SendMessage("UCCREATURE|blocked|identity-or-arena");
                return;
            }
            foreach (var client in owner.Map.GetClientsInRange(owner.Location))
            {
                if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                {
                    client.Mobile.Blessed = true;
                }
            }
            foreach (var name in candidate.classes)
            {
                if (requested != null && name != requested)
                {
                    continue;
                }
                var type = typeof(BaseCreature).Assembly.GetType("Server.Mobiles." + name);
                if (type == null || type.IsAbstract || !type.IsSubclassOf(typeof(BaseCreature))
                    || type.IsSubclassOf(typeof(BaseMount)) || type.ContainsGenericParameters)
                {
                    continue;
                }
                for (var attempt = 0; attempt < 16; attempt++)
                {
                    var creature = Construct(type, owner, requested != null);
                    if (creature == null)
                    {
                        break;
                    }
                    var nativeState = "constructor";
                    if (creature is Sheep sheep && body == 0xDF)
                    {
                        // Reach the shorn form through the native wool API;
                        // assigning a body ID would not prove the transition.
                        sheep.MoveToWorld(new Point3D(owner.X + 1, owner.Y, owner.Z), owner.Map);
                        var tool = new Dagger();
                        try
                        {
                            sheep.Carve(owner, tool);
                        }
                        finally
                        {
                            tool.Delete();
                        }
                        nativeState = "shorn";
                    }
                    // Random native constructor variants are sampled; body IDs
                    // are never overwritten to manufacture matching evidence.
                    if (creature.Body.BodyID != body)
                    {
                        creature.Delete();
                        continue;
                    }
                    if (creature is BaseFamiliar && !creature.SetControlMaster(owner))
                    {
                        creature.Delete();
                        continue;
                    }
                    if (!AquaticFixtures.Prepare(owner, creature.CanSwim && creature.CantWalk))
                    {
                        creature.Delete();
                        owner.SendMessage("UCCREATURE|blocked|native-surface-arena");
                        return;
                    }
                    creature.Frozen = true;
                    creature.MoveToWorld(new Point3D(owner.X + 1, owner.Y, owner.Z), owner.Map);
                    _creatures[owner] = creature;
                    owner.SendMessage($"UCCREATURE|prepared|{creature.Serial.Value}|{creature.Body.BodyID}|{type.Name}|{creature.Str}|{creature.Dex}|{creature.Int}|{nativeState}|{creature.Wool}|aquatic={(creature.CanSwim && creature.CantWalk ? 1 : 0)}|wet={(AquaticFixtures.IsWetSurface(creature.Map, creature.X, creature.Y, creature.Z) ? 1 : 0)}");
                    return;
                }
            }
            owner.SendMessage("UCCREATURE|blocked|native-constructor");
            return;
        }
        if (!_creatures.TryGetValue(owner, out var subject))
        {
            return;
        }
        if (command == "colour" && args.Length > 1)
        {
            subject.Hue = args.GetInt32(1) & 0xFFFF;
            owner.SendMessage($"UCCREATURE|colour|{subject.Hue}");
        }
        else if (command == "step")
        {
            subject.Frozen = false;
            try
            {
                if (subject.DisallowAllMoves)
                {
                    var before = subject.Location;
                    var ai = subject.AIObject;
                    var allowed = ai?.CheckMove() ?? true;
                    var progressed = ai?.MoveToPoint(new Point3D(before.X + 1, before.Y, before.Z), 0) ?? true;
                    owner.SendMessage(!allowed && !progressed && subject.Location == before
                        ? $"UCCREATURE|step|{subject.X}|{subject.Y}|{subject.Z}|immobile"
                        : "UCCREATURE|blocked|immobile-creature-moved");
                    return;
                }
                for (var direction = 0; direction < 8; direction++)
                {
                    var before = subject.Location;
                    var facing = (Direction)direction | (args.Length > 1 && args.GetInt32(1) != 0 ? Direction.Running : Direction.North);
                    var target = before;
                    Server.Movement.Movement.Offset(facing, ref target);
                    if (!owner.InRange(target, 2))
                    {
                        continue;
                    }
                    for (var turn = 0; turn < 2; turn++)
                    {
                        if (subject.Move(facing) && subject.Location != before)
                        {
                            owner.SendMessage($"UCCREATURE|step|{subject.X}|{subject.Y}|{subject.Z}|wet={(AquaticFixtures.IsWetSurface(subject.Map, subject.X, subject.Y, subject.Z) ? 1 : 0)}");
                            return;
                        }
                    }
                }
                owner.SendMessage("UCCREATURE|blocked|movement");
            }
            finally
            {
                subject.Frozen = true;
            }
        }
        else if (command == "hurt")
        {
            // Use the pinned native method, rather than inventing a group
            // number from a client enum whose historic labels can mislead.
            if (subject.Weapon is BaseWeapon weapon)
            {
                weapon.PlayHurtAnimation(subject);
            }
            owner.SendMessage($"UCCREATURE|hurt|{subject.Serial.Value}");
        }
        else if (command == "breach" && subject is Dolphin dolphin)
        {
            dolphin.Jump();
            owner.SendMessage($"UCCREATURE|breach|{subject.Serial.Value}");
        }
        else if (command == "action" && args.Length > 1)
        {
            var action = args.GetInt32(1);
            if (action is -1 or -2 or -3 or -4 or -5)
            {
                var animationType = action switch { -1 => 4, -2 => 11, -3 => 2, -4 => 5, _ => 14 };
                foreach (var client in subject.Map.GetClientsInRange(subject.Location))
                {
                    if (client.Mobile.CanSee(subject))
                    {
                        client.SendNewMobileAnimation(subject.Serial, animationType, 0, 0);
                    }
                }
            }
            else if (action is >= 0 and <= 21)
            {
                subject.Animate(action, 5, 1, true, false, 0);
            }
            owner.SendMessage($"UCCREATURE|action|{subject.Serial.Value}|{action}");
        }
        else if (command == "kill")
        {
            subject.Frozen = false;
            var damageable = subject.CanBeDamaged();
            subject.Kill();
            if (!subject.Deleted && subject.Alive)
            {
                // Quest actors can veto native death. No corpse does not
                // establish deletion, and this harness must not force either.
                subject.Frozen = true;
                owner.SendMessage($"UCCREATURE|corpse|0|{subject.Body.BodyID}|damageable={(damageable ? 1 : 0)}|refused");
            }
            else if (subject.Corpse is { Deleted: false } corpse)
            {
                _corpses[owner] = corpse;
                owner.SendMessage($"UCCREATURE|corpse|{corpse.Serial.Value}|{subject.Body.BodyID}");
            }
            else
            {
                owner.SendMessage($"UCCREATURE|corpse|0|{subject.Body.BodyID}|suppressed");
            }
        }
    }
}
