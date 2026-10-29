// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;
using Server.Accounting;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Loaded only by the isolated horse test runtime. Never installed into the
// owner's running runtime. Upstream Horse/BaseMount own all riding behaviour.
public static class HorseFixtures
{
    private static readonly Dictionary<Mobile, Horse> Horses = [];
    private static readonly int[] Bodies = [0xC8, 0xE2, 0xE4, 0xCC];
    private static readonly int[] Items = [0x3E9F, 0x3EA0, 0x3EA1, 0x3EA2];

    [CallPriority(int.MaxValue)]
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false))
        {
            CommandSystem.Register("HorseFixture", AccessLevel.Player, Execute);
        }
    }

    [CallPriority(int.MinValue)]
    public static void Initialize()
    {
        // World load must complete before adding accounts. Run before the
        // upstream owner prompt; this account has ordinary Player access.
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false) && Accounts.Count == 0)
        {
            _ = new Account("brhorse-test-bootstrap", Guid.NewGuid().ToString("N"));
        }
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
        if (command == "prepare")
        {
            if (Horses.Remove(owner, out var previous))
            {
                previous.Rider = null;
                previous.Delete();
            }
            var variant = args.Length > 1 ? args.GetInt32(1) : 0;
            if (variant < 0 || variant >= Bodies.Length)
            {
                return;
            }
            for (var dx = -1; dx <= 1; dx++)
            {
                for (var dy = -1; dy <= 1; dy++)
                {
                    if ((dx == 0 && dy == 0) || !owner.Map.CanSpawnMobile(owner.X + dx, owner.Y + dy, owner.Z))
                    {
                        continue;
                    }
                    var horse = new Horse { Body = Bodies[variant], ItemID = Items[variant], Name = "Horse integration fixture" };
                    horse.SetControlMaster(owner);
                    horse.ControlOrder = OrderType.Stay;
                    horse.MoveToWorld(new Point3D(owner.X + dx, owner.Y + dy, owner.Z), owner.Map);
                    Horses[owner] = horse;
                    owner.SendMessage($"UCHORSE|prepared|{horse.Serial.Value}|{horse.Body.BodyID}|{horse.ItemID}");
                    return;
                }
            }
            owner.SendMessage("UCHORSE|blocked");
        }
        else if (command == "colour" && args.Length > 1 && Horses.TryGetValue(owner, out var colouredHorse))
        {
            colouredHorse.Hue = args.GetInt32(1) & 0xFFFF;
            owner.SendMessage($"UCHORSE|colour|{colouredHorse.Hue}");
        }
        else if (command == "action" && owner.Mounted && args.Length > 1)
        {
            var action = args.GetInt32(1);
            if (action >= 23 && action <= 29)
            {
                owner.Animate(action, 6, 1, true, false, 0);
            }
        }
        else if (command == "audit" && Horses.TryGetValue(owner, out var horse))
        {
            owner.SendMessage($"UCHORSE|audit|{horse.Serial.Value}|{horse.Body.BodyID}|{horse.ItemID}|{horse.Rider?.Serial.Value ?? 0}");
        }
        else if (command == "cleanup" && Horses.Remove(owner, out var cleanupHorse))
        {
            cleanupHorse.Rider = null;
            cleanupHorse.Delete();
            owner.SendMessage("UCHORSE|cleaned");
        }
    }
}
