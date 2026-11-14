// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class TombHiddenDoor : Item
{
    public static readonly Point3D Threshold = new(52, 99, 0);
    private const int ClosedGraphic = 18304;
    private static readonly Point3D _return = new(21, 99, 1);
    private static readonly Point3D _antechamber = new(35, 215, -5);

    [SerializableField(0)]
    private DateTime _closesAt;

    private Timer? _timer;

    [Constructible]
    public TombHiddenDoor() : base(ClosedGraphic) => Movable = false;

    public override int LabelNumber => 1020233;
    public bool Open => _closesAt != default;

    public override void OnDoubleClick(Mobile from)
    {
        if (Open || from.Map != Map || !from.InRange(this, 1) || Math.Abs(from.Z - Z) > 5 ||
            !from.InLOS(this))
        {
            return;
        }

        _closesAt = Core.Now + TimeSpan.FromMinutes(2);
        this.MarkDirty();
        ItemID = 1;
        ResumeTimer();
    }

    public override void OnDoubleClickDead(Mobile from) => OnDoubleClick(from);

    public override bool OnMoveOver(Mobile mobile) => Math.Abs(mobile.Z - Z) > 5 || Open;

    [AfterDeserialization]
    private void ResumeTimer()
    {
        _timer?.Stop();
        if (Open)
        {
            var delay = _closesAt - Core.Now;
            _timer = Timer.DelayCall(delay > TimeSpan.Zero ? delay : TimeSpan.Zero, Close);
        }
    }

    private void Close()
    {
        foreach (var mobile in Map.GetMobilesInRange<Mobile>(Location, 0))
        {
            if (Math.Abs(mobile.Z - Z) <= 5)
            {
                _timer = Timer.DelayCall(TimeSpan.FromSeconds(2), Close);
                return;
            }
        }

        _closesAt = default;
        this.MarkDirty();
        ItemID = ClosedGraphic;
    }

    public override void OnDelete()
    {
        _timer?.Stop();
        base.OnDelete();
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceTombHiddenAccess", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || actor.Y is < 94 or > 104 || actor.X is < 18 or > 56 || Math.Abs(actor.Z) > 6)
        {
            actor.SendMessage("Stand along either side of the blue hall in the Tomb of Kings.");
            return;
        }

        var hasDoor = false;
        foreach (var door in map.GetItemsAt<TombHiddenDoor>(Threshold))
        {
            hasDoor |= door.Location == Threshold;
        }

        var hasReturn = false;
        foreach (var gate in map.GetItemsAt<Teleporter>(_return))
        {
            if (Math.Abs(gate.Z - _return.Z) > 2)
            {
                continue;
            }
            if (!gate.Active || gate.PointDest != _antechamber || (gate.MapDest != null && gate.MapDest != map))
            {
                actor.SendMessage("A different teleporter occupies the return alcove.");
                return;
            }
            hasReturn = true;
        }

        if (!hasDoor)
        {
            new TombHiddenDoor().MoveToWorld(Threshold, map);
        }
        if (!hasReturn)
        {
            new TombHallReturn(_antechamber).MoveToWorld(_return, map);
        }

        foreach (var item in map.GetItemsAt<Item>(_return))
        {
            if (item.Location == _return && item.ItemID == 0x376A)
            {
                actor.SendMessage("The Tomb's hidden door and return are already in place.");
                return;
            }
        }

        new Static(0x376A).MoveToWorld(_return, map);
        actor.SendMessage("The Tomb's hidden door and return sparkle are in place.");
    }
}

[SerializationGenerator(0)]
public sealed partial class TombHallReturn : Teleporter
{
    [Constructible]
    public TombHallReturn(Point3D destination) : base(destination, Map.TerMur)
    {
        SoundID = 0x1FE;
        DestEffect = true;
    }

    public override void DoTeleport(Mobile mobile)
    {
        base.DoTeleport(mobile);
        if (mobile is PlayerMobile)
        {
            mobile.SendLocalizedMessage(1112182);
        }
    }
}
