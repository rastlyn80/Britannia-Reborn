// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class CitadelAdmissionKey : TransientItem
{
    [SerializableField(0)]
    private CitadelKeyTable? _table;
    [SerializableField(1)]
    private Travesty? _boss;

    public CitadelAdmissionKey(CitadelKeyTable table, Travesty boss) : base(0x1012, TimeSpan.FromMinutes(10))
    {
        _table = table;
        _boss = boss;
        Hue = 0x489;
        LootType = LootType.Blessed;
    }

    public override int LabelNumber => 1074344;

    public override void OnDoubleClick(Mobile from)
    {
        if (!IsChildOf(from.Backpack))
        {
            from.SendLocalizedMessage(1042001);
            return;
        }
        _table?.OfferAdmission(from, this);
    }
}
