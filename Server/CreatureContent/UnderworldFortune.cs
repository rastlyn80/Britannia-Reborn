// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Gumps;
using Server.Mobiles;
using Server.Network;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class LuckyCoin : Item
{
    [Constructible]
    public LuckyCoin(int amount = 1) : base(0x0EED)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113366;

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not PlayerMobile { Alive: true } player)
        {
            return;
        }
        if (!IsInBackpack(player))
        {
            player.SendLocalizedMessage(1042001);
            return;
        }

        player.SendLocalizedMessage(1113367);
        player.Target = new FountainTarget(this);
    }

    private bool IsInBackpack(PlayerMobile player) =>
        !Deleted && player.Backpack is { } pack && IsChildOf(pack);

    private sealed class FountainTarget(LuckyCoin coin) : Target(5, true, TargetFlags.None)
    {
        protected override void OnTarget(Mobile from, object targeted)
        {
            if (from is not PlayerMobile { Alive: true } player || !coin.IsInBackpack(player))
            {
                return;
            }

            if (!UnderworldFontOfFortune.IsWater(player, targeted))
            {
                player.SendLocalizedMessage(1113369);
                return;
            }
            if (!UnderworldFortune.TryBeginToss(player))
            {
                player.SendLocalizedMessage(1113368);
                return;
            }

            var fortunes = Math.Min(coin.Amount, 2);
            coin.Delete();
            for (var i = 0; i < fortunes; i++)
            {
                UnderworldFortune.GrantFortune(player);
            }
            player.FixedParticles(0x373A, 10, 15, 5018, EffectLayer.Waist);
            player.PlaySound(0x22);
        }
    }
}

[SerializationGenerator(0)]
public sealed partial class UnderworldFontOfFortune : BaseAddon
{
    private static readonly Point3D _site = new(1121, 957, -42);
    private static readonly (int Art, int X, int Y)[] _tiles =
    [
        (0x1741, -2, -2), (0x173F, -1, -2), (0x1738, 0, -2), (0x1737, 1, -2),
        (0x173D, -2, -1), (0x173E, -1, -1), (0x1739, 0, -1), (0x1736, 1, -1),
        (0x173C, -2,  0), (0x173B, -1,  0), (0x173A, 0,  0), (0x1735, 1,  0),
        (0x1731, -2,  1), (0x1732, -1,  1), (0x1733, 0,  1), (0x1734, 1,  1)
    ];

    [Constructible]
    public UnderworldFontOfFortune()
    {
        foreach (var (art, x, y) in _tiles)
        {
            AddComponent(new FontTile(art), x, y, 0);
        }
    }

    public override int LabelNumber => 1113618;
    public override bool HandlesOnMovement => true;

    public override void OnMovement(Mobile mobile, Point3D previous)
    {
        if (mobile is PlayerMobile { Alive: false } player && !Utility.InRange(Location, previous, 5))
        {
            OfferResurrection(player);
        }
    }

    private bool CanUse(PlayerMobile player) =>
        !Deleted && Location == _site && Map == Map.TerMur && player.Map == Map &&
        player.InRange(Location, 5) && Math.Abs(player.Z - Z) <= 12 && player.InLOS(Location);

    private void OfferResurrection(PlayerMobile player)
    {
        if (!player.Alive && CanUse(player) && UnderworldFortune.CanReceiveHealing(player))
        {
            player.SendGump(new FontResurrectionGump(this, player));
        }
    }

    private void Heal(PlayerMobile player)
    {
        if (player.Alive && player.Hits < player.HitsMax && CanUse(player) && UnderworldFortune.CanReceiveHealing(player))
        {
            player.Hits = player.HitsMax;
            UnderworldFortune.RecordHealing(player);
            player.SendLocalizedMessage(1113365);
        }
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceUnderworldFont", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var player = args.Mobile;
        if (player.Map != Map.TerMur || !player.InRange(_site, 5) || Math.Abs(player.Z - _site.Z) > 12)
        {
            player.SendMessage("Stand near the Font of Fortune at the northern edge of the Underworld.");
            return;
        }

        foreach (var font in Map.TerMur.GetItemsAt<UnderworldFontOfFortune>(_site))
        {
            if (font.Location != _site)
            {
                continue;
            }
            player.SendMessage("The Font of Fortune is already in place.");
            return;
        }

        new UnderworldFontOfFortune().MoveToWorld(_site, Map.TerMur);
        player.SendMessage("The Font of Fortune is in place.");
    }

