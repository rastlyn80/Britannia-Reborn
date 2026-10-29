// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using System.Collections.Generic;
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;
using Server.Multis;
using Server.Multis.Deeds;

namespace UltimaClone.PreviewTools;

// Development test kit for the client's world systems (houses, boats, maps,
// spellcasting).
// An explicit, owner-approved exception to "no staff powers" (2026-10-29): it
// only exists when ultimaClone.previewTools is enabled, only answers a loopback
// connection, and hands the caller ordinary upstream items, which then go
// through the server's own placement, customisation and decoding rules.
public static class PreviewKit
{
    public const int HouseGold = 200000;

    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false)) return;
        CommandSystem.Register("PreviewKit", AccessLevel.Player, Kit);
    }

    private static void Kit(CommandEventArgs args)
    {
        var mobile = args.Mobile;
        if (mobile.NetState is not { } state || !IPAddress.IsLoopback(state.Address))
        {
            mobile.SendMessage("Preview tools are available only on the local development connection.");
            return;
        }
        var pack = mobile.Backpack;
        if (pack == null) return;
        var what = args.Length > 0 ? args.GetString(0).ToLowerInvariant() : "all";
        if (what is "all" or "house")
        {
            pack.DropItem(new HousePlacementTool());
            pack.DropItem(new SmallBrickHouseDeed());
            Banker.Deposit(mobile, HouseGold);
        }
        if (what is "all" or "boat") pack.DropItem(new SmallBoatDeed());
        if (what is "all" or "map") pack.DropItem(new TreasureMap(1, Map.Trammel));
        if (what is "all" or "magic")
        {
            // A spellbook with the first two circles and reagents loose in the pack.
            pack.DropItem(new Spellbook(0xFFFF));
            foreach (var reagent in new Item[] { new BlackPearl(30), new Bloodmoss(30), new Garlic(30), new Ginseng(30), new MandrakeRoot(30), new Nightshade(30), new SulfurousAsh(30), new SpidersSilk(30) })
            {
                pack.DropItem(reagent);
            }
        }
        if (what == "site") { HouseSite(mobile, args.Length > 1 ? Utility.ToInt32(args.GetString(1)) : 0); return; }
        if (what == "dock") { BoatSite(mobile); return; }
        if (what is not ("all" or "house" or "boat" or "map" or "magic")) { mobile.SendMessage("[PreviewKit all|house|boat|map|magic|site|dock"); return; }
        mobile.SendMessage($"Preview kit ({what}) is in your backpack" + (what is "all" or "house" ? $"; {HouseGold} gold was deposited in your bank." : "."));
    }

    // The prepared client area (docs/BRITANNIA_EXPLORER.md), nearest the start first.
    private static readonly Rectangle2D Area = new(1088, 1408, 704, 512);
    private static readonly Point2D Start = new(1602, 1591);

    private static IEnumerable<Point2D> Candidates(int step)
    {
        var points = new List<Point2D>();
        for (var x = Area.X + 4; x < Area.X + Area.Width - 4; x += step)
        for (var y = Area.Y + 4; y < Area.Y + Area.Height - 4; y += step)
            points.Add(new Point2D(x, y));
        points.Sort((a, b) => Distance(a).CompareTo(Distance(b)));
        return points;
    }

    private static int Distance(Point2D p) => (p.X - Start.X) * (p.X - Start.X) + (p.Y - Start.Y) * (p.Y - Start.Y);

    // Moves the caller beside the nearest spot where the server's own rules
    // accept a small brick house (or the given multi, e.g. 0x13EC for a 7x7
    // custom foundation, same offset); reports UCKIT|house|x|y|z (the tile to target).
    private static void HouseSite(Mobile mobile, int multiID)
    {
        var deed = new SmallBrickHouseDeed();
        try
        {
            foreach (var point in Candidates(5))
            {
                var center = new Point3D(point.X, point.Y, mobile.Map.GetAverageZ(point.X, point.Y));
                if (HousePlacement.Check(mobile, multiID > 0 ? multiID : deed.MultiID, center, out _) != HousePlacementResult.Valid) continue;
                var target = new Point3D(center.X + deed.Offset.X, center.Y + deed.Offset.Y, center.Z + deed.Offset.Z);
                var stand = new Point3D(center.X, center.Y + 7, mobile.Map.GetAverageZ(center.X, center.Y + 7));
                mobile.Combatant = null;
                mobile.MoveToWorld(stand, Map.Trammel);
                mobile.SendMessage($"UCKIT|house|{target.X}|{target.Y}|{target.Z}");
                return;
            }
            mobile.SendMessage("No house site found in the prepared area.");
        }
        finally { deed.Delete(); }
    }

    // Moves the caller to the shore beside the nearest water the server lets a
    // small boat use; reports UCKIT|boat|x|y|z (the water tile to target).
    private static void BoatSite(Mobile mobile)
    {
        var boat = new SmallBoat();
        try
        {
            var map = Map.Trammel;
            foreach (var point in Candidates(4))
            {
                var p = new Point3D(point.X, point.Y, -5);
                if (!BaseBoat.IsValidLocation(p, map) || !boat.CanFit(p, map, boat.ItemID)) continue;
                for (var r = 3; r <= 8; r++)
                for (var dx = -r; dx <= r; dx++)
                for (var dy = -r; dy <= r; dy++)
                {
                    if (Math.Max(Math.Abs(dx), Math.Abs(dy)) != r) continue;
                    var z = map.GetAverageZ(p.X + dx, p.Y + dy);
                    var shore = new Point3D(p.X + dx, p.Y + dy, z);
                    // Low shore with a clear view of the water, as a player standing there needs.
                    if (Math.Abs(z - p.Z) > 10 || !map.CanSpawnMobile(shore)) continue;
                    if (!map.LineOfSight(new Point3D(shore.X, shore.Y, shore.Z + 14), p)) continue;
                    mobile.Combatant = null;
                    mobile.MoveToWorld(shore, map);
                    mobile.SendMessage($"UCKIT|boat|{p.X}|{p.Y}|{p.Z}");
                    return;
                }
            }
            mobile.SendMessage("No boat site found in the prepared area.");
        }
        finally { boat.Delete(); }
    }
}
