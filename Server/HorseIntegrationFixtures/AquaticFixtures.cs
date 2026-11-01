// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Called only from the guarded disposable creature command. No terrain,
// collision flags, movement rules or production spawn definitions are changed.
internal static class AquaticFixtures
{
    private static Point3D? _water;

    internal static bool IsWater(Map map, int x, int y, int z) =>
        map.CanSpawnMobile(x, y, z, z, true, true, out var found) && found == z &&
        !map.CanSpawnMobile(x, y, z, z, false, false, out _) && IsWetSurface(map, x, y, z);

    internal static bool IsWetSurface(Map map, int x, int y, int z)
    {
        // Spawn checks include current occupants, so they cease to be a
        // surface probe once the tested creature is standing in this cell.
        var land = map.Tiles.GetLandTile(x, y);
        if ((TileData.LandTable[land.ID & TileData.MaxLandValue].Flags & TileFlag.Wet) != 0 && map.GetAverageZ(x, y) == z)
        {
            return true;
        }
        foreach (var tile in map.Tiles.GetStaticAndMultiTiles(x, y))
        {
            var data = TileData.ItemTable[tile.ID & TileData.MaxItemValue];
            if (data.Wet && tile.Z + data.CalcHeight == z)
            {
                return true;
            }
        }
        return false;
    }

    private static void PlaceClients(Mobile owner, Point3D point)
    {
        var participants = new List<Mobile>();
        foreach (var client in owner.Map.GetClientsInRange(owner.Location))
        {
            if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
            {
                participants.Add(client.Mobile);
            }
        }
        participants.Sort((a, b) => a.Serial.Value.CompareTo(b.Serial.Value));
        for (var i = 0; i < participants.Count; i++)
        {
            participants[i].MoveToWorld(new Point3D(point.X + i * 2, point.Y, point.Z), owner.Map);
        }
    }

    internal static bool Prepare(Mobile owner, bool waterOnly)
    {
        if (!waterOnly)
        {
            if (!EquineFixtures.PrepareBovineArena(owner))
            {
                return false;
            }
            // A mixed batch may return from the sea after the land arena was
            // cached. Explicitly restore that setup rather than reusing water.
            if (EquineFixtures.BovineArena is { } land)
            {
                PlaceClients(owner, land);
            }
            return true;
        }
        var map = owner.Map;
        if (_water == null)
        {
            for (var x = 1600; x <= 2000 && _water == null; x += 16)
            {
                for (var y = 1700; y <= 2100 && _water == null; y += 16)
                {
                    if (!map.CanSpawnMobile(x, y, -30, 20, true, true, out var z))
                    {
                        continue;
                    }
                    var clear = true;
                    for (var dx = -5; dx <= 5 && clear; dx++)
                    {
                        for (var dy = -5; dy <= 5 && clear; dy++)
                        {
                            clear = IsWater(map, x + dx, y + dy, z);
                        }
                    }
                    if (clear)
                    {
                        _water = new Point3D(x, y, z);
                    }
                }
            }
        }
        if (_water is not { } point)
        {
            return false;
        }
        PlaceClients(owner, point);
        return true;
    }
}