    internal static bool IsWater(PlayerMobile player, object target)
    {
        if (player.Map != Map.TerMur || Math.Abs(player.Z - _site.Z) > 12)
        {
            return false;
        }
        if (target is FontTile { Addon: UnderworldFontOfFortune { Deleted: false } fountain })
        {
            return fountain.Location == _site && fountain.Map == player.Map;
        }
        if (target is not StaticTarget tile)
        {
            return false;
        }

        // The client can select an existing map tile beneath the server addon.
        var tileZ = tile.Z - TileData.ItemTable[tile.ItemID].CalcHeight;
        return tileZ == _site.Z && Array.Exists(_tiles,
            piece => piece.Art == tile.ItemID && _site.X + piece.X == tile.X && _site.Y + piece.Y == tile.Y);
    }

    private sealed class FontResurrectionGump(UnderworldFontOfFortune font, PlayerMobile player) : ResurrectGump(player)
    {
        public override void OnResponse(NetState state, in RelayInfo info)
        {
            if (info.ButtonID != 1 || state.Mobile != player || player.Alive || !font.CanUse(player) ||
                !UnderworldFortune.CanReceiveHealing(player))
            {
                return;
            }

            base.OnResponse(state, info);
            if (player.Alive)
            {
                UnderworldFortune.RecordHealing(player);
            }
        }
    }

    [SerializationGenerator(0)]
    public sealed partial class FontTile : AddonComponent
    {
        [Constructible]
        public FontTile(int art) : base(art)
        {
        }

        public override int LabelNumber => 1113618;

        public override void OnDoubleClick(Mobile from)
        {
            if (from is PlayerMobile player && Addon is UnderworldFontOfFortune font)
            {
                font.Heal(player);
            }
        }

        public override void OnDoubleClickDead(Mobile from)
        {
            if (from is PlayerMobile player && Addon is UnderworldFontOfFortune font)
            {
                font.OfferResurrection(player);
            }
        }
    }
}

public sealed class UnderworldFortune : GenericPersistence
{
    private static readonly TimeSpan _tossCooldown = TimeSpan.FromHours(12);
    private static readonly TimeSpan _healingCooldown = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan _blessingDuration = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan _extension = TimeSpan.FromHours(1);
    private static readonly Dictionary<Serial, DateTime> _nextToss = [];
    private static readonly Dictionary<Serial, DateTime> _nextHealing = [];
    private static readonly Dictionary<Serial, DateTime> _protectedUntil = [];
    private static readonly (StatType Stat, string Name, int Message, Dictionary<Serial, DateTime> Timers)[] _statBlessings =
    [
        (StatType.Str, "FontOfFortuneStr", 1113373, []),
        (StatType.Dex, "FontOfFortuneDex", 1113374, []),
        (StatType.Int, "FontOfFortuneInt", 1113371, [])
    ];

    public UnderworldFortune() : base("BritanniaRebornUnderworldFortune", 10)
    {
    }

    public static void Configure() => _ = new UnderworldFortune();

    public static void Initialize() => EventSink.Connected += RestoreBlessings;

    private static void RestoreBlessings(Mobile mobile)
    {
        if (mobile is not PlayerMobile player)
        {
            return;
        }

        var now = Core.Now;
        foreach (var (stat, name, _, timers) in _statBlessings)
        {
            if (timers.TryGetValue(player.Serial, out var end) && end > now && player.GetStatMod(name) == null)
            {
                player.AddStatMod(new StatMod(stat, name, 10, end - now));
            }
        }
    }

