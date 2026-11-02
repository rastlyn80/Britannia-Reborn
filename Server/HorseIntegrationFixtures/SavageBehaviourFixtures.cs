// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;
using Server.Regions;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Ordinary constructors/callbacks only in the explicitly enabled disposable world.
public static class SavageBehaviourFixtures
{
    private sealed class Group
    {
        public required BaseCreature Lead { get; init; }
        public required BaseCreature[] Dancers { get; init; }
        public required Savage Ally { get; init; }
        public required Ogre Enemy { get; init; }
        public Dictionary<Mobile, bool> Players { get; } = [];
        public long Started { get; set; } = Core.TickCount;
        public int AllyBefore { get; set; }
        public int EnemyBefore { get; set; }
        public Item? Corpse { get; set; }
    }
    private static readonly Dictionary<Serial, Group> Groups = [];
    private static Point3D? _arena;
    private static bool PrepareArena(PlayerMobile owner)
    {
        var map = owner.Map;
        if (_arena == null)
        {
            for (var x = 1200; x <= 1472 && _arena == null; x += 8)
            for (var y = 1800; y <= 2072 && _arena == null; y += 8)
            {
                var z = map.GetAverageZ(x, y); var clear = true;
                for (var dx = -1; dx <= 6 && clear; dx++)
                for (var dy = -1; dy <= 6 && clear; dy++)
                {
                    var point = new Point3D(x + dx, y + dy, z);
                    clear = map.GetAverageZ(point.X, point.Y) == z
                        && !Region.Find(point, map).IsPartOf<GuardedRegion>() && map.CanSpawnMobile(point);
                }
                if (clear) { _arena = new Point3D(x, y, z); }
            }
        }
        if (_arena is not { } arena) { return false; }
        var participants = new List<Mobile>();
        foreach (var client in map.GetClientsInRange(owner.Location))
        {
            if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
            { participants.Add(client.Mobile); }
        }
        for (var i = 0; i < participants.Count; i++)
        { participants[i].MoveToWorld(new Point3D(arena.X + i * 2, arena.Y, arena.Z), map); }
        return true;
    }
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedSavageTests", false))
        {
            CommandSystem.Register("SavageBehaviourFixture", AccessLevel.Player, Execute);
        }
    }
    private static int Flag(bool value) => value ? 1 : 0;
    private static bool AllStopped(Group group) => group.Dancers.All(FixtureAIControls.Stopped)
        && FixtureAIControls.Stopped(group.Ally) && FixtureAIControls.Stopped(group.Enemy);
    private static void Stop(Group group)
    {
        foreach (var dancer in group.Dancers) { FixtureAIControls.Stop(dancer); }
        FixtureAIControls.Stop(group.Ally); FixtureAIControls.Stop(group.Enemy);
    }
    private static void Cleanup(PlayerMobile player)
    {
        if (!Groups.Remove(player.Serial, out var group)) { return; }
        foreach (var dancer in group.Dancers) { dancer.Delete(); }
        group.Ally.Delete(); group.Enemy.Delete();
        group.Corpse?.Delete();
        foreach (var pair in group.Players)
        {
            if (!pair.Key.Deleted) { pair.Key.Blessed = pair.Value; }
        }
    }
    private static BaseCreature? Construct(string kind, int body)
    {
        for (var attempt = 0; attempt < 32; attempt++)
        {
            BaseCreature candidate = kind == "shaman" ? new SavageShaman() : new Savage();
            if (candidate.Body.BodyID == body) { return candidate; }
            candidate.Delete();
        }
        return null;
    }
    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile player || player.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true) { return; }
        var command = args.GetString(0);
        if (command == "cleanup") { Cleanup(player); player.SendMessage("UCSAVAGE|clean"); return; }
        if (command == "prepare")
        {
            Cleanup(player);
            var kind = args.GetString(1); var body = args.GetInt32(2); var count = args.GetInt32(3);
            if (kind is not ("savage" or "shaman") || body is not (183 or 184)
                || count is not (1 or 4) || kind == "savage" && count != 1
                || !PrepareArena(player))
            { player.SendMessage("UCSAVAGE|blocked|kind-body-quorum-or-arena"); return; }
            var lead = Construct(kind, body);
            if (lead == null) { player.SendMessage("UCSAVAGE|blocked|constructor-sampling"); return; }
            var dancers = new BaseCreature[count]; dancers[0] = lead;
            for (var i = 1; i < count; i++) { dancers[i] = new SavageShaman(); }
            var group = new Group { Lead = lead, Dancers = dancers, Ally = new Savage { Frozen = true }, Enemy = new Ogre { Frozen = true } };
            for (var i = 0; i < count; i++)
            {
                dancers[i].MoveToWorld(new Point3D(player.X + 1 + i, player.Y + 2 + i % 2, player.Z), player.Map);
            }
            group.Ally.MoveToWorld(new Point3D(player.X + 1, player.Y + 4, player.Z), player.Map);
            group.Enemy.MoveToWorld(new Point3D(player.X + 3, player.Y + 5, player.Z), player.Map);
            // Only disposable participants are protected from this area callback.
            foreach (var client in player.Map.GetClientsInRange(player.Location))
            {
                if (client.Mobile is { } observer
                    && observer.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                { group.Players[observer] = observer.Blessed; observer.Blessed = true; }
            }
            Stop(group); Groups[player.Serial] = group;
            player.SendMessage($"UCSAVAGE|prepared|{lead.Serial.Value}|{lead.Body.BodyID}|{lead.GetType().Name}|{string.Join(',', dancers.Select(d => d.Serial.Value))}|{group.Ally.Serial.Value}|{group.Enemy.Serial.Value}|{count}|{Flag(lead.Female)}|{lead.Hue}|{Flag(AllStopped(group))}|{Flag(lead.Region.IsPartOf<GuardedRegion>())}");
            return;
        }
        if (!Groups.TryGetValue(player.Serial, out var current))
        { player.SendMessage("UCSAVAGE|blocked|no-group"); return; }
        if (current.Lead.Deleted)
        { player.SendMessage("UCSAVAGE|blocked|lead-deleted"); return; }
        switch (command)
        {
            case "kill":
                Stop(current);
                var body = current.Lead.Body.BodyID;
                current.Lead.Kill();
                if (current.Lead.Corpse is { Deleted: false } corpse)
                {
                    current.Corpse = corpse;
                    player.SendMessage($"UCSAVAGE|corpse|{corpse.Serial.Value}|{body}");
                }
                else
                {
                    player.SendMessage("UCSAVAGE|blocked|native-death-without-corpse");
                }
                break;
            case "ai":
                player.SendMessage($"UCSAVAGE|ai|{Flag(AllStopped(current))}");
                break;
            case "dance" when current.Lead is SavageShaman shaman:
                Stop(current);
                // Explicit initial conditions, not changed maxima/skills/deadlines or forced randomness.
                current.Enemy.CurePoison(shaman); current.Enemy.Hits = current.Enemy.HitsMax;
                current.Ally.CurePoison(shaman); current.Ally.Hits = Math.Max(1, current.Ally.HitsMax - 25);
                current.AllyBefore = current.Ally.Hits; current.EnemyBefore = current.Enemy.Hits;
                current.Started = Core.TickCount;
                shaman.BeginSavageDance();
                player.SendMessage($"UCSAVAGE|dance|{current.Started}|{shaman.AIObject.NextMove - current.Started}|{current.Dancers.Length}|{Flag(AllStopped(current))}");
                break;
            case "status":
                player.SendMessage($"UCSAVAGE|status|{Core.TickCount - current.Started}|{current.AllyBefore}|{current.Ally.Hits}|{current.EnemyBefore}|{current.Enemy.Hits}|{current.Enemy.Poison?.Level ?? -1}|{Flag(AllStopped(current))}");
                break;
            case "action":
                var action = args.GetInt32(1);
                if (action is >= 0 and <= 34 && action is not (>= 23 and <= 29))
                { current.Lead.Animate(action, 5, 1, true, false, 0); player.SendMessage($"UCSAVAGE|action|{action}"); }
                break;
            case "hue":
                current.Lead.Hue = Math.Clamp(args.GetInt32(1), 0, 0xFFFF);
                player.SendMessage($"UCSAVAGE|hue|{current.Lead.Hue}");
                break;
            case "walk":
            case "run":
                Stop(current);
                var moved = current.Lead.Move(command == "walk" ? Direction.East : Direction.West | Direction.Running);
                Stop(current);
                player.SendMessage($"UCSAVAGE|move|{Flag(moved)}|{current.Lead.X}|{current.Lead.Y}|{current.Lead.Z}|{(int)current.Lead.Direction}|{Flag(AllStopped(current))}");
                break;
        }
    }
}
