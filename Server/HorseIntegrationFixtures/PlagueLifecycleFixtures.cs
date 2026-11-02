// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Only the disposable loopback module enables these native lifecycle probes.
public static class PlagueLifecycleFixtures
{
    private sealed record Pair(PlagueBeast Owner, PlagueSpawn Spawn);
    private static readonly Dictionary<Mobile, Pair> Pairs = [];
    private static readonly int[] Bodies = [14, 31, 400, 401, 29, 21, 51];

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedPlagueTests", false))
        {
            CommandSystem.Register("PlagueLifecycleFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Cleanup(Mobile player)
    {
        if (!Pairs.Remove(player, out var pair))
        {
            return;
        }
        pair.Spawn.Delete();
        pair.Owner.Delete();
    }

    private static void Execute(CommandEventArgs args)
    {
        var player = args.Mobile;
        if (player.NetState is not { } state || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }
        var command = args.Length > 0 ? args.GetString(0) : "audit";
        if (command == "cleanup")
        {
            Cleanup(player);
            player.SendMessage("UCPLAGUE|cleaned");
            return;
        }
        if (command == "prepare" && args.Length > 1)
        {
            Cleanup(player);
            var body = args.GetInt32(1);
            if (!Array.Exists(Bodies, value => value == body) || !AquaticFixtures.Prepare(player, false))
            {
                player.SendMessage("UCPLAGUE|blocked|body-or-arena");
                return;
            }
            foreach (var client in player.Map.GetClientsInRange(player.Location))
            {
                if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                {
                    client.Mobile.Blessed = true;
                }
            }
            var owner = new PlagueBeast { Frozen = true, Blessed = true };
            owner.MoveToWorld(new Point3D(player.X + 1, player.Y, player.Z), player.Map);
            owner.AIObject?.Deactivate();
            // Sample the real damage callback's random constructors. Never
            // manufacture a form by assigning Body, Hue, Owner or native stats.
            for (var attempt = 0; attempt < 4096; attempt++)
            {
                owner.OnGotMeleeAttack(player, 0);
                var spawned = new List<PlagueSpawn>();
                foreach (var candidate in owner.Map.GetMobilesInRange<PlagueSpawn>(owner.Location, 1))
                {
                    if (candidate.Owner == owner)
                    {
                        spawned.Add(candidate);
                    }
                }
                foreach (var candidate in spawned)
                {
                    if (candidate.Body.BodyID == body)
                    {
                        candidate.Frozen = true;
                        // Its ordinary AI timer remains enabled. Native
                        // OnThink owns expiry/range/map/deleted-owner removal.
                        Pairs[player] = new Pair(owner, candidate);
                        var lifetime = (int)(candidate.ExpireTime - Core.Now).TotalMilliseconds;
                        player.SendMessage($"UCPLAGUE|prepared|{candidate.Serial.Value}|{candidate.Body.BodyID}|{candidate.Hue}|{owner.Serial.Value}|{lifetime}|{attempt + 1}|owner={(ReferenceEquals(candidate.Owner, owner) ? 1 : 0)}");
                        return;
                    }
                    candidate.Delete();
                }
            }
            owner.Delete();
            player.SendMessage("UCPLAGUE|blocked|native-random-form-not-observed");
            return;
        }
        if (!Pairs.TryGetValue(player, out var current))
        {
            player.SendMessage("UCPLAGUE|blocked|no-pair");
            return;
        }
        if (command == "owner-range")
        {
            var before = current.Owner.Location;
            current.Owner.MoveToWorld(new Point3D(before.X + 17, before.Y, before.Z), current.Owner.Map);
            player.SendMessage("UCPLAGUE|condition|range");
        }
        else if (command == "owner-map")
        {
            var other = current.Owner.Map == Map.Felucca ? Map.Trammel : Map.Felucca;
            current.Owner.MoveToWorld(current.Owner.Location, other);
            player.SendMessage("UCPLAGUE|condition|map");
        }
        else if (command == "owner-delete")
        {
            current.Owner.Delete();
            player.SendMessage("UCPLAGUE|condition|deleted-owner");
        }
        else if (command == "audit")
        {
            var remaining = (int)(current.Spawn.ExpireTime - Core.Now).TotalMilliseconds;
            player.SendMessage($"UCPLAGUE|audit|{current.Spawn.Serial.Value}|deleted={(current.Spawn.Deleted ? 1 : 0)}|remaining={remaining}");
        }
    }
}
