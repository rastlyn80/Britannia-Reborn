// SPDX-License-Identifier: GPL-3.0-or-later
using Server.Mobiles;

namespace Server;

public sealed class MechanicalLifeKnowledge : GenericPersistence
{
    private static readonly Dictionary<Serial, DateTime> _builders = [];

    public MechanicalLifeKnowledge() : base("BritanniaRebornMechanicalLife", 10)
    {
    }

    public static void Configure() => _ = new MechanicalLifeKnowledge();

    internal static bool IsKnownBy(PlayerMobile player) => _builders.ContainsKey(player.Serial);

    internal static bool Learn(PlayerMobile player) => _builders.TryAdd(player.Serial, DateTime.MinValue);

    internal static bool IsRecovering(PlayerMobile player) =>
        _builders.TryGetValue(player.Serial, out var ready) && ready > Core.Now;

    internal static void StartRecovery(PlayerMobile player) =>
        _builders[player.Serial] = Core.Now + TimeSpan.FromMinutes(10);

    public override void Serialize(IGenericWriter writer)
    {
        writer.WriteEncodedInt(0);
        writer.WriteEncodedInt(_builders.Count);
        foreach (var (serial, ready) in _builders)
        {
            writer.Write(serial.Value);
            writer.Write(ready);
        }
    }

    public override void Deserialize(IGenericReader reader)
    {
        var version = reader.ReadEncodedInt();
        if (version != 0)
        {
            throw new InvalidOperationException($"Unsupported mechanical life save version {version}.");
        }

        _builders.Clear();
        var count = reader.ReadEncodedInt();
        for (var i = 0; i < count; i++)
        {
            _builders.Add((Serial)reader.ReadUInt(), reader.ReadDateTime());
        }
    }
}
