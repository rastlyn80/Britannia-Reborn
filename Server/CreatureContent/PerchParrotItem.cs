// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;
using Server.Multis;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class PerchParrotItem : Item
{
    private static readonly int[] Plumage = [3, 13, 19, 28, 33, 48, 63, 68, 89, 98, 113];
    public static readonly LootPack Loot = new([new LootPackEntry(false, [new LootPackItem(typeof(PerchParrotItem), 1)], 10.0, 1)]);

    [Constructible]
    public PerchParrotItem() : base(0x20EE) => Hue = Utility.RandomList(Plumage);

    public override int LabelNumber => 1074281;
    public override double DefaultWeight => 1;

    public override void OnDoubleClick(Mobile from)
    {
        if (!IsChildOf(from.Backpack))
        {
            from.SendLocalizedMessage(1042004);
            return;
        }
        from.SendLocalizedMessage(1072612);
        from.Target = new SelectPerch(this);
    }

    private sealed class SelectPerch(PerchParrotItem item) : Target(2, false, TargetFlags.None)
    {
        protected override void OnTarget(Mobile from, object targeted)
        {
            if (item.Deleted || !item.IsChildOf(from.Backpack))
            {
                from.SendLocalizedMessage(1042004);
                return;
            }
            if (targeted is not AddonComponent { Addon: ParrotPerchAddon { Deleted: false } perch })
            {
                from.SendLocalizedMessage(1072614);
                return;
            }
            var house = BaseHouse.FindHouseAt(perch);
            if (house == null || !house.IsCoOwner(from) || !house.Addons.Contains(perch))
            {
                from.SendLocalizedMessage(1072618);
                return;
            }
            if (perch is OccupiedParrotPerch existing)
            {
                if (!existing.TryPlaceBird(item.Hue))
                {
                    from.SendLocalizedMessage(1072616);
                    return;
                }
            }
            else
            {
                var installed = new OccupiedParrotPerch { Resource = perch.Resource, Hue = perch.Hue };
                installed.MoveToWorld(perch.Location, perch.Map);
                installed.TryPlaceBird(item.Hue);
                house.Addons.Add(installed);
                house.Addons.Remove(perch);
                perch.Delete();
            }
            item.Delete();
        }

        protected override void OnTargetOutOfRange(Mobile from, object targeted) => from.SendLocalizedMessage(1072613);
    }
}

[SerializationGenerator(0)]
public sealed partial class OccupiedParrotPerch : ParrotPerchAddon
{
    private const int BirdHeight = 12;

    [SerializableField(0, getter: "public", setter: "private")]
    private PerchedParrot? _bird;

    [Constructible(AccessLevel.Administrator)]
    public OccupiedParrotPerch()
    {
    }

    public override bool RetainDeedHue => true;
    public override BaseAddonDeed Deed => _bird is { Deleted: false } bird
        ? new OccupiedParrotPerchDeed(bird.Hue, bird.Name, bird.Birth) : new ParrotPerchDeed();

    internal bool TryPlaceBird(int hue, string? name = null, DateTime? birth = null)
    {
        if (_bird is { Deleted: false })
        {
            return false;
        }
        Bird = new PerchedParrot(hue, name, birth);
        PositionBird();
        return true;
    }

    public override void OnChop(Mobile from)
    {
        var house = BaseHouse.FindHouseAt(this);
        if (house?.IsOwner(from) != true || !house.Addons.Contains(this))
        {
            return;
        }
        var deed = Deed;
        deed.Resource = Resource;
        deed.Hue = Hue;
        from.AddToBackpack(deed);
        house.Addons.Remove(this);
        Delete();
        from.SendLocalizedMessage(500461);
        Effects.PlaySound(from.Location, from.Map, 0x3B3);
    }

    public override void OnLocationChange(Point3D from)
    {
        base.OnLocationChange(from);
        PositionBird();
    }

    public override void OnMapChange()
    {
        base.OnMapChange();
        PositionBird();
    }

    private void PositionBird()
    {
        if (_bird is { Deleted: false } bird)
        {
            bird.MoveToWorld(new Point3D(X, Y, Z + BirdHeight), Map ?? Map.Internal);
        }
    }

    public override void OnAfterDelete()
    {
        _bird?.Delete();
        _bird = null;
        base.OnAfterDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class OccupiedParrotPerchDeed : BaseAddonDeed
{
    [SerializableField(0)]
    private int _plumage;

    [SerializableField(1)]
    private string? _birdName;

    [SerializableField(2)]
    private DateTime _birth;

    internal OccupiedParrotPerchDeed(int plumage, string? name, DateTime birth)
    {
        _plumage = plumage;
        _birdName = name;
        _birth = birth;
        LootType = LootType.Blessed;
    }

    public override int LabelNumber => 1072619;

    public override BaseAddon Addon
    {
        get
        {
            var perch = new OccupiedParrotPerch { Resource = Resource, Hue = Hue };
            perch.TryPlaceBird(_plumage, _birdName, _birth);
            return perch;
        }
    }

    public override void GetProperties(IPropertyList list)
    {
        base.GetProperties(list);
        if (string.IsNullOrEmpty(_birdName) || _birdName == PerchedParrot.Unnamed)
        {
            list.Add(1072620);
        }
        else
        {
            list.Add(1072624, _birdName);
        }
    }
}

