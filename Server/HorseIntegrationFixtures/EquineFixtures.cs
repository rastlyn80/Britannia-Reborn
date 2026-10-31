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
    private static readonly Dictionary<Mobile, Server.Factions.Faction> Memberships = [];

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
        if (Memberships.Remove(owner, out var faction)) faction.RemoveMember(owner);
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
        23 => new HolySteed(),
        24 => new UnholySteed(),
        25 => new Server.Factions.FactionWarHorse(),
        26 => new Server.Factions.FactionWarHorse(Server.Factions.TrueBritannians.Instance),
        27 => new Server.Factions.FactionWarHorse(Server.Factions.CouncilOfMages.Instance),
        28 => new Server.Factions.FactionWarHorse(Server.Factions.Minax.Instance),
        29 => new Server.Factions.FactionWarHorse(Server.Factions.Shadowlords.Instance),
        30 => new HellSteed(),
        31 => new GrizzledMare(),
        32 => new RedDeath(),
        33 => new Llama(),
        34 => new Server.Factions.FactionWarHorse(Server.Factions.TrueBritannians.Instance),
        35 => new Server.Factions.FactionWarHorse(Server.Factions.CouncilOfMages.Instance),
        36 => new Server.Factions.FactionWarHorse(Server.Factions.Minax.Instance),
        37 => new Server.Factions.FactionWarHorse(Server.Factions.Shadowlords.Instance),
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
            if (index < 0 || index > 37) return;
            Cleanup(owner);
            if (index is 11 or 12 or 16 or 21 or 22)
            {
                EtherealMount ethereal = index == 11 ? new EtherealHorse() : index == 12 ? new EtherealUnicorn() : index == 21 ? new EtherealLlama() : index == 22 ? new EtherealKirin() : new EtherealOstard();
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
                if (index >= 34 && animal is Server.Factions.FactionWarHorse factionHorse)
                {
                    // Disposable-account setup only. The normal OnDoubleClick
                    // still enforces actual faction membership and native rank.
                    var faction = factionHorse.Faction;
                    faction.AddMember(owner);
                    Memberships[owner] = faction;
                    Server.Factions.PlayerState.Find(owner).KillPoints = 100;
                }
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
            if (action is 3 or 5 or 11) subject.Animate(action, 6, 1, true, false, 0);
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
        else if (command == "ethics-status")
        {
            owner.SendMessage($"UCEQUINE|ethics|{(Server.Ethics.Ethic.Hero == null ? 0 : 1)}|{(Server.Ethics.Ethic.Evil == null ? 0 : 1)}");
        }
    }
}