    internal static bool CanReceiveHealing(PlayerMobile player) =>
        _nextHealing.GetValueOrDefault(player.Serial) <= Core.Now;

    internal static void RecordHealing(PlayerMobile player) =>
        _nextHealing[player.Serial] = Core.Now + _healingCooldown;

    internal static bool TryBeginToss(PlayerMobile player)
    {
        var now = Core.Now;
        if (_nextToss.TryGetValue(player.Serial, out var next) && next > now)
        {
            return false;
        }

        _nextToss[player.Serial] = now + _tossCooldown;
        return true;
    }

    internal static bool ProtectsFromSpecialAttack(Mobile player) =>
        _protectedUntil.TryGetValue(player.Serial, out var end) && end > Core.Now;

    internal static void GrantFortune(PlayerMobile player)
    {
        var serial = player.Serial;
        var now = Core.Now;
        // Offer the extension only when there is an existing Font stat blessing to extend.
        var extendable = Array.FindIndex(_statBlessings,
            bonus => bonus.Timers.GetValueOrDefault(serial) > now && player.GetStatMod(bonus.Name) != null);
        var roll = Utility.Random(extendable < 0 ? 4 : 5);
        if (roll == 3)
        {
            _protectedUntil[serial] = now + _blessingDuration;
            player.SendLocalizedMessage(1113375);
            return;
        }

        if (roll == 4)
        {
            var (stat, name, _, timers) = _statBlessings[extendable];
            var end = timers[serial] + _extension;
            player.RemoveStatMod(name);
            player.AddStatMod(new StatMod(stat, name, 10, end - now));
            timers[serial] = end;
            player.SendLocalizedMessage(1113372);
            return;
        }

        var (type, key, message, expirations) = _statBlessings[roll];
        var expires = now + _blessingDuration;
        if (expirations.GetValueOrDefault(serial) < expires || player.GetStatMod(key) == null)
        {
            player.RemoveStatMod(key);
            player.AddStatMod(new StatMod(type, key, 10, _blessingDuration));
            expirations[serial] = expires;
        }
        player.SendLocalizedMessage(message);
    }

    internal static void DropCoin(Container corpse, double chance)
    {
        if (chance > 0 && Utility.RandomDouble() < chance)
        {
            corpse.DropItem(new LuckyCoin());
        }
    }

    public override void Serialize(IGenericWriter writer)
    {
        writer.WriteEncodedInt(1);
        WriteTimers(writer, _nextToss);
        WriteTimers(writer, _protectedUntil);
        foreach (var bonus in _statBlessings)
        {
            WriteTimers(writer, bonus.Timers);
        }
        WriteTimers(writer, _nextHealing);
    }

    public override void Deserialize(IGenericReader reader)
    {
        var version = reader.ReadEncodedInt();
        if (version is not (0 or 1))
        {
            throw new InvalidOperationException("Unsupported Underworld Fortune save version.");
        }
        ReadTimers(reader, _nextToss);
        ReadTimers(reader, _protectedUntil);
        foreach (var bonus in _statBlessings)
        {
            ReadTimers(reader, bonus.Timers);
        }
        if (version >= 1)
        {
            ReadTimers(reader, _nextHealing);
        }
    }

    private static void WriteTimers(IGenericWriter writer, Dictionary<Serial, DateTime> timers)
    {
        var now = Core.Now;
        var active = timers.Where(entry => entry.Value > now).ToArray();
        writer.WriteEncodedInt(active.Length);
        foreach (var (serial, end) in active)
        {
            writer.Write(serial.Value);
            writer.Write(end);
        }
    }

    private static void ReadTimers(IGenericReader reader, Dictionary<Serial, DateTime> timers)
    {
        timers.Clear();
        var count = reader.ReadEncodedInt();
        for (var i = 0; i < count; i++)
        {
            var serial = (Serial)reader.ReadUInt();
            var end = reader.ReadDateTime();
            if (end > Core.Now)
            {
                timers.Add(serial, end);
            }
        }
    }
}
