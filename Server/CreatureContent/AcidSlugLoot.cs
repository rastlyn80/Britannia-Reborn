// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class CongealedSlugAcid : Item
{
    [Constructible]
    public CongealedSlugAcid(int amount = 1) : base(0x5742)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1112901;
}

[SerializationGenerator(0)]
public partial class AcidSac : Item
{
    [Constructible]
    public AcidSac() : base(0x0C67)
    {
        Stackable = true;
        Hue = 648;
        Weight = 1.0;
    }

    public override int LabelNumber => 1111654;

    public override void OnDoubleClick(Mobile from)
    {
        if (!IsChildOf(from.Backpack))
        {
            from.SendLocalizedMessage(1042001);
            return;
        }

        from.SendLocalizedMessage(1111656);
        from.BeginTarget(1, false, TargetFlags.None, ApplyAcid);
    }

    private void ApplyAcid(Mobile from, object target)
    {
        if (Deleted || !IsChildOf(from.Backpack))
        {
            from.SendLocalizedMessage(1042001);
            return;
        }

        if (target is not AcidVine vine)
        {
            from.SendMessage("The acid has no effect there.");
            return;
        }

        if (vine.TryBurn(from))
        {
            Consume();
        }
    }
}

[SerializationGenerator(0)]
public partial class VialOfVitriol : Item, ICommodity
{
    [Constructible]
    public VialOfVitriol(int amount = 1) : base(0x5722)
    {
        Stackable = true;
        Amount = amount;
    }

    public override int LabelNumber => 1113331;
    int ICommodity.DescriptionNumber => LabelNumber;
    bool ICommodity.IsDeedable => true;
}
