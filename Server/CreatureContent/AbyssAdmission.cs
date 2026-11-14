// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class AbyssAdmissionGate : Teleporter
{
    private static readonly Point3D[] _stairs = [new(1125, 1076, -117), new(1126, 1076, -117)];
    private static readonly Point3D[] _entries = [new(520, 920, 39), new(521, 920, 39)];

    [Constructible]
    public AbyssAdmissionGate(Point3D destination) : base(destination, Map.TerMur)
    {
    }

    public override bool OnMoveOver(Mobile from)
    {
        if (!Active || from is not PlayerMobile player)
        {
            return true;
        }

        if (AbyssAdmission.HasAccess(player))
        {
            return base.OnMoveOver(from);
        }

        if (TheArisen.IsUnderwayFor(player))
        {
            player.SendLocalizedMessage(1112226);
            return false;
        }

        var key = player.Alive && player.Backpack is { } pack
            ? pack.FindItemByType<UnderworldKey>(predicate: item => item.Fragment == UnderworldFragment.Complete)
            : null;
        if (key == null)
        {
            player.SendMessage("The stone guardians require a Tripartite Key.");
            return false;
        }

        AbyssAdmission.Grant(player);
        key.Delete();
        player.SendLocalizedMessage(1113708);
        player.SendLocalizedMessage(1113709);
        return base.OnMoveOver(from);
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceUnderworldAbyssEntry", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || !actor.InRange(_stairs[0], 3) || Math.Abs(actor.Z - _stairs[0].Z) > 10)
        {
            actor.SendMessage("Stand at the bottom of the Underworld's spiral stair.");
            return;
        }

        var replaced = new Teleporter?[_stairs.Length];
        var placed = new bool[_stairs.Length];
        for (var i = 0; i < _stairs.Length; i++)
        {
            if (!map.CanFit(_entries[i], 16, checkMobiles: false))
            {
                actor.SendMessage("The Abyss arrival is blocked.");
                return;
            }

            foreach (var teleporter in map.GetItemsAt<Teleporter>(_stairs[i]))
            {
                if (Math.Abs(teleporter.Z - _stairs[i].Z) > 3)
                {
                    continue;
                }

                if (placed[i] || replaced[i] != null || !teleporter.Active ||
                    (teleporter.MapDest != null && teleporter.MapDest != map) ||
                    teleporter.PointDest != _entries[i])
                {
                    actor.SendMessage("An unrelated or inactive teleporter occupies the spiral stair.");
                    return;
                }

                if (teleporter is AbyssAdmissionGate)
                {
                    placed[i] = true;
                }
                else if (teleporter.GetType() == typeof(Teleporter))
                {
                    replaced[i] = teleporter;
                }
                else
                {
                    actor.SendMessage("A specialized teleporter already controls this stair.");
                    return;
                }
            }
        }

        for (var i = 0; i < _stairs.Length; i++)
        {
            if (!placed[i])
            {
                new AbyssAdmissionGate(_entries[i]).MoveToWorld(_stairs[i], map);
                replaced[i]?.Delete();
            }
        }

        actor.SendMessage("Both spiral stair lanes now enforce access to the Abyss.");
    }
}

public sealed class AbyssAdmission : GenericPersistence
{
    private static readonly HashSet<Serial> _admitted = [];
    private static readonly Dictionary<Serial, DateTime> _shrineRetry = [];

    public AbyssAdmission() : base("BritanniaRebornAbyssAdmission", 10)
    {
    }

    public static void Configure() => _ = new AbyssAdmission();
    internal static bool HasAccess(PlayerMobile player) => _admitted.Contains(player.Serial);
    internal static void Grant(PlayerMobile player) => _admitted.Add(player.Serial);
    internal static bool ShrineCanRetry(PlayerMobile player) =>
        !_shrineRetry.TryGetValue(player.Serial, out var retry) || retry <= Core.Now;

    internal static void FailShrineTrial(PlayerMobile player) =>
        _shrineRetry[player.Serial] = Core.Now + TimeSpan.FromHours(24);

    internal static void CompleteShrineTrial(PlayerMobile player)
    {
        Grant(player);
        _shrineRetry.Remove(player.Serial);
    }

    public override void Serialize(IGenericWriter writer)
    {
        writer.WriteEncodedInt(1);
        writer.WriteEncodedInt(_admitted.Count);
        foreach (var serial in _admitted)
        {
            writer.Write(serial.Value);
        }

        var now = Core.Now;
        var pending = _shrineRetry.Where(entry => entry.Value > now).ToArray();
        writer.WriteEncodedInt(pending.Length);
        foreach (var (serial, retry) in pending)
        {
            writer.Write(serial.Value);
            writer.Write(retry);
        }
    }

    public override void Deserialize(IGenericReader reader)
    {
        var version = reader.ReadEncodedInt();
        if (version is not (0 or 1))
        {
            throw new InvalidOperationException($"Unsupported Abyss admission save version {version}.");
        }

        _admitted.Clear();
        var count = reader.ReadEncodedInt();
        for (var i = 0; i < count; i++)
        {
            _admitted.Add((Serial)reader.ReadUInt());
        }

        _shrineRetry.Clear();
        if (version == 1)
        {
            var retries = reader.ReadEncodedInt();
            for (var i = 0; i < retries; i++)
            {
                _shrineRetry.Add((Serial)reader.ReadUInt(), reader.ReadDateTime());
            }
        }
    }
}
