// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class TigersClawThief : SerpentsFangAssassin
{
    [Constructible]
    public TigersClawThief() : base(0x69, new Wakizashi(), "of the Tiger's Claw Sect")
    {
        SetStr(340, 360);
        SetDex(400, 415);
        SetInt(200, 215);
        SetHits(800, 815);
        SetResistance(ResistanceType.Physical, 45, 65);
        SetResistance(ResistanceType.Fire, 60, 70);
    }

    public override string DefaultName => "Black Order Thief";
    public override string CorpseName => "a black order thief corpse";
    protected override Item CreateSectBadge() => new TigerClawSectBadge();
}
