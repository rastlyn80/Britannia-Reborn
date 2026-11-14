// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class OrcScoutBow : Bow
{
    [Constructible]
    public OrcScoutBow()
    {
    }

    public override void PlaySwingAnimation(Mobile from)
    {
        if (from is OrcScout)
        {
            from.Animate(7, 7, 1, true, false, 0);
            return;
        }
        base.PlaySwingAnimation(from);
    }
}

[SerializationGenerator(0)]
public sealed partial class OrcishBow : OrcScoutBow
{
    [Constructible]
    public OrcishBow()
    {
        Hue = 1107;
        Attributes.WeaponDamage = 25;
        WeaponAttributes.DurabilityBonus = 70;
    }

    public override int LabelNumber => 1153778;
}
