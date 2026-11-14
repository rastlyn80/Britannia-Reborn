// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class FoolsGold : Item
{
    [SerializableField(0)]
    private Niporailem? _source;

    [SerializableField(1)]
    private PlayerMobile? _bearer;

    [SerializableField(2)]
    private DateTime _until;

    private Timer? _timer;

    public FoolsGold(Niporailem source, PlayerMobile bearer) : base(0x0EEF)
    {
        _source = source;
        _bearer = bearer;
        _until = Core.Now + TimeSpan.FromSeconds(15);
        Weight = 300;
        Schedule();
    }

    public override int LabelNumber => 1112113;

    public override bool OnDroppedToWorld(Mobile from, Point3D point)
    {
        _source?.SummonCursedDefender(from);
        new TreasureSand().MoveToWorld(point, from.Map);
        Delete();
        return false;
    }

    [AfterDeserialization]
    private void Schedule()
    {
        var delay = _until - Core.Now;
        _timer = Timer.DelayCall(delay > TimeSpan.Zero ? delay : TimeSpan.Zero, Crumble);
    }

    private void Crumble()
    {
        var sand = new TreasureSand();
        if (Parent is Container container)
        {
            container.DropItem(sand);
        }
        else if (Map != null && Map != Map.Internal)
        {
            sand.MoveToWorld(Location, Map);
        }
        else
        {
            sand.Delete();
        }
        _bearer?.SendLocalizedMessage(1112112);
        Delete();
    }

    public override void OnDelete()
    {
        _timer?.Stop();
        _source = null;
        _bearer = null;
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class TreasureSand : Item
{
    [Constructible]
    public TreasureSand() : base(0x0EFD) => Weight = 1;
    public override int LabelNumber => 1112115;
}
