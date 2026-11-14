// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.Spawners;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class HolyCityArisen : Item
{
    private static readonly Point3D _clockTile = new(997, 3869, -42);

    [SerializableField(0)]
    private List<Spawner> _spawners = [];

    private Timer? _timer;

    [Constructible]
    public HolyCityArisen() : base(1)
    {
        Visible = false;
        Movable = false;
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceHolyCityArisen", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var mobile = args.Mobile;
        var map = Map.TerMur;
        if (mobile.Map != map || !mobile.Region.IsPartOf("Holy City") || !mobile.InRange(_clockTile, 12))
        {
            mobile.SendMessage("Stand near the Tomb of Kings end of Holy City.");
            return;
        }

        foreach (var controller in map.GetItemsInRange<HolyCityArisen>(_clockTile, 0))
        {
            mobile.SendMessage("The Holy City night spawns are already in place.");
            return;
        }

        var arisen = new HolyCityArisen();
        arisen.MoveToWorld(_clockTile, map);
        arisen.PlaceSpawners();
        arisen.StartClock();
        mobile.SendMessage("The Holy City night spawns are in place.");
    }

    private void PlaceSpawners()
    {
        foreach (var street in new[] { 3862, 3892, 3917, 3951 })
        {
            PlaceSpawner(new Point3D(996, street, -42), nameof(EffeteUndeadGargoyle), 5, 15, 20, 15, 30);
            PlaceSpawner(new Point3D(996, street + 1, -42), nameof(EffetePutridGargoyle), 5, 15, 20, 30, 60);
        }

        PlaceSpawner(new Point3D(996, 3864, -42), nameof(GargoyleShade), 2, 10, 15, 60, 90);
        PlaceSpawner(new Point3D(997, 3951, -42), nameof(GargoyleShade), 2, 10, 15, 60, 90);
        PlaceSpawner(new Point3D(997, 3951, -42), nameof(PutridUndeadGuardian), 1, 5, 10, 300, 600);
    }

    private void PlaceSpawner(Point3D location, string creature, int count, int spawnRange, int walkingRange,
        int minSeconds, int maxSeconds)
    {
        var spawner = new Spawner(count, TimeSpan.FromSeconds(minSeconds), TimeSpan.FromSeconds(maxSeconds),
            spawnedNames: creature)
        {
            HomeRange = spawnRange,
            WalkingRange = walkingRange
        };
        spawner.MoveToWorld(location, Map.TerMur);
        spawner.Stop();
        _spawners.Add(spawner);
    }

    [AfterDeserialization]
    private void StartClock()
    {
        _timer?.Stop();
        _timer = Timer.DelayCall(TimeSpan.Zero, TimeSpan.FromSeconds(5), CheckClock);
    }

    private void CheckClock()
    {
        Clock.GetTime(Map.TerMur, _clockTile.X, _clockTile.Y, out var hour, out int _);
        Reconcile(hour);
    }

    private void Reconcile(int hour)
    {
        var night = hour is >= 0 and < 4;
        foreach (var spawner in _spawners)
        {
            if (spawner == null || spawner.Deleted)
            {
                continue;
            }

            if (night && !spawner.Running)
            {
                spawner.Start();
                spawner.Respawn();
            }
            else if (!night && (spawner.Running || spawner.Spawned is { Count: > 0 }))
            {
                spawner.Reset();
            }
        }
    }

    public override void OnDelete()
    {
        _timer?.Stop();
        foreach (var spawner in _spawners)
        {
            spawner?.Delete();
        }
        _spawners.Clear();
        base.OnDelete();
    }
}
