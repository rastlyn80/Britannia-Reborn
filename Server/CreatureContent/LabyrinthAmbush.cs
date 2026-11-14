// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.Spawners;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class LabyrinthAmbush : ProximitySpawner
{
    private static readonly Guid _siteId = new("aaca3ab0-5ea8-4af5-ac5f-c037d41b00fa");
    private static readonly Point3D _site = new(347, 1888, 5);

    [Constructible(AccessLevel.Developer)]
    public LabyrinthAmbush() : base(4, TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(10),
        triggerRange: 4, spawnedNames: [nameof(Flurry), nameof(Mistral), nameof(Tempest), nameof(Grim),
            nameof(AirElemental), nameof(Drake)])
    {
        HomeRange = 6;
        WalkingRange = 20;
    }

    public override string DefaultName => "Labyrinth ambush";

    public static void Initialize() =>
        CommandSystem.Register("PlaceLabyrinthAmbush", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        if (actor.Map != Map.Malas || !actor.InRange(_site, 12))
        {
            actor.SendMessage("Stand near the Labyrinth ambush site on Malas.");
            return;
        }

        BaseSpawner? original = null;
        foreach (var spawner in Map.Malas.GetItemsAt<BaseSpawner>(_site))
        {
            if (spawner.Guid != _siteId)
            {
                continue;
            }

            if (spawner is LabyrinthAmbush)
            {
                actor.SendMessage("The Labyrinth ambush is already in place.");
                return;
            }

            original = spawner;
        }

        if (original == null)
        {
            actor.SendMessage("Import the Labyrinth spawners before placing the ambush.");
            return;
        }

        var ambush = new LabyrinthAmbush { Guid = _siteId };
        ambush.MoveToWorld(_site, Map.Malas);
        ambush.Start();
        ambush.DoTimer(TimeSpan.Zero);
        original.Delete();
        actor.SendMessage("The Labyrinth ambush is in place.");
    }

    public override bool ValidTrigger(Mobile mobile) =>
        mobile is PlayerMobile { Alive: true, Hidden: false } && mobile.CanBeDamaged() && base.ValidTrigger(mobile);

    public override void OnMovement(Mobile mobile, Point3D oldLocation)
    {
        if (OnTriggerLevel(mobile.Z) &&
            (!Utility.InRange(oldLocation, Location, TriggerRange) || !OnTriggerLevel(oldLocation.Z)))
        {
            base.OnMovement(mobile, oldLocation);
        }
    }

    private bool OnTriggerLevel(int z) => Math.Abs(z - Z) <= 8;

    public override void Spawn()
    {
        Defrag();
        if (!IsEmpty)
        {
            return;
        }

        var leader = Utility.Random(4);
        if (!Spawn(leader, out _))
        {
            return;
        }

        var escort = leader == 3 ? 5 : 4;
        for (var i = 1; i < Count; ++i)
        {
            Spawn(escort, out _);
        }
    }
}

