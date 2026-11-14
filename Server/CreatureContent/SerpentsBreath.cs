// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class SerpentsBreathFlame : Item
{
    public static readonly Point3D OrderTile = new(28, 212, 3);
    public static readonly Point3D ChaosTile = new(43, 212, 3);
    private static readonly TimeSpan _opening = TimeSpan.FromMinutes(2);

    [SerializableField(0)]
    private bool _order;

    [SerializableField(1)]
    private DateTime _restoreAt;

    [SerializableField(2)]
    private List<SerpentsBreathField> _fields = [];

    private Timer? _restore;
    private readonly Dictionary<Serial, DateTime> _scorched = [];

    [Constructible]
    public SerpentsBreathFlame(bool order) : base(0x19AB)
    {
        _order = order;
        Movable = false;
        Light = LightType.Circle225;
    }

    public override int LabelNumber => _order ? 1112127 : 1112128;
    public override bool HandlesOnSpeech => true;

    public override void OnSpeech(SpeechEventArgs e)
    {
        if (!Visible || e.Mobile is not PlayerMobile { Alive: true } player ||
            player.Map != Map || !player.InRange(this, 2) || Math.Abs(player.Z - Z) > 7 || !player.InLOS(this))
        {
            return;
        }

        var word = e.Speech.Trim().ToLowerInvariant();
        if (_order ? word != "ord" : word is not ("anord" or "an-ord"))
        {
            return;
        }

        _restoreAt = Core.Now + _opening;
        this.MarkDirty();
        Visible = false;
        foreach (var field in _fields)
        {
            if (!field.Deleted)
            {
                field.Visible = false;
            }
        }
        ResumeTimer();
    }

    [AfterDeserialization]
    private void ResumeTimer()
    {
        _restore?.Stop();
        if (_restoreAt != default)
        {
            var delay = _restoreAt - Core.Now;
            _restore = Timer.DelayCall(delay > TimeSpan.Zero ? delay : TimeSpan.Zero, Restore);
        }
    }

    private void Restore()
    {
        _restoreAt = default;
        this.MarkDirty();
        Visible = true;
        _scorched.Clear();
        foreach (var field in _fields)
        {
            if (!field.Deleted)
            {
                field.Visible = true;
            }
        }
    }

    internal bool AllowCrossing(Mobile mobile, int row)
    {
        if (_order)
        {
            if (mobile.Y < row)
            {
                mobile.SendLocalizedMessage(1112225);
                return false;
            }
            return !Visible;
        }

        if (Visible && mobile is PlayerMobile { Alive: true } player &&
            (!_scorched.TryGetValue(player.Serial, out var next) || next <= Core.Now))
        {
            _scorched[player.Serial] = Core.Now + TimeSpan.FromSeconds(5);
            AOS.Damage(player, Utility.RandomMinMax(5, 7), 0, 100, 0, 0, 0);
        }
        return true;
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceSerpentsBreath", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || !actor.InRange(new Point3D(35, 211, 0), 10) || Math.Abs(actor.Z) > 10)
        {
            actor.SendMessage("Stand in the Tomb of Kings entrance hall by the two flames.");
            return;
        }

        PlaceSide(map, true, OrderTile, [205]);
        PlaceSide(map, false, ChaosTile, [203, 204, 206, 207]);
        actor.SendMessage("The twin flames and their linked fields are in place.");
    }

    private static void PlaceSide(Map map, bool order, Point3D location, int[] rows)
    {
        foreach (var existing in map.GetItemsAt<SerpentsBreathFlame>(location))
        {
            if (existing.Location == location)
            {
                return;
            }
        }

        var flame = new SerpentsBreathFlame(order);
        flame.MoveToWorld(location, map);
        foreach (var row in rows)
        {
            for (var x = 33; x <= 37; x++)
            {
                var field = new SerpentsBreathField(flame, order);
                field.MoveToWorld(new Point3D(x, row, 0), map);
                flame._fields.Add(field);
            }
        }
    }

    public override void OnDelete()
    {
        _restore?.Stop();
        foreach (var field in _fields)
        {
            field?.Delete();
        }
        _fields.Clear();
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class SerpentsBreathField : Item
{
    [SerializableField(0)]
    private SerpentsBreathFlame? _flame;

    [Constructible]
    public SerpentsBreathField(SerpentsBreathFlame flame, bool order) : base(order ? 0x3967 : 0x3E27)
    {
        _flame = flame;
        Movable = false;
        Light = LightType.Circle150;
        Hue = order ? 0 : 0x47E;
    }

    public override bool OnMoveOver(Mobile mobile) =>
        Math.Abs(mobile.Z - Z) > 5 || _flame?.AllowCrossing(mobile, Y) != false;
}
