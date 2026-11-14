// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Commands;
using Server.Engines.Spawners;
using Server.Items;
using Server.Mobiles;
using Server.Regions;

namespace Server;

public static class CitadelEncounterPlacement
{
    private static readonly Point3D MasterThiefHome = new(142, 1921, 0);
    private static readonly Point2D EntranceVillage = new(1344, 769);

    public static void Initialize()
    {
        CommandSystem.Register("PlaceCitadelEncounter", AccessLevel.Administrator, Place);
        CommandSystem.Register("PlaceCitadelEntrance", AccessLevel.Administrator, PlaceEntrance);
        CommandSystem.Register("PlaceSarakki", AccessLevel.Administrator, PlaceNotary);
    }

    private static void PlaceEntrance(CommandEventArgs args)
    {
        var actor = args.Mobile;
        if (actor.Map != Map.Tokuno || !actor.InRange(EntranceVillage, 4) ||
            !Map.Tokuno.CanFit(actor.Location, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on a clear tile at the Isamu-Jima fishing hut.");
            return;
        }

        foreach (var entrance in Map.Tokuno.GetItemsInRange<CitadelEntrance>(actor.Location, 10))
        {
            actor.SendMessage($"Citadel entrance already placed at {entrance.Location}.");
            return;
        }

        var crate = new CitadelEntrance();
        crate.MoveToWorld(actor.Location, Map.Tokuno);
        actor.SendMessage($"Citadel entrance placed at {crate.Location}.");
    }

    private static void PlaceNotary(CommandEventArgs args)
    {
        var actor = args.Mobile;
        if (actor.Map != Map.Trammel || !actor.Region.IsPartOf("Britain") ||
            !Map.Trammel.CanFit(actor.Location, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on a clear tile at the castle gate in Trammel Britain.");
            return;
        }

        foreach (var notary in Map.Trammel.GetMobilesInRange<Sarakki>(actor.Location, 80))
        {
            actor.SendMessage($"Sarakki is already at {notary.Location}.");
            return;
        }

        var quester = new Sarakki { CantWalk = true };
        quester.MoveToWorld(actor.Location, Map.Trammel);
        actor.SendMessage($"Sarakki placed at {quester.Location}.");
    }

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        if (actor.Map != Map.Malas || !actor.Region.IsPartOf("The Citadel") ||
            !Map.Malas.CanFit(actor.Location, 16, checkMobiles: false) ||
            !Map.Malas.CanFit(MasterThiefHome, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on a clear tile in the Citadel where the key table should go.");
            return;
        }

        CitadelKeyTable? table = null;
        foreach (var candidate in Map.Malas.GetItemsInRange<CitadelKeyTable>(actor.Location, 140))
        {
            if (Region.Find(candidate.Location, Map.Malas).IsPartOf("The Citadel"))
            {
                table = candidate;
                break;
            }
        }
        if (table == null)
        {
            table = new CitadelKeyTable();
            table.MoveToWorld(actor.Location, Map.Malas);
        }

        Spawner? thiefSpawner = null;
        foreach (var candidate in Map.Malas.GetItemsAt(MasterThiefHome.X, MasterThiefHome.Y))
        {
            if (candidate is Spawner spawner && spawner.Location == MasterThiefHome &&
                spawner.Entries.Any(entry => entry.SpawnedName.Equals(nameof(TigersClawMaster), System.StringComparison.OrdinalIgnoreCase)))
            {
                thiefSpawner = spawner;
                break;
            }
        }
        if (thiefSpawner == null)
        {
            thiefSpawner = new Spawner(nameof(TigersClawMaster)) { HomeRange = 5, WalkingRange = 5 };
            thiefSpawner.MoveToWorld(MasterThiefHome, Map.Malas);
            thiefSpawner.Start();
        }

        actor.SendMessage($"Citadel table at {table.Location}. Master Thief spawner at {thiefSpawner.Location}.");
    }
}
