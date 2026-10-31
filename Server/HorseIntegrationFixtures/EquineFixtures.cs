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
    private static readonly Dictionary<Mobile, Item> Ankhs = [];
    private static Point3D? BovineArena;

    private static bool PrepareBovineArena(Mobile owner)
    {
        if (BovineArena != null) return true;
        var map = owner.Map;
        for (var x = 1490; x <= 1550; x += 8)
        for (var y = 1690; y <= 1750; y += 8)
        {
            var z = map.GetAverageZ(x, y);
            var clear = true;
            for (var dx = -3; dx <= 3 && clear; dx++)
            for (var dy = -3; dy <= 3 && clear; dy++)
            {
                clear = map.GetAverageZ(x + dx, y + dy) == z && map.CanSpawnMobile(x + dx, y + dy, z);
            }
            if (!clear) continue;
            var participants = new List<Mobile>();
            foreach (var client in map.GetClientsInRange(owner.Location))
            {
                if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true) participants.Add(client.Mobile);
            }
            for (var i = 0; i < participants.Count; i++) participants[i].MoveToWorld(new Point3D(x + i * 2, y, z), map);
            BovineArena = new Point3D(x, y, z);
            return true;
        }
        return false;
    }

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
        if (Ankhs.Remove(owner, out var ankh)) ankh.Delete();
        if (owner is PlayerMobile { EthicPlayer: { } ethicalPlayer })
        {
            ethicalPlayer.Detach();
            ethicalPlayer.Delete();
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
        38 or 40 => new HolySteed(),
        39 or 41 => new UnholySteed(),
        42 => new Cow { Body = 0xD8 },
        43 => new Cow { Body = 0xE7 },
        44 => new Bull { Body = 0xE8 },
        45 => new Bull { Body = 0xE9 },
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
            if (index < 0 || index > 45) return;
            Cleanup(owner);
            if (index >= 42 && !PrepareBovineArena(owner))
            {
                owner.SendMessage("UCEQUINE|arena-blocked");
                return;
            }
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
                if (index is >= 38 and <= 41)
                {
                    var faction = index is 38 or 41 ? Server.Factions.TrueBritannians.Instance : Server.Factions.Minax.Instance;
                    faction.AddMember(owner);
                    Memberships[owner] = faction;
                    var ankh = new AnkhNorth();
                    ankh.MoveToWorld(owner.Location, owner.Map);
                    Ankhs[owner] = ankh;
                }
                else if (index >= 34 && animal is Server.Factions.FactionWarHorse factionHorse)
                {
                    // Disposable-account setup only. The normal OnDoubleClick
                    // still enforces actual faction membership and native rank.
                    var faction = factionHorse.Faction;
                    faction.AddMember(owner);
                    Memberships[owner] = faction;
                    Server.Factions.PlayerState.Find(owner).KillPoints = 100;
                }
                if (!animal.SetControlMaster(owner))
                {
                    animal.Delete();
                    owner.SendMessage("UCEQUINE|control-denied");
                    return;
                }
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
        else if (command == "ethics-owner")
        {
            var player = Server.Ethics.Player.Find(owner);
            if (player != null && Ankhs.Remove(owner, out var ankh)) ankh.Delete();
            owner.SendMessage($"UCEQUINE|owner|{player?.Ethic?.GetType().Name ?? "None"}|{(owner.Mount is BaseMount mount ? mount.ItemID : 0)}|{(player?.Steed?.Serial.Value ?? 0)}|{Server.Ethics.Ethic.Hero?.Players?.Count ?? 0}|{Server.Ethics.Ethic.Evil?.Players?.Count ?? 0}|{Server.Factions.Faction.Find(owner)?.GetType().Name ?? "None"}|{World.WorldState}");
        }
        else if (command == "ethics-link" && Animals.TryGetValue(owner, out var steed))
        {
            if (Server.Ethics.Player.Find(owner) is { } player) player.Steed = steed;
            owner.SendMessage("UCEQUINE|linked");
        }
        else if (command == "ethics-save")
        {
            World.Save();
            owner.SendMessage("UCEQUINE|save-requested");
        }
        else if (command == "ethics-duplicates")
        {
            var hero = Server.Ethics.Ethic.Hero;
            var evil = Server.Ethics.Ethic.Evil;
            var duplicateHero = new Server.Ethics.Hero.HeroEthic();
            var duplicateEvil = new Server.Ethics.Evil.EvilEthic();
            var preserved = hero != null && evil != null && ReferenceEquals(hero, Server.Ethics.Ethic.Hero)
                && ReferenceEquals(evil, Server.Ethics.Ethic.Evil) && duplicateHero.Deleted && duplicateEvil.Deleted;
            owner.SendMessage($"UCEQUINE|duplicates|{(preserved ? 1 : 0)}");
        }
        else if (command == "bovine-step" && Animals.TryGetValue(owner, out var walker))
        {
            for (var direction = 0; direction < 8; direction++)
            {
                var before = walker.Location;
                var facing = (Direction)direction | (args.Length > 1 && args.GetInt32(1) != 0 ? Direction.Running : Direction.North);
                var target = before;
                Server.Movement.Movement.Offset(facing, ref target);
                if (!owner.InRange(target, 2)) continue;
                var moved = false;
                for (var attempt = 0; attempt < 2 && !moved; attempt++) moved = walker.Move(facing) && walker.Location != before;
                if (moved)
                {
                    owner.SendMessage($"UCEQUINE|step|{walker.X}|{walker.Y}|{walker.Z}");
                    return;
                }
            }
            owner.SendMessage("UCEQUINE|step-blocked");
        }
        else if (command == "bovine-tip" && Animals.TryGetValue(owner, out var tipped) && tipped is Cow cow)
        {
            cow.Tip();
            owner.SendMessage("UCEQUINE|tipped");
        }
        else if (command == "bovine-milk" && Animals.TryGetValue(owner, out var milked) && milked is Cow dairy)
        {
            var result = dairy.TryMilk(owner);
            owner.SendMessage($"UCEQUINE|milk|{(result ? 1 : 0)}|{dairy.Milk}");
        }
    }
}
