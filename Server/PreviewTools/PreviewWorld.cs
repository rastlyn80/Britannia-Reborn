// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.Json;
using Server;
using Server.Commands;
using Server.Items;

namespace UltimaClone.PreviewTools;

// Only the bounded local plan is accepted; native item classes own all gameplay.
public static class PreviewWorld
{
    private static readonly JsonSerializerOptions _json = new() { PropertyNameCaseInsensitive = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true };
    private static string Folder => Path.Combine(Core.BaseDirectory, "Data", "UltimaClonePreview");
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false))
        {
            return;
        }
        CommandSystem.Register("PreviewPopulate", AccessLevel.Player, Populate);
        CommandSystem.Register("PreviewAudit", AccessLevel.Player, Audit);
        CommandSystem.Register("PreviewVisit", AccessLevel.Player, Visit);
    }
    private static bool Allowed(CommandEventArgs args)
    {
        return args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address);
    }
    private static Plan ReadPlan()
    {
        var path = Path.Combine(Folder, "population.local.json");
        if (new FileInfo(path).Length > 4_000_000)
        {
            throw new InvalidOperationException("Population plan too large.");
        }
        var plan = JsonSerializer.Deserialize<Plan>(File.ReadAllText(path), _json) ?? throw new InvalidOperationException("Missing plan.");
        if (plan.Schema != 1 || plan.Facet != 1 || plan.Bounds.Width is <= 0 or > 128 || plan.Bounds.Height is <= 0 or > 128 || plan.Placements.Length + plan.Signs.Length > 20000)
        {
            throw new InvalidOperationException("Expected a bounded Trammel plan.");
        }
        if (plan.Bounds.X < 0 || plan.Bounds.Y < 0 || plan.Bounds.X + plan.Bounds.Width > Map.Trammel.Width || plan.Bounds.Y + plan.Bounds.Height > Map.Trammel.Height)
        {
            throw new InvalidOperationException("Plan exceeds map bounds.");
        }
        foreach (var entry in plan.Placements)
        {
            if (!plan.Bounds.Contains(entry.X, entry.Y) || entry.Header.Contains('\n') || entry.Header.Contains('\r') || !string.IsNullOrWhiteSpace(entry.Extra))
            {
                throw new InvalidOperationException("Out-of-bounds or unsupported placement metadata.");
            }
        }
        foreach (var sign in plan.Signs)
        {
            if (!plan.Bounds.Contains(sign.X, sign.Y))
            {
                throw new InvalidOperationException("Out-of-bounds sign.");
            }
        }
        return plan;
    }
    private static Item? Existing(int x, int y, int z, int id)
    {
        foreach (var item in Map.Trammel.GetItemsAt(x, y))
        {
            if (item.Z == z && item.ItemID == id)
            {
                return item;
            }
        }
        return null;
    }
    private static void Populate(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        try
        {
            var plan = ReadPlan();
            Export(plan, "audit-before.local.json");
            var decorations = 0;
            var signs = 0;
            foreach (var entry in plan.Placements)
            {
                // Unlike the global Decorate command, never delete/replace an existing item.
                if (Existing(entry.X, entry.Y, entry.Z, entry.Id) != null)
                {
                    continue;
                }
                using var memory = new MemoryStream(Encoding.UTF8.GetBytes(entry.Header + "\n\n"));
                using var reader = new StreamReader(memory);
                var item = DecorationList.Read(reader)?.Construct() ?? throw new InvalidOperationException("Native decoration constructor returned null.");
                item.MoveToWorld(new Point3D(entry.X, entry.Y, entry.Z), Map.Trammel);
                decorations++;
            }
            foreach (var entry in plan.Signs)
            {
                if (Existing(entry.X, entry.Y, entry.Z, entry.Id) != null)
                {
                    continue;
                }
                Item item = entry.Text.StartsWith('#') ? new LocalizedSign(entry.Id, int.Parse(entry.Text.AsSpan(1))) : new Sign(entry.Id) { Name = entry.Text };
                item.MoveToWorld(new Point3D(entry.X, entry.Y, entry.Z), Map.Trammel);
                signs++;
            }
            var doors = Doors(plan.Bounds);
            Export(plan, "audit.local.json");
            args.Mobile.SendMessage($"UCPOP1|{decorations}|{doors}|{signs}");
        }
        catch (Exception error)
        {
            args.Mobile.SendMessage($"Population stopped: {error.GetType().Name}: {error.Message}. Existing items were not removed. Audit before retrying.");
        }
    }
    private static int Doors(Bounds bounds)
    {
        // The pinned generator exposes frame matching/AddDoor, but its facet selector is private.
        var field = typeof(DoorGenerator).GetField("m_Map", BindingFlags.NonPublic | BindingFlags.Static) ?? throw new InvalidOperationException("Upstream door generator layout changed.");
        var previous = field.GetValue(null);
        var count = 0;
        try
        {
            field.SetValue(null, Map.Trammel);
            for (var x = bounds.X; x < bounds.X + bounds.Width; x++)
            {
                for (var y = bounds.Y; y < bounds.Y + bounds.Height; y++)
                {
                    foreach (var tile in Map.Trammel.Tiles.GetStaticTiles(x, y))
                    {
                        if (DoorGenerator.IsWestFrame(tile.ID))
                        {
                            if (DoorGenerator.IsEastFrame(x + 2, y, tile.Z, out var z))
                            {
                                Door(x + 1, y, tile.Z, z, DoorFacing.WestCW, bounds, ref count);
                            }
                            else if (DoorGenerator.IsEastFrame(x + 3, y, tile.Z, out z))
                            {
                                Pair(x + 1, y, x + 2, y, tile.Z, z, DoorFacing.WestCW, DoorFacing.EastCCW, bounds, ref count);
                            }
                        }
                        else if (DoorGenerator.IsNorthFrame(tile.ID))
                        {
                            if (DoorGenerator.IsSouthFrame(x, y + 2, tile.Z, out var z))
                            {
                                Door(x, y + 1, tile.Z, z, DoorFacing.SouthCW, bounds, ref count);
                            }
                            else if (DoorGenerator.IsSouthFrame(x, y + 3, tile.Z, out z))
                            {
                                Pair(x, y + 1, x, y + 2, tile.Z, z, DoorFacing.NorthCCW, DoorFacing.SouthCW, bounds, ref count);
                            }
                        }
                    }
                }
            }
        }
        finally
        {
            field.SetValue(null, previous);
        }
        return count;
    }
    private static BaseDoor? Door(int x, int y, int z, int otherZ, DoorFacing facing, Bounds bounds, ref int count)
    {
        if (!bounds.Contains(x, y))
        {
            return null;
        }
        foreach (var item in Map.Trammel.GetItemsInBounds<BaseDoor>(new Rectangle2D(Math.Max(0, bounds.X - 1), Math.Max(0, bounds.Y - 1), bounds.Width + 2, bounds.Height + 2)))
        {
            var closed = item.Open ? new Point3D(item.X - item.Offset.X, item.Y - item.Offset.Y, item.Z - item.Offset.Z) : item.Location;
            if (closed.X == x && closed.Y == y && closed.Z == Math.Min(z, otherZ))
            {
                return item;
            }
        }
        var door = DoorGenerator.AddDoor(x, y, z, otherZ, facing);
        if (door != null)
        {
            count++;
        }
        return door;
    }
    private static void Pair(int x, int y, int bx, int by, int z, int otherZ, DoorFacing a, DoorFacing b, Bounds bounds, ref int count)
    {
        if (!bounds.Contains(x, y) || !bounds.Contains(bx, by))
        {
            return;
        }
        var before = count;
        var first = Door(x, y, z, otherZ, a, bounds, ref count);
        var firstCreated = count > before;
        var middle = count;
        var second = Door(bx, by, z, otherZ, b, bounds, ref count);
        if (first == null || second == null)
        {
            if (firstCreated)
            {
                first?.Delete();
                count--;
            }
            if (count > middle)
            {
                second?.Delete();
                count--;
            }
            return;
        }
        if (first != null && second != null && first.Link == null && second.Link == null)
        {
            first.Link = second;
            second.Link = first;
        }
    }
    private static string Family(Item item)
    {
        var type = item.GetType().Name;
        return item switch
        {
            BaseDoor => "door",
            Sign => "sign",
            _ when type.Contains("Armoire") => "wardrobe",
            _ when type.Contains("Drawer") => "drawers",
            _ when type.Contains("Bookcase") => "bookcase",
            _ when type.Contains("Barrel") => "barrel",
            _ when type.Contains("Crate") => "crate",
            Container => "chest",
            _ when type.Contains("LampPost") || type.Contains("Candelabra") || type.Contains("Candle") => "lamp",
            _ when type.Contains("Potted") => "plant",
            _ when type.Contains("Chair") || type.Contains("Stool") => "chair",
            _ when type.Contains("Bulletin") => "noticeboard",
            _ => "decoration"
        };
    }
    private static void Export(Plan plan, string file)
    {
        var items = new List<object>();
        var definitions = new Dictionary<string, object>();
        void Definition(Item item)
        {
            var family = Family(item);
            object Describe(bool open) => new { family, type = item.GetType().Name, display_name = item.ItemData.Name, label = item.LabelNumber, container = item is Container, height = item.ItemData.Height, flags = (ulong)item.ItemData.Flags, is_open = open, closed_id = item is BaseDoor d ? d.ClosedId : 0, opened_id = item is BaseDoor e ? e.OpenedId : 0, facing = item is BaseDoor f ? (f.ClosedId - 0x6A5) / 2 : 0, offset = item is BaseDoor g ? new[] { g.Offset.X, g.Offset.Y, g.Offset.Z } : new[] { 0, 0, 0 } };
            definitions[item.ItemID.ToString()] = Describe(item is BaseDoor { Open: true });
            if (item is BaseDoor door)
            {
                definitions[door.ClosedId.ToString()] = Describe(false);
                definitions[door.OpenedId.ToString()] = Describe(true);
            }
            if (item is Container container)
            {
                foreach (var child in container.Items)
                {
                    Definition(child);
                }
            }
        }
        foreach (var item in Map.Trammel.GetItemsInBounds<Item>(plan.Bounds.Rectangle))
        {
            if (item.Parent != null)
            {
                continue;
            }
            Definition(item);
            items.Add(new { serial = item.Serial.Value, id = item.ItemID, type = item.GetType().Name, family = Family(item), x = item.X, y = item.Y, z = item.Z, name = item.Name, label = item.LabelNumber, contents = item is Container c ? c.Items.Count : -1, open = item is BaseDoor { Open: true }, linked = item is BaseDoor d ? d.Link?.Serial.Value : null });
        }
        Directory.CreateDirectory(Folder);
        File.WriteAllText(Path.Combine(Folder, file), JsonSerializer.Serialize(new { schema = 1, bounds = plan.Bounds, items, definitions }, _json));
    }
    private static void Audit(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        try
        {
            Export(ReadPlan(), "audit.local.json");
            args.Mobile.SendMessage("UC AUDIT READY");
        }
        catch (Exception error)
        {
            args.Mobile.SendMessage($"Audit failed: {error.Message}");
        }
    }
    private static void Visit(CommandEventArgs args)
    {
        if (!Allowed(args) || args.Length != 1 || !uint.TryParse(args.GetString(0), out var serial))
        {
            return;
        }
        var plan = ReadPlan();
        var item = World.FindItem((Serial)serial);
        if (item == null || item.Map != Map.Trammel || item.Parent != null || !plan.Bounds.Contains(item.X, item.Y))
        {
            return;
        }
        for (var radius = 1; radius <= 2; radius++)
        {
            for (var dx = -radius; dx <= radius; dx++)
            {
                for (var dy = -radius; dy <= radius; dy++)
                {
                    var x = item.X + dx;
                    var y = item.Y + dy;
                    if (!plan.Bounds.Contains(x, y))
                    {
                        continue;
                    }
                    // Tabletop items sit above the walkable floor. Search only
                    // within native use height, retaining CanSpawnMobile checks.
                    for (var drop = 0; drop <= 16; drop++)
                    {
                        var z = item.Z - drop;
                        if (Map.Trammel.CanSpawnMobile(x, y, z))
                        {
                            args.Mobile.MoveToWorld(new Point3D(x, y, z), Map.Trammel);
                            args.Mobile.SendMessage($"UCVISIT1|{serial}");
                            return;
                        }
                    }
                }
            }
        }
        args.Mobile.SendMessage("No safe stand point near that preview item.");
    }
    private sealed record Bounds(int X, int Y, int Width, int Height)
    {
        public Rectangle2D Rectangle => new(X, Y, Width, Height);
        public bool Contains(int x, int y) => x >= X && y >= Y && x < X + Width && y < Y + Height;
    }
    private sealed record Placement(string Header, int Id, int X, int Y, int Z, string Extra);
    private sealed record SignEntry(int Id, int X, int Y, int Z, string Text);
    private sealed record Plan(int Schema, int Facet, Bounds Bounds, Placement[] Placements, SignEntry[] Signs);
}
