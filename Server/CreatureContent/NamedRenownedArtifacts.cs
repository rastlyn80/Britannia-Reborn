// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class DemonHuntersStandard : Spear
{
    [Constructible]
    public DemonHuntersStandard()
    {
        Hue = 1377;
        Attributes.CastSpeed = 1;
        Attributes.WeaponSpeed = 25;
        Attributes.WeaponDamage = 50;
        WeaponAttributes.HitLeechStam = 50;
        WeaponAttributes.HitLightning = 40;
        WeaponAttributes.HitLowerDefend = 30;
        Slayer = SlayerName.Exorcism;
    }

    public override int LabelNumber => 1113864;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class DragonJadeEarrings : BaseArmor
{
    [Constructible]
    public DragonJadeEarrings() : base(0x4213)
    {
        Layer = Layer.Earrings;
        Hue = 2129;
        Attributes.BonusDex = 5;
        Attributes.BonusStr = 5;
        Attributes.RegenHits = 2;
        Attributes.RegenStam = 3;
        Attributes.LowerManaCost = 5;
    }

    public override int LabelNumber => 1113720;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override ArmorMaterialType MaterialType => ArmorMaterialType.Chainmail;
    public override ArmorMeditationAllowance DefMedAllowance => ArmorMeditationAllowance.All;
    public override int BasePhysicalResistance => 9;
    public override int BaseFireResistance => 16;
    public override int BaseColdResistance => 5;
    public override int BasePoisonResistance => 13;
    public override int BaseEnergyResistance => 3;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class MantleOfTheFallen : GargishClothChestType1
{
    [Constructible]
    public MantleOfTheFallen()
    {
        Hue = 1512;
        Attributes.LowerRegCost = 25;
        Attributes.BonusInt = 8;
        Attributes.BonusMana = 8;
        Attributes.RegenMana = 1;
        Attributes.SpellDamage = 5;
    }

    public override int LabelNumber => 1113819;
    public override int BasePhysicalResistance => 5;
    public override int BaseFireResistance => 8;
    public override int BaseColdResistance => 11;
    public override int BasePoisonResistance => 12;
    public override int BaseEnergyResistance => 8;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class ResonantStaffofEnlightenment : QuarterStaff
{
    [Constructible]
    public ResonantStaffofEnlightenment()
    {
        Hue = 2401;
        WeaponAttributes.HitMagicArrow = 40;
        WeaponAttributes.MageWeapon = 20;
        Attributes.SpellChanneling = 1;
        Attributes.DefendChance = 10;
        Attributes.WeaponSpeed = 20;
        Attributes.WeaponDamage = -40;
        Attributes.LowerManaCost = 5;
        Attributes.BonusInt = 5;
    }

    public override int LabelNumber => 1113757;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class SwordOfShatteredHopes : GlassSword
{
    [Constructible]
    public SwordOfShatteredHopes()
    {
        Hue = 91;
        WeaponAttributes.HitDispel = 25;
        Attributes.WeaponSpeed = 30;
        Attributes.WeaponDamage = 50;
        WeaponAttributes.ResistFireBonus = 15;
    }

    public override int LabelNumber => 1112770;
    public override int AosStrengthReq => 10;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class SummonersKilt : GargishClothKiltType1
{
    [Constructible]
    public SummonersKilt()
    {
        Hue = 1266;
        Attributes.BonusMana = 5;
        Attributes.RegenMana = 2;
        Attributes.SpellDamage = 5;
        Attributes.LowerManaCost = 8;
        Attributes.LowerRegCost = 10;
    }

    public override int LabelNumber => 1113540;
    public override int BasePhysicalResistance => 5;
    public override int BaseFireResistance => 7;
    public override int BaseColdResistance => 21;
    public override int BasePoisonResistance => 6;
    public override int BaseEnergyResistance => 21;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class DefenderOfTheMagus : MetalShield
{
    [Constructible]
    public DefenderOfTheMagus()
    {
        Hue = 590;
        Attributes.SpellChanneling = 1;
        Attributes.DefendChance = 10;
        Attributes.CastRecovery = 1;
    }

    public override int LabelNumber => 1113851;
    public override int BasePhysicalResistance => 0;
    public override int BaseFireResistance => 1;
    public override int BaseColdResistance => 0;
    public override int BasePoisonResistance => 0;
    public override int BaseEnergyResistance => 0;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class SpinedBloodwormBracers : GargishClothArmsType1
{
    [Constructible]
    public SpinedBloodwormBracers()
    {
        Hue = 1642;
        Attributes.RegenHits = 2;
        Attributes.RegenStam = 2;
        Attributes.WeaponDamage = 10;
        Attributes.ReflectPhysical = 30;
    }

    public override int LabelNumber => 1113865;
    public override int BasePhysicalResistance => 11;
    public override int BaseFireResistance => 10;
    public override int BaseColdResistance => 15;
    public override int BasePoisonResistance => 15;
    public override int BaseEnergyResistance => 10;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class MysticsGarb : Robe
{
    [Constructible]
    public MysticsGarb()
    {
        Hue = 1420;
        Attributes.BonusMana = 5;
        Attributes.LowerManaCost = 1;
    }

    public override int LabelNumber => 1113649;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class BreastplateOfTheBerserker : BaseArmor
{
    [Constructible]
    public BreastplateOfTheBerserker() : base(0x30A)
    {
        Layer = Layer.InnerTorso;
        Hue = 1172;
        Attributes.WeaponSpeed = 10;
        Attributes.WeaponDamage = 15;
        Attributes.LowerManaCost = 4;
        Attributes.BonusHits = 5;
        Attributes.RegenStam = 3;
    }

    public override int LabelNumber => 1113539;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override double DefaultWeight => 10.0;
    public override ArmorMaterialType MaterialType => ArmorMaterialType.Plate;
    public override int BasePhysicalResistance => 18;
    public override int BaseFireResistance => 16;
    public override int BaseColdResistance => 5;
    public override int BasePoisonResistance => 11;
    public override int BaseEnergyResistance => 5;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}
