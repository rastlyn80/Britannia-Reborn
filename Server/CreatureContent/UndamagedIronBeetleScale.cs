// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class UndamagedIronBeetleScale : Item
{
    [Constructible]
    public UndamagedIronBeetleScale() : base(0x5742) => Weight = 1;

    public override int LabelNumber => 1112905;
}
