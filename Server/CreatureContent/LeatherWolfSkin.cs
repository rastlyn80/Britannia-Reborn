// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class LeatherWolfSkin : Item
{
    [Constructible]
    public LeatherWolfSkin(int amount = 1) : base(0xDF8)
    {
        Stackable = true;
        Amount = amount;
        Hue = 248;
    }

    public override int LabelNumber => 1112906;
}
