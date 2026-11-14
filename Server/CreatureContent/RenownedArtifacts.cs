// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class AnimatedLegsoftheInsaneTinker : PlateLegs
{
    [Constructible]
    public AnimatedLegsoftheInsaneTinker()
    {
        Hue = 2310;
        Attributes.BonusDex = 5;
        Attributes.RegenStam = 2;
        Attributes.WeaponDamage = 10;
        Attributes.WeaponSpeed = 10;
        ArmorAttributes.LowerStatReq = 50;
    }

    public override int LabelNumber => 1113760;
    public override int BasePhysicalResistance => 17;
    public override int BaseFireResistance => 15;
    public override int BaseColdResistance => 7;
    public override int BasePoisonResistance => 15;
    public override int BaseEnergyResistance => 2;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[Flippable(0x4205, 0x420B)]
[SerializationGenerator(0)]
public sealed partial class PillarOfStrength : BaseShield
{
    [Constructible]
    public PillarOfStrength() : base(0x4205)
    {
        Attributes.BonusStr = 10;
        Attributes.BonusHits = 10;
        Attributes.WeaponDamage = 20;
    }

    public override int LabelNumber => 1113533;
    public override int BasePhysicalResistance => 10;
    public override int BaseFireResistance => 0;
    public override int BaseColdResistance => 0;
    public override int BasePoisonResistance => 1;
    public override int BaseEnergyResistance => 0;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
    public override int AosStrReq => 20;
    public override int ArmorBase => 12;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
}
