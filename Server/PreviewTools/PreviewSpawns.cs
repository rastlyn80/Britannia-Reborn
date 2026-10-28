// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using System.Text.Json;
using Server;
using Server.Collections;
using Server.Commands;
using Server.Engines.Spawners;
using Server.Json;
using Server.Mobiles;

namespace UltimaClone.PreviewTools;

// Bounded upstream spawners for the prepared preview region (the same bounds as
// PreviewPopulate). It reads ModernUO's own Trammel spawn files, selected the
// way the upstream world-generation menu selects them (shared, plus uoml or
// post-uoml by era), keeps only spawners inside the bounds, and builds them with
// the upstream DTO path. Vendors, townsfolk, guards and creatures then come and
// go under their native spawner, AI and respawn timers. A spawner already in
// place (same GUID at its location) is kept, so repeated runs create nothing.
public static class PreviewSpawns
{
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false))
        {
            return;
        }
        CommandSystem.Register("PreviewSpawn", AccessLevel.Player, Spawn);
        CommandSystem.Register("PreviewSpawnAudit", AccessLevel.Player, Audit);
    }

    private static bool Allowed(CommandEventArgs args) => args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address);

    private static Rectangle2D Bounds()
    {
        using var plan = JsonDocument.Parse(File.ReadAllText(Path.Combine(Core.BaseDirectory,"Data/UltimaClonePreview/population.local.json")));
        var b = plan.RootElement.GetProperty("bounds");
        var width = b.GetProperty("width").GetInt32();
        var height = b.GetProperty("height").GetInt32();
        if (width is <= 0 or > PreviewWorld.MaxSide || height is <= 0 or > PreviewWorld.MaxSide)
        {
            throw new InvalidOperationException("Expected bounded preview region.");
        }
        return new Rectangle2D(b.GetProperty("x").GetInt32(),b.GetProperty("y").GetInt32(),width,height);
    }

    private static IEnumerable<FileInfo> Sources()
    {
        var era = Core.SA ? "post-uoml" : "uoml";
        foreach (var folder in new[] { $"Data/Spawns/{era}/trammel", "Data/Spawns/shared/trammel" })
        {
            var directory = new DirectoryInfo(Path.Combine(Core.BaseDirectory,folder));
            if (!directory.Exists)
            {
                continue;
            }
            foreach (var file in directory.GetFiles("*.json").OrderBy(file => file.Name,StringComparer.Ordinal))
            {
                yield return file;
            }
        }
    }

    private static bool Present(SpawnerDto dto)
    {
        foreach (var existing in Map.Trammel.GetItemsAt<BaseSpawner>(dto.Location))
        {
            if (existing.Guid == dto.Guid)
            {
                return true;
            }
        }
        return false;
    }

    // A vendor placed earlier by PreviewShop/PreviewInn stands where its native
    // spawner now spawns one of the same kind; keep only the spawner's.
    private static int RetireStandIns(BaseSpawner spawner)
    {
        var retired = 0;
        var range = Math.Max(spawner.WalkingRange,0)+2;
        using var queue = PooledRefQueue<Mobile>.Create();
        foreach (var mobile in Map.Trammel.GetMobilesInRange<BaseVendor>(spawner.Location,range))
        {
            if (mobile.Spawner != null)
            {
                continue;
            }
            foreach (var entry in spawner.Entries)
            {
                if (string.Equals(entry.SpawnedName,mobile.GetType().Name,StringComparison.OrdinalIgnoreCase))
                {
                    queue.Enqueue(mobile);
                    break;
                }
            }
        }
        while (queue.Count > 0)
        {
            queue.Dequeue().Delete();
            retired++;
        }
        return retired;
    }

    private static void Spawn(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        var bounds = Bounds();
        int files = 0, created = 0, kept = 0, failed = 0, retired = 0;
        foreach (var file in Sources())
        {
            List<SpawnerDto>? dtos;
            try
            {
                dtos = JsonConfig.Deserialize<List<SpawnerDto>>(file.FullName,SpawnerJsonSerializer.Options);
            }
            catch (JsonException)
            {
                args.Mobile.SendMessage($"Skipped unreadable spawn file {file.Name}.");
                failed++;
                continue;
            }
            files++;
            foreach (var dto in dtos ?? [])
            {
                if (dto.Map != Map.Trammel || !bounds.Contains(dto.Location.X,dto.Location.Y))
                {
                    continue;
                }
                if (Present(dto))
                {
                    kept++;
                    continue;
                }
                BaseSpawner spawner;
                try
                {
                    spawner = dto.ToSpawner();
                }
                catch (Exception)
                {
                    failed++;
                    continue;
                }
                try
                {
                    spawner.MoveToWorld(dto.Location,Map.Trammel);
                    retired += RetireStandIns(spawner);
                    spawner.Respawn();
                    created++;
                }
                catch (Exception)
                {
                    spawner.Delete();
                    failed++;
                }
            }
        }
        args.Mobile.SendMessage($"UCSPAWN1|{files}|{created}|{kept}|{failed}|{retired}");
    }

    // Spawners and what they currently hold inside the bounds, by spawned type.
    private static void Audit(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        var bounds = Bounds();
        var spawners = 0;
        var byType = new SortedDictionary<string,int>(StringComparer.Ordinal);
        foreach (var spawner in Map.Trammel.GetItemsInBounds<BaseSpawner>(bounds))
        {
            spawners++;
            foreach (var spawned in spawner.Spawned.Keys)
            {
                var name = spawned.GetType().Name;
                byType[name] = byType.GetValueOrDefault(name)+1;
            }
        }
        var vendors = 0;
        var mobiles = 0;
        foreach (var mobile in Map.Trammel.GetMobilesInBounds<Mobile>(bounds))
        {
            if (mobile.Player)
            {
                continue;
            }
            mobiles++;
            if (mobile is BaseVendor)
            {
                vendors++;
            }
        }
        File.WriteAllText(Path.Combine(Core.BaseDirectory,"Data/UltimaClonePreview/spawns.local.json"),JsonSerializer.Serialize(new { bounds = new { bounds.X,bounds.Y,bounds.Width,bounds.Height },spawners,mobiles,vendors,spawned = byType }));
        args.Mobile.SendMessage($"UCSPAWNAUDIT1|{spawners}|{mobiles}|{vendors}");
    }
}
