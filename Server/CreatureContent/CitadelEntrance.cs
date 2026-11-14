// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class CitadelEntrance : Item
{
    public static readonly Point3D Arrival = new(107, 1883, 0);

    [Constructible]
    public CitadelEntrance() : base(0xE3F) => Movable = false;

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not PlayerMobile { Alive: true, NetState: { } state } player || Map != Map.Tokuno)
        {
            return;
        }

        if (!state.SupportsExpansion(Expansion.ML))
        {
            player.SendLocalizedMessage(1072608);
            return;
        }

        if (player.Map != Map || !player.InRange(this, 2) || !player.InLOS(this))
        {
            player.SendLocalizedMessage(1019045);
            return;
        }

        if (!CitadelEntryQuests.AllowsEntry(player))
        {
            player.SendLocalizedMessage(1074278);
            return;
        }

        BaseCreature.TeleportPets(player, Arrival, Map.Malas);
        player.MoveToWorld(Arrival, Map.Malas);
    }
}
