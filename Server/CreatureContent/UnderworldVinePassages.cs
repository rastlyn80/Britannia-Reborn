// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;

namespace Server.Items;

public static class UnderworldVinePassages
{
    private readonly record struct Passage(Point3D Threshold, Point3D Approach, Point3D Interior, DoorFacing Facing);

    private static readonly Passage[] _passages =
    [
        new(new(1064, 1195, -42), new(1063, 1195, -42), new(1065, 1195, -42), DoorFacing.SouthCCW),
        new(new(1012, 1049, -32), new(1013, 1049, -32), new(1011, 1049, -32), DoorFacing.NorthCW)
    ];

    public static void Initialize() =>
        CommandSystem.Register("PlaceUnderworldVinePassage", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        foreach (var site in _passages)
        {
            if (actor.Map != map || !actor.InRange(site.Threshold, 4))
            {
                continue;
            }

            foreach (var door in map.GetItemsInRange<UnderworldVineDoor>(site.Threshold, 3))
            {
                if (door.Threshold == site.Threshold)
                {
                    actor.SendMessage("This vine passage is already in place.");
                    return;
                }
            }

            Point3D[] tiles = [site.Approach, site.Threshold, site.Interior];
            if (Array.Exists(tiles, tile => !map.CanFit(tile, 16, checkMobiles: false, requireSurface: false)))
            {
                actor.SendMessage("The map does not have a walkable passage at this location.");
                return;
            }

            foreach (var tile in tiles)
            {
                if (!map.CanFit(tile, 16, checkMobiles: false))
                {
                    new Static(0x0521).MoveToWorld(tile, map);
                }
            }

            var passage = new UnderworldVineDoor(site.Facing, site.Threshold, site.Interior.X);
            passage.MoveToWorld(site.Threshold, map);
            var vines = new AcidVine(passage);
            passage.AttachVines(vines);
            vines.MoveToWorld(site.Threshold, map);
            actor.SendMessage("The magic vines and secret wall are in place.");
            return;
        }

        actor.SendMessage("Stand near one of the Underworld's two secret laboratory passages.");
    }
}

[SerializationGenerator(0)]
public sealed partial class AcidVine : Item
{
    [SerializableField(0)]
    private UnderworldVineDoor? _door;

    [Constructible]
    public AcidVine(UnderworldVineDoor door) : base(0x0CF1)
    {
        _door = door;
        Movable = false;
    }

    public override int LabelNumber => 1111655;
    public override bool ForceShowProperties => ObjectPropertyList.Enabled;

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Map != Map || !from.InRange(this, 4))
        {
            from.SendLocalizedMessage(1019045);
            return;
        }

        from.SendLocalizedMessage(from.InRange(this, 1) ? 1111658 : 1111665);
    }

    public bool TryBurn(Mobile from)
    {
        if (Deleted || !Visible || !from.Alive || from.Map != Map || !from.InRange(this, 1) || Math.Abs(from.Z - Z) > 12 ||
            !from.CanSee(this) || !from.InLOS(this) || _door is not { Deleted: false } door)
        {
            return false;
        }

        if (!door.BurnVines())
        {
            return false;
        }

        from.SendLocalizedMessage(1111662);
        return true;
    }

    public override void OnDelete()
    {
        _door = null;
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class UnderworldVineDoor : SecretDungeonDoor
{
    private static readonly TimeSpan _vineRecovery = TimeSpan.FromMinutes(1);
    private Timer? _timer;

    [SerializableField(0)]
    private Point3D _threshold;

    [SerializableField(1)]
    private int _interiorX;

    [SerializableField(2)]
    private AcidVine? _vines;

    [SerializableField(3)]
    private DateTime _regrowsAt;

    [Constructible]
    public UnderworldVineDoor(DoorFacing facing, Point3D threshold, int interiorX) : base(facing)
    {
        _threshold = threshold;
        _interiorX = interiorX;
    }

    public bool IsVineBurned => _regrowsAt > Core.Now;

    public void AttachVines(AcidVine vines) => _vines = vines;

    public bool BurnVines()
    {
        if (_vines is not { Deleted: false, Visible: true } || Open || IsVineBurned)
        {
            return false;
        }

        _regrowsAt = Core.Now + _vineRecovery;
        UpdateVines();
        return true;
    }

    public override void Use(Mobile from)
    {
        if (Deleted || from.Map != Map || !from.Alive || !from.InRange(_threshold, 1) ||
            Math.Abs(from.Z - _threshold.Z) > 12 || !from.InLOS(this))
        {
            return;
        }

        var isInside = _interiorX > _threshold.X ? from.X > _threshold.X : from.X < _threshold.X;
        if (!Open && !IsVineBurned && !isInside)
        {
            from.SendLocalizedMessage(1111658);
            return;
        }

        base.Use(from);
        if (Open && isInside && !IsVineBurned)
        {
            from.SendLocalizedMessage(1111664);
        }

        UpdateVines();
    }

    private void UpdateVines()
    {
        _timer?.Stop();
        _timer = null;
        if (_vines is not { Deleted: false } vines)
        {
            return;
        }

        vines.Visible = !Open && !IsVineBurned;
        var remaining = _regrowsAt - Core.Now;
        if (remaining > TimeSpan.Zero)
        {
            _timer = Timer.DelayCall(remaining, UpdateVines);
        }
        else if (Open)
        {
            _timer = Timer.DelayCall(TimeSpan.FromSeconds(1), UpdateVines);
        }
    }

    [AfterDeserialization]
    private void RestoreVines() => _timer = Timer.DelayCall(TimeSpan.Zero, UpdateVines);

    public override void OnDelete()
    {
        _timer?.Stop();
        _vines?.Delete();
        _vines = null;
        base.OnDelete();
    }
}
