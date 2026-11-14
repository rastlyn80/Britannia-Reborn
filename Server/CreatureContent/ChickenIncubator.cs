// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Gumps;
using Server.Multis;

namespace Server.Items;

[Flippable(0x407C, 0x407D)]
[SerializationGenerator(0)]
public partial class ChickenIncubator : BaseContainer, ISecurable
{
    [SerializableField(0)]
    private SecureLevel _level;

    [Constructible]
    public ChickenIncubator() : base(0x407C)
    {
        Level = SecureLevel.CoOwners;
    }

    public override int LabelNumber => 1112479;
    public override int DefaultGumpID => 1156;
    public override int DefaultDropSound => 66;
    public override int DefaultMaxItems => 6;
    internal bool HeatsEggs => Parent == null && !Deleted && BaseHouse.CheckSecured(this);

    internal bool CanUseAt(Mobile from) =>
        HeatsEggs && from.Alive && from.Map == Map && from.InRange(Location, 2) &&
        IsAccessibleTo(from) && from.InLOS(this);

    public override bool CheckHold(Mobile from, Item item, bool message, bool checkItems, int plusItems, int plusWeight)
    {
        if (!HeatsEggs)
        {
            if (message)
            {
                from?.SendLocalizedMessage(1113711);
            }
            return false;
        }

        return item is ChickenLizardEgg && Items.Count < DefaultMaxItems &&
            base.CheckHold(from, item, message, checkItems, plusItems, plusWeight);
    }
}
