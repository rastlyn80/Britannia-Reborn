// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Json;

namespace UltimaClone.PreviewTools;

// Populates the whole Trammel facet with ModernUO's own world content, the
// way its world generation would, for Trammel only (the client streams all
// of Trammel): decorations, doors, signs, teleporters, public moongates and
// the standard spawners. Owner decision 2026-10-31: extend the world from
// Britain to all of Trammel, client and server.
//
// Every step keeps what is already there, so a repeat creates nothing and the
// Britain preview population is not replaced: decorations go through the
// upstream generator's own duplicate check, doors through the bounded door
// pass, signs, teleporters and moongates are skipped when an identical one
// stands at the spot, and spawners already in place are kept.
// Loopback- and previewTools-only, like the other preview commands.
public static class PreviewTrammel
{
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false)) return;
        CommandSystem.Register("PreviewTrammel", AccessLevel.Player, Populate);
        CommandSystem.Register("PreviewSave", AccessLevel.Player, SaveWorld);
    }

    private static bool Allowed(CommandEventArgs args)
    {
        if (args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address)) return true;
        args.Mobile.SendMessage("Preview tools are available only on the local development connection.");
        return false;
    }

    // A world save on demand, so the server can be stopped without losing work.
    private static void SaveWorld(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        World.Save();
        args.Mobile.SendMessage("UCSAVE1|requested");
    }

    private static void Populate(CommandEventArgs args)
    {
        if (!Allowed(args)) return;
        var from = args.Mobile;
        var map = Map.Trammel;
        from.SendMessage("Populating all of Trammel with the native world content; this takes a while.");
        int decorations = 0, doors = 0, signs = 0, teleporters = 0, gates = 0;
        try
        {
            decorations = Decorations(map);
            doors = PreviewWorld.DoorsIn(0, 0, map.Width, map.Height);
            signs = Signs(map);
            teleporters = Teleporters(map);
            gates = Moongates(map);
            var (files, created, kept, failed, retired) = PreviewSpawns.Build(new Rectangle2D(0, 0, map.Width, map.Height), from);
            from.SendMessage($"UCTRAM1|{decorations}|{doors}|{signs}|{teleporters}|{gates}|{files}|{created}|{kept}|{failed}|{retired}");
        }
        catch (Exception error)
        {
            from.SendMessage($"Trammel population stopped: {error.GetType().Name}: {error.Message}. Nothing was removed; run it again after fixing.");
        }
    }

    // The upstream decoration lists for Trammel (shared Britannia + Trammel);
    // the generator skips items already present.
    private static int Decorations(Map map)
    {
        var before = World.Items.Count;
        Decorate.Generate("Data/Decoration/Britannia", map);
        Decorate.Generate("Data/Decoration/Trammel", map);
        return World.Items.Count - before;
    }

    // signs.cfg entries for Britannia (both facets) and Trammel.
    private static int Signs(Map map)
    {
        var cfg = Path.Combine(Core.BaseDirectory, "Data/signs.cfg");
        if (!File.Exists(cfg)) return 0;
        var count = 0;
        foreach (var line in File.ReadLines(cfg))
        {
            var split = line.Split(' ');
            if (split.Length < 6) continue;
            var facet = Utility.ToInt32(split[0]);
            if (facet != 0 && facet != 2) continue;
            var id = Utility.ToInt32(split[1]);
            var location = new Point3D(Utility.ToInt32(split[2]), Utility.ToInt32(split[3]), Utility.ToInt32(split[4]));
            var text = line[(split[0].Length + 1 + split[1].Length + 1 + split[2].Length + 1 + split[3].Length + 1 + split[4].Length + 1)..];
            var present = false;
            foreach (var item in map.GetItemsAt(location))
            {
                if (item is Sign && item.Z == location.Z && item.ItemID == id) present = true;
            }
            if (present) continue;
            SignParser.Add_Static(id, location, map, text);
            count++;
        }
        return count;
    }

    // teleporters.json entries whose ends are on Trammel.
    private static int Teleporters(Map map)
    {
        var path = Path.Combine(Core.BaseDirectory, "Data/teleporters.json");
        if (!File.Exists(path)) return 0;
        var count = 0;
        foreach (var definition in JsonConfig.Deserialize<List<TeleporterDefinition>>(path) ?? [])
        {
            if (definition.Source.Map == map && Place(definition.Source, definition.Destination)) count++;
            if (definition.Back && definition.Destination.Map == map && Place(definition.Destination, definition.Source)) count++;
        }
        return count;
    }

    private static bool Place(WorldLocation at, WorldLocation to)
    {
        foreach (var item in at.Map.GetItemsAt(at.Location))
        {
            if (item is Teleporter && Math.Abs(item.Z - at.Location.Z) <= 12) return false;
        }
        new Teleporter(to.Location, to.Map).MoveToWorld(at.Location, at.Map);
        return true;
    }

    // The public moongates on ModernUO's Trammel list.
    private static int Moongates(Map map)
    {
        var count = 0;
        foreach (var entry in PMList.Trammel.Entries)
        {
            var present = false;
            foreach (var item in map.GetItemsAt(entry.Location))
            {
                if (item is PublicMoongate) present = true;
            }
            if (present) continue;
            new PublicMoongate().MoveToWorld(entry.Location, map);
            count++;
        }
        return count;
    }
}
