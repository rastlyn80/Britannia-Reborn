// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using System.Text.Json;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;

namespace UltimaClone.PreviewTools;

// Bounded local setup only. The native vendor owns stock, prices, payment and AI.
public static class PreviewCommerce
{
    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.previewTools", false))
        {
            return;
        }
        CommandSystem.Register("PreviewShop", AccessLevel.Player, Setup);
        CommandSystem.Register("PreviewShopVisit", AccessLevel.Player, Visit);
        CommandSystem.Register("PreviewInn", AccessLevel.Player, args => SetupVendor(args,true));
        CommandSystem.Register("PreviewInnVisit", AccessLevel.Player, args => VisitVendor(args,true));
        CommandSystem.Register("PreviewCommerceAudit", AccessLevel.Player, Audit);
    }
    private static bool Allowed(CommandEventArgs args) => args.Mobile.NetState is { } state && IPAddress.IsLoopback(state.Address);
    private static Rectangle2D Bounds()
    {
        using var plan = JsonDocument.Parse(File.ReadAllText(Path.Combine(Core.BaseDirectory,"Data/UltimaClonePreview/population.local.json")));
        var b = plan.RootElement.GetProperty("bounds");
        var width = b.GetProperty("width").GetInt32();
        var height = b.GetProperty("height").GetInt32();
        if (width is <= 0 or > 128 || height is <= 0 or > 128)
        {
            throw new InvalidOperationException("Expected bounded preview crop.");
        }
        return new Rectangle2D(b.GetProperty("x").GetInt32(),b.GetProperty("y").GetInt32(),width,height);
    }
    private static BaseVendor? Find(bool inn = false)
    {
        foreach (var mobile in Map.Trammel.GetMobilesInBounds<BaseVendor>(Bounds()))
        {
            if (inn ? mobile is InnKeeper : mobile is TavernKeeper)
            {
                return mobile;
            }
        }
        return null;
    }
    private static void Setup(CommandEventArgs args) => SetupVendor(args,false);
    private static void SetupVendor(CommandEventArgs args,bool inn)
    {
        if (!Allowed(args))
        {
            return;
        }
        var vendor = Find(inn);
        if (vendor == null)
        {
            using var source = JsonDocument.Parse(File.ReadAllText(Path.Combine(Core.BaseDirectory,"Data/Spawns/shared/trammel/Vendors.json")));
            var bounds = Bounds();
            foreach (var record in source.RootElement.EnumerateArray())
            {
                var at = record.GetProperty("location");
                var point = new Point3D(at[0].GetInt32(),at[1].GetInt32(),at[2].GetInt32());
                if (!bounds.Contains(point.X,point.Y))
                {
                    continue;
                }
                foreach (var entry in record.GetProperty("entries").EnumerateArray())
                {
                    if (entry.GetProperty("name").GetString() != (inn ? "InnKeeper" : "TavernKeeper"))
                    {
                        continue;
                    }
                    if (!Map.Trammel.CanSpawnMobile(point.X,point.Y,point.Z))
                    {
                        args.Mobile.SendMessage("Native vendor source position is blocked; no substitute position was invented.");
                        return;
                    }
                    vendor = inn ? new InnKeeper() : new TavernKeeper();
                    vendor.Home = point;
                    vendor.RangeHome = record.GetProperty("walkingRange").GetInt32();
                    vendor.MoveToWorld(point,Map.Trammel);
                    break;
                }
                if (vendor != null)
                {
                    break;
                }
            }
        }
        if (vendor == null)
        {
            args.Mobile.SendMessage("No native tavern vendor spawn exists in this crop.");
            return;
        }
        var prefix = inn ? "UCINN1" : "UCSHOP1";
        args.Mobile.SendMessage($"{prefix}|{vendor.Serial.Value}|{vendor.X}|{vendor.Y}|{vendor.Z}");
    }
    private static void Visit(CommandEventArgs args) => VisitVendor(args,false);
    private static void VisitVendor(CommandEventArgs args,bool inn)
    {
        if (!Allowed(args))
        {
            return;
        }
        var vendor = Find(inn);
        if (vendor == null)
        {
            return;
        }
        var bounds = Bounds();
        for (var radius = 1; radius <= 2; radius++)
        {
            for (var dx = -radius; dx <= radius; dx++)
            {
                for (var dy = -radius; dy <= radius; dy++)
                {
                    var x = vendor.X+dx;
                    var y = vendor.Y+dy;
                    if (bounds.Contains(x,y) && Map.Trammel.CanSpawnMobile(x,y,vendor.Z))
                    {
                        args.Mobile.MoveToWorld(new Point3D(x,y,vendor.Z),Map.Trammel);
                        var prefix = inn ? "UCINNVISIT1" : "UCSHOPVISIT1";
                        args.Mobile.SendMessage($"{prefix}|{vendor.Serial.Value}");
                        return;
                    }
                }
            }
        }
        args.Mobile.SendMessage("No safe native shop approach.");
    }
    private static void Audit(CommandEventArgs args)
    {
        if (!Allowed(args))
        {
            return;
        }
        var items = new List<object>();
        void Add(Item item,uint parent)
        {
            if (items.Count >= 4000)
            {
                return;
            }
            items.Add(new { serial=item.Serial.Value,id=item.ItemID,amount=item.Amount,layer=(int)item.Layer,parent,movable=item.Movable,type=item.GetType().Name });
            foreach (var child in item.Items)
            {
                Add(child,item.Serial.Value);
            }
        }
        foreach (var item in args.Mobile.Items)
        {
            Add(item,args.Mobile.Serial.Value);
        }
        var vendor = Find();
        File.WriteAllText(Path.Combine(Core.BaseDirectory,"Data/UltimaClonePreview/commerce.local.json"),JsonSerializer.Serialize(new { actor=args.Mobile.Serial.Value,gold=args.Mobile.TotalGold,backpack=args.Mobile.Backpack?.Serial.Value,items,vendor=vendor == null ? null : new { serial=vendor.Serial.Value,name=vendor.Name,x=vendor.X,y=vendor.Y,z=vendor.Z } }));
        args.Mobile.SendMessage("UCCOMMERCEAUDIT1");
    }
}
