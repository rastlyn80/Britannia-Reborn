// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using System.Text.Json;
using Server;
using Server.Commands;

namespace UltimaClone.PreviewTools;

// Developer travel (owner request, 31 October 2026): the client's Travel menu
// lists ModernUO's own Trammel locations (Data/Locations/trammel.json: towns,
// dungeons by level, shrines) and moves the developer there. Loopback- and
// previewTools-only, like the other preview commands; the move is the
// server's own MoveToWorld, so the client is resynchronised as usual.
//   [PreviewLocations  -> one "UCLOC1|category|group|place|x|y|z" line each
//   [PreviewGo x y z   -> moves the caller on Trammel, answers "UCGO1|x|y|z"
//   [PreviewDie / [PreviewResurrect -> the server's own Kill()/Resurrect(), to
//   check death presentation (ghost, black and white) without a fight.
public static class PreviewTravel
{
    private static readonly string[] _skipped = ["Internal"];

    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false)) return;
        CommandSystem.Register("PreviewLocations", AccessLevel.Player, Locations);
        CommandSystem.Register("PreviewGo", AccessLevel.Player, Go);
        CommandSystem.Register("PreviewDie", AccessLevel.Player, Die);
        CommandSystem.Register("PreviewResurrect", AccessLevel.Player, Resurrect);
    }

    private static bool Allowed(CommandEventArgs args)
    {
        if (args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address)) return true;
        args.Mobile.SendMessage("Preview tools are available only on the local development connection.");
        return false;
    }

    private static void Locations(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        var path = Path.Combine(Core.BaseDirectory, "Data/Locations/trammel.json");
        if (!File.Exists(path))
        {
            args.Mobile.SendMessage("UCLOC1|none");
            return;
        }
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var count = 0;
        foreach (var category in document.RootElement.GetProperty("categories").EnumerateArray())
        {
            var name = category.GetProperty("name").GetString() ?? "";
            if (Array.IndexOf(_skipped, name) >= 0) continue;
            count += Send(args.Mobile, name, name, category);
            if (!category.TryGetProperty("categories", out var groups)) continue;
            foreach (var group in groups.EnumerateArray())
            {
                count += Send(args.Mobile, name, group.GetProperty("name").GetString() ?? "", group);
            }
        }
        args.Mobile.SendMessage($"UCLOC1|end|{count}");
    }

    private static int Send(Mobile to, string category, string group, JsonElement node)
    {
        if (!node.TryGetProperty("locations", out var locations)) return 0;
        var count = 0;
        foreach (var location in locations.EnumerateArray())
        {
            var at = location.GetProperty("location");
            var place = (location.GetProperty("name").GetString() ?? "").Replace('|', '/');
            to.SendMessage($"UCLOC1|{category.Replace('|', '/')}|{group.Replace('|', '/')}|{place}|{at[0].GetInt32()}|{at[1].GetInt32()}|{at[2].GetInt32()}");
            count++;
        }
        return count;
    }

    private static void Go(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        var map = Map.Trammel;
        if (args.Length != 3 || !int.TryParse(args.GetString(0), out var x) || !int.TryParse(args.GetString(1), out var y) || !int.TryParse(args.GetString(2), out var z)
            || x < 0 || y < 0 || x >= map.Width || y >= map.Height || z < -128 || z > 127)
        {
            args.Mobile.SendMessage("Usage: [PreviewGo x y z (a Trammel location).");
            return;
        }
        var from = args.Mobile;
        from.Combatant = null;
        from.Warmode = false;
        from.MoveToWorld(new Point3D(x, y, z), map);
        from.SendMessage($"UCGO1|{x}|{y}|{z}");
    }

    private static void Die(CommandEventArgs args)
    {
        if (!Allowed(args) || !args.Mobile.Alive) return;
        args.Mobile.Kill();
    }

    private static void Resurrect(CommandEventArgs args)
    {
        if (!Allowed(args) || args.Mobile.Alive) return;
        args.Mobile.Resurrect();
    }
}
