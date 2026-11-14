// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;

namespace Server.Items;

public enum UnderworldFragment
{
    Blue,
    Red,
    Yellow,
    Complete
}

public static class UnderworldLaboratories
{
    private readonly record struct Site(Point3D Stand, Point3D Lever, Point3D Globe, Point3D Journal, UnderworldFragment Fragment);

    private static readonly Site[] _sites =
    [
        new(new(1069, 1195, -42), new(1068, 1193, -32), new(1066, 1195, -42), new(1068, 1193, -36), UnderworldFragment.Blue),
        new(new(1004, 1049, -32), new(1003, 1045, -22), new(1002, 1049, -32), new(1004, 1046, -32), UnderworldFragment.Red)
    ];

    public static void Initialize() =>
        CommandSystem.Register("PlaceUnderworldLaboratory", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        foreach (var site in _sites)
        {
            if (actor.Map != Map.TerMur || !actor.InRange(site.Stand, 4) || Math.Abs(actor.Z - site.Stand.Z) > 8)
            {
                continue;
            }

            foreach (var lever in actor.Map.GetItemsInRange<UnderworldLaboratoryLever>(site.Lever, 0))
            {
                if (lever.Location == site.Lever)
                {
                    actor.SendMessage("This laboratory is already in place.");
                    return;
                }
            }

            var journal = new UnderworldLaboratoryJournal(site.Fragment);
            journal.MoveToWorld(site.Journal, actor.Map);
            var leverItem = new UnderworldLaboratoryLever(site.Globe, site.Fragment);
            leverItem.MoveToWorld(site.Lever, actor.Map);
            leverItem.PlaceGlobe();
            actor.SendMessage("The journal, globe and switch are in place.");
            return;
        }

        actor.SendMessage("Stand inside one of the Underworld's secret laboratories.");
    }
}

[SerializationGenerator(0)]
public sealed partial class UnderworldLaboratoryJournal : BaseBook
{
    public UnderworldLaboratoryJournal(UnderworldFragment fragment) : base(0x0FF1,
        "Laboratory Journal", fragment == UnderworldFragment.Blue ? "Garamon" : "Tyball", 1, false)
    {
        Movable = false;
        Pages[0] = fragment == UnderworldFragment.Blue
            ? new BookPageInfo("My brother and I", "released the Slasher.", "I will lure him into", "the Chamber of Virtue", "while Tyball seals it.", "Then I must lead him", "back to his own plane.")
            : new BookPageInfo("The Slasher tempts me", "with wealth and power", "for my brother's life.", "Did he make Garamon", "the same bargain?", "We must see this", "through together.");
    }
}

[SerializationGenerator(0)]
public sealed partial class UnderworldLaboratoryLever : Item
{
    private static readonly TimeSpan _liftTime = TimeSpan.FromSeconds(4);
    private static readonly TimeSpan _openTime = TimeSpan.FromSeconds(30);
    private Timer? _timer;

    [SerializableField(0)]
    private Point3D _rest;

    [SerializableField(1)]
    private UnderworldFragment _fragment;

    [SerializableField(2)]
    private DateTime _started;

    [SerializableField(3)]
    private Static? _globe;

    [SerializableField(4)]
    private UnderworldKey? _masterKey;

    [Constructible]
    public UnderworldLaboratoryLever(Point3D rest, UnderworldFragment fragment) : base(0x1091)
    {
        Movable = false;
        _rest = rest;
        _fragment = fragment;
    }

    public bool KeyAvailable => _started != default && Core.Now >= _started + _liftTime &&
                                Core.Now < _started + _liftTime + _openTime;

    public void PlaceGlobe()
    {
        if (_globe is { Deleted: false } && _masterKey is { Deleted: false })
        {
            return;
        }

        _globe = new Static(0x1048);
        _globe.MoveToWorld(_rest, Map);
        _masterKey = new UnderworldKey(_fragment, this) { Visible = false };
        _masterKey.MoveToWorld(_rest, Map);
    }

    public override void OnDoubleClick(Mobile from)
    {
        if (!from.Alive || from.Map != Map || !from.InRange(this, 1) ||
            Math.Abs(from.Z - Z) > 12 || !from.InLOS(this))
        {
            from.SendLocalizedMessage(1019045);
            return;
        }

        if (_started != default && Core.Now < _started + _liftTime + _openTime)
        {
            return;
        }

        PlaceGlobe();
        _started = Core.Now;
        Effects.PlaySound(Location, Map, 0x3E8);
        UpdateLift();
    }

