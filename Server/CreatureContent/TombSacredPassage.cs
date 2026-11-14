// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class TombSacredPassage : Item
{
    public static readonly Point3D Threshold = new(37, 38, 0);
    private static readonly Point3D _westGuardian = new(33, 38, 13);
    private static readonly Point3D _eastGuardian = new(42, 38, 13);

    [Constructible]
    public TombSacredPassage() : base(0x1BC3)
    {
        Movable = false;
        Visible = false;
    }

    public override bool OnMoveOver(Mobile mobile)
    {
        var player = mobile as PlayerMobile ?? (mobile as BaseCreature)?.ControlMaster as PlayerMobile;
        if (player != null && AbyssAdmission.HasAccess(player))
        {
            if (mobile == player)
            {
                player.SendLocalizedMessage(1112227);
            }
            return true;
        }

        if (mobile is PlayerMobile)
        {
            mobile.SendLocalizedMessage(1112226);
        }
        return false;
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceTombSacredPassage", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var staff = args.Mobile;
        var map = Map.TerMur;
        if (staff.Map != map || !staff.InRange(Threshold, 6) || Math.Abs(staff.Z - Threshold.Z) > 6)
        {
            staff.SendMessage("Stand near the guardians at the north end of the Tomb of Kings.");
            return;
        }

        for (var x = 35; x <= 39; x++)
        {
            var point = new Point3D(x, Threshold.Y, Threshold.Z);
            var exists = false;
            foreach (var barrier in map.GetItemsInRange<TombSacredPassage>(point, 0))
            {
                exists |= barrier.Location == point;
            }
            if (!exists)
            {
                new TombSacredPassage().MoveToWorld(point, map);
            }
        }

        PlaceGuardian(map, _westGuardian, Direction.East);
        PlaceGuardian(map, _eastGuardian, Direction.West);
        staff.SendMessage("The Tomb of Kings passage and stone guardians are in place.");
    }

    private static void PlaceGuardian(Map map, Point3D point, Direction direction)
    {
        foreach (var guardian in map.GetMobilesInRange<SacredTombGuardian>(point, 0))
        {
            if (guardian.Location == point)
            {
                return;
            }
        }
        new SacredTombGuardian { Direction = direction }.MoveToWorld(point, map);
    }
}

[SerializationGenerator(0)]
public sealed partial class SacredTombGuardian : BaseCreature
{
    [Constructible]
    public SacredTombGuardian() : base(AIType.AI_Melee, FightMode.None, 0)
    {
        Body = 755;
        Hue = 2401;
        CantWalk = true;
        Blessed = true;
    }

    public override string DefaultName => "a stone guardian";
    public override bool IsInvulnerable => true;
}
