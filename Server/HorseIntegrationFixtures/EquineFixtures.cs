// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;
using Server.Items;
using Server.Network;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Disposable loopback test world only. Real upstream classes own permissions,
// control slots, mount items and ethereal casting; no production module install.
public static class EquineFixtures
{
    private static readonly Dictionary<Mobile, BaseCreature> Animals = [];
    private static readonly Dictionary<Mobile, EtherealMount> Ethereals = [];
    private static readonly Dictionary<Mobile, Container> Corpses = [];

    [CallPriority(int.MaxValue)]
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false))
        {
            CommandSystem.Register("EquineFixture", AccessLevel.Player, Execute);
        }
    }

    private static void Cleanup(Mobile owner)
    {
        if (Corpses.Remove(owner, out var corpse)) corpse.Delete();
        if (Animals.Remove(owner, out var animal))
        {
            if (animal is BaseMount mount) mount.Rider = null;
            animal.Delete();
        }
        if (Ethereals.Remove(owner, out var ethereal))
        {
            ethereal.Rider = null;
            ethereal.Delete();
        }
    }

    private static BaseCreature Create(int index) => index switch
    {
        0 => new Nightmare { Body = 0x74, ItemID = 0x3EA7 },
        1 => new Nightmare { Body = 0xB2, ItemID = 0x3EA9 },
        2 => new Nightmare { Body = 0xB3, ItemID = 0x3EB7 },
        3 => new SilverSteed(),
        4 => new FireSteed(),
        5 => new Unicorn(),
        6 => new TBWarHorse(),
        7 => new CoMWarHorse(),
        8 => new MinaxWarHorse(),
        9 => new SLWarHorse(),
        10 => new PackHorse(),
        13 => new DesertOstard(),
        14 => new ForestOstard(),
        15 => new FrenziedOstard(),
        17 => new Kirin(),
        18 => new SkeletalMount(),
        19 => new RidableLlama(),
        20 => new PackLlama(),
        _ => throw new ArgumentOutOfRangeException(nameof(index))
    };

    private static void Execute(CommandEventArgs args)
    {
        var owner = args.Mobile;
        if (owner.NetState is not { } state || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true) return;
        var command = args.Length > 0 ? args.GetString(0) : "audit";
        if (command == "cleanup")
        {
            Cleanup(owner);
            owner.SendMessage("UCEQUINE|cleaned");
        }
        else if (command == "prepare" && args.Length > 1)
        {
            var index = args.GetInt32(1);
            if (index < 0 || index > 21) return;
            Cleanup(owner);
            if (index is 11 or 12 or 16 or 21)
            {
                EtherealMount ethereal = index == 11 ? new EtherealHorse() : index == 12 ? new EtherealUnicorn() : index == 21 ? new EtherealLlama() : new EtherealOstard();
                owner.AddToBackpack(ethereal);
                Ethereals[owner] = ethereal;
                owner.SendMessage($"UCEQUINE|prepared|{ethereal.Serial.Value}|0|{ethereal.MountedID}|{ethereal.GetType().Name}");
                return;
            }
            for (var dx = -1; dx <= 1; dx++)
            for (var dy = -1; dy <= 1; dy++)
            {
                if ((dx == 0 && dy == 0) || !owner.Map.CanSpawnMobile(owner.X + dx, owner.Y + dy, owner.Z)) continue;
                var animal = Create(index);
                animal.SetControlMaster(owner);
                animal.ControlOrder = OrderType.Stay;
                animal.MoveToWorld(new Point3D(owner.X + dx, owner.Y + dy, owner.Z), owner.Map);
                Animals[owner] = animal;
                owner.SendMessage($"UCEQUINE|prepared|{animal.Serial.Value}|{animal.Body.BodyID}|{(animal is BaseMount mount ? mount.ItemID : 0)}|{animal.GetType().Name}");
                return;
            }
            owner.SendMessage("UCEQUINE|blocked");
        }
        else if (command == "action" && args.Length > 1 && Animals.TryGetValue(owner, out var subject))
        {
            var action = args.GetInt32(1);
            if (action == 5) subject.Animate(5, 6, 1, true, false, 0);
            else if (action == 4)
            {
                foreach (var client in subject.Map.GetClientsInRange(subject.Location))
                    if (client.Mobile.CanSee(subject)) client.SendNewMobileAnimation(subject.Serial, 4, 0, 0);
            }
            owner.SendMessage($"UCEQUINE|action|{subject.Serial.Value}|{action}");
        }
        else if (command == "kill" && Animals.TryGetValue(owner, out var doomed))
        {
            doomed.Kill();
            if (doomed.Corpse is { } corpse)
            {
                Corpses[owner] = corpse;
                owner.SendMessage($"UCEQUINE|corpse|{corpse.Serial.Value}|{doomed.Body.BodyID}");
            }
        }
        else if (command == "colour" && args.Length > 1)
        {
            var hue = args.GetInt32(1) & 0xFFFF;
            if (Animals.TryGetValue(owner, out var animal)) animal.Hue = hue;
            if (Ethereals.TryGetValue(owner, out var ethereal)) ethereal.Hue = hue;
            owner.SendMessage($"UCEQUINE|colour|{hue}");
        }
        else if (command == "audit")
        {
            owner.SendMessage($"UCEQUINE|audit|{(owner.Mounted ? 1 : 0)}|{owner.Followers}");
        }
    }
}