    private void UpdateLift()
    {
        _timer?.Stop();
        _timer = null;
        if (_globe is not { Deleted: false } globe || _masterKey is not { Deleted: false } key)
        {
            return;
        }

        var elapsed = Core.Now - _started;
        var active = _started != default && elapsed < _liftTime + _openTime;
        var rise = active ? Math.Clamp((int)elapsed.TotalSeconds, 0, 4) * 2 : 0;
        globe.Location = new Point3D(_rest.X, _rest.Y, _rest.Z + rise);
        key.Visible = KeyAvailable;
        ItemID = active ? 0x1092 : 0x1091;
        if (active)
        {
            var next = elapsed < _liftTime ? _started.AddSeconds(rise / 2 + 1) : _started + _liftTime + _openTime;
            _timer = Timer.DelayCall(next - Core.Now, UpdateLift);
        }
        else
        {
            _started = default;
        }
    }

    [AfterDeserialization]
    private void ResumeLift() => _timer = Timer.DelayCall(TimeSpan.Zero, UpdateLift);

    public override void OnDelete()
    {
        _timer?.Stop();
        _globe?.Delete();
        _masterKey?.Delete();
        _globe = null;
        _masterKey = null;
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class UnderworldKey : Item
{
    private static readonly TimeSpan _copyLife = TimeSpan.FromHours(1);
    private Timer? _timer;

    [SerializableField(0)]
    private UnderworldFragment _fragment;

    [SerializableField(1)]
    private UnderworldLaboratoryLever? _source;

    [SerializableField(2)]
    private DateTime _expiresAt;

    [Constructible]
    public UnderworldKey(UnderworldFragment fragment, UnderworldLaboratoryLever? source = null) : base(0x100E)
    {
        _fragment = fragment;
        _source = source;
        Hue = fragment switch
        {
            UnderworldFragment.Blue => 0x59,
            UnderworldFragment.Red => 0x21,
            UnderworldFragment.Yellow => 0x35,
            _ => 0
        };
        Movable = source == null;
        if (Movable && fragment != UnderworldFragment.Complete)
        {
            _expiresAt = Core.Now + _copyLife;
            ScheduleExpiry();
        }
    }

    public override int LabelNumber => 1111646 + (int)_fragment;
    public bool IsExpired => _expiresAt != default && _expiresAt <= Core.Now;

    public static bool HasFragment(Container pack, UnderworldFragment fragment)
    {
        foreach (var key in pack.FindItemsByType<UnderworldKey>())
        {
            if (!key.IsExpired && key.Fragment == fragment)
            {
                return true;
            }
        }

        return false;
    }

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not Mobiles.PlayerMobile { Alive: true, Backpack: { } pack } || IsExpired)
        {
            return;
        }

        if (_source != null)
        {
            if (_source.Deleted || !_source.KeyAvailable || !Visible || from.Map != Map ||
                !from.InRange(this, 2) || Math.Abs(from.Z - Z) > 12 || !from.InLOS(this))
            {
                return;
            }

            if (HasFragment(pack, _fragment) || HasFragment(pack, UnderworldFragment.Complete))
            {
                from.SendLocalizedMessage(1111653);
                return;
            }

            var copy = new UnderworldKey(_fragment);
            if (pack.TryDropItem(from, copy, true))
            {
                from.SendLocalizedMessage(1111652);
            }
            else
            {
                copy.Delete();
            }

            return;
        }

        if (_fragment == UnderworldFragment.Complete || !IsChildOf(pack))
        {
            return;
        }

        var pieces = new UnderworldKey?[3];
        foreach (var key in pack.FindItemsByType<UnderworldKey>())
        {
            if (!key.IsExpired && key.Fragment != UnderworldFragment.Complete)
            {
                pieces[(int)key.Fragment] = key;
            }
        }

        var missing = Array.FindAll(pieces, key => key == null).Length;
        if (missing != 0)
        {
            from.SendLocalizedMessage(1114319, missing.ToString());
            return;
        }

        var combined = new UnderworldKey(UnderworldFragment.Complete);
        if (!pack.TryDropItem(from, combined, true))
        {
            combined.Delete();
            return;
        }

        foreach (var piece in pieces)
        {
            piece!.Delete();
        }

        from.SendLocalizedMessage(1111650);
    }

    public override bool OnDroppedToWorld(Mobile from, Point3D p)
    {
        if (_expiresAt == default)
        {
            return base.OnDroppedToWorld(from, p);
        }

        from.SendLocalizedMessage(1111651);
        Delete();
        return false;
    }

    [AfterDeserialization]
    private void ScheduleExpiry()
    {
        if (_expiresAt != default)
        {
            _timer = Timer.DelayCall(_expiresAt - Core.Now, Delete);
        }
    }

    public override void OnDelete()
    {
        _timer?.Stop();
        _source = null;
        base.OnDelete();
    }
}
