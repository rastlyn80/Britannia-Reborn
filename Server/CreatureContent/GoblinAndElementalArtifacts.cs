// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.BuffIcons;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class TorcOfTheGuardians : GoldNecklace
{
    [Constructible]
    public TorcOfTheGuardians()
    {
        Hue = 1837;
        Attributes.BonusInt = 5;
        Attributes.BonusStr = 5;
        Attributes.BonusDex = 5;
        Attributes.RegenStam = 2;
        Attributes.RegenMana = 2;
        Attributes.LowerManaCost = 5;
        Resistances.Physical = 5;
        Resistances.Fire = 5;
        Resistances.Cold = 5;
        Resistances.Poison = 5;
        Resistances.Energy = 5;
    }

    public override int LabelNumber => 1113721;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class GiantSteps : GargishStoneLegsType1
{
    [Constructible]
    public GiantSteps()
    {
        Hue = 656;
        Attributes.BonusStr = 5;
        Attributes.BonusDex = 5;
        Attributes.BonusHits = 5;
        Attributes.RegenHits = 2;
        Attributes.WeaponDamage = 10;
    }

    public override int LabelNumber => 1113537;
    public override int BasePhysicalResistance => 18;
    public override int BaseFireResistance => 16;
    public override int BaseColdResistance => 4;
    public override int BasePoisonResistance => 8;
    public override int BaseEnergyResistance => 12;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class CavalrysFolly : BladedStaff
{
    [Constructible]
    public CavalrysFolly()
    {
        Hue = 1165;
        Attributes.BonusHits = 2;
        Attributes.AttackChance = 10;
        Attributes.WeaponDamage = 45;
        Attributes.WeaponSpeed = 35;
        WeaponAttributes.HitLowerDefend = 40;
        WeaponAttributes.HitFireball = 40;
    }

    public override int LabelNumber => 1115446;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class ObsidianEarrings : BaseArmor
{
    [Constructible]
    public ObsidianEarrings() : base(0x4213)
    {
        Layer = Layer.Earrings;
        Attributes.BonusMana = 8;
        Attributes.RegenMana = 2;
        Attributes.RegenStam = 2;
        Attributes.SpellDamage = 8;
    }

    public override int LabelNumber => 1113820;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override ArmorMaterialType MaterialType => ArmorMaterialType.Chainmail;
    public override ArmorMeditationAllowance DefMedAllowance => ArmorMeditationAllowance.All;
    public override int BasePhysicalResistance => 4;
    public override int BaseFireResistance => 10;
    public override int BaseColdResistance => 10;
    public override int BasePoisonResistance => 3;
    public override int BaseEnergyResistance => 13;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class TheImpalersPick : HammerPick
{
    [Constructible]
    public TheImpalersPick()
    {
        Hue = 2101;
        Slayer = SlayerName.Repond;
        WeaponAttributes.HitLightning = 40;
        WeaponAttributes.HitLowerDefend = 40;
        Attributes.WeaponSpeed = 30;
        Attributes.WeaponDamage = 45;
    }

    public override int LabelNumber => 1113822;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;

    public override void OnHit(Mobile attacker, Mobile defender, double damageBonus = 1.0)
    {
        var before = defender.Hits;
        base.OnHit(attacker, defender, damageBonus);
        if (!Core.AOS || !defender.Alive || defender.Hits >= before || Utility.RandomDouble() >= 0.10)
        {
            return;
        }
        defender.Mana -= (before - defender.Hits) * 9 / 10;
        defender.FixedParticles(0x3789, 10, 25, 5032, EffectLayer.Head);
        defender.PlaySound(0x1F8);
    }
}

[SerializationGenerator(0)]
public sealed partial class AxeOfAbandon : BattleAxe
{
    [Constructible]
    public AxeOfAbandon()
    {
        Hue = 556;
        WeaponAttributes.HitLowerDefend = 40;
        Attributes.AttackChance = 15;
        Attributes.DefendChance = 10;
        Attributes.CastSpeed = 1;
        Attributes.WeaponSpeed = 30;
        Attributes.WeaponDamage = 50;
    }

    public override int LabelNumber => 1113863;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class DemonBridleRing : GoldRing
{
    [Constructible]
    public DemonBridleRing()
    {
        Hue = 39;
        Attributes.CastRecovery = 2;
        Attributes.CastSpeed = 1;
        Attributes.RegenHits = 1;
        Attributes.RegenMana = 1;
        Attributes.DefendChance = 10;
        Attributes.LowerManaCost = 4;
        Resistances.Fire = 5;
    }

    public override int LabelNumber => 1113651;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class VoidInfusedKilt : BaseArmor
{
    [Constructible]
    public VoidInfusedKilt() : base(0x30C)
    {
        Weight = 5.0;
        Hue = 2124;
        Attributes.AttackChance = 5;
        Attributes.BonusStr = 5;
        Attributes.BonusDex = 5;
        Attributes.RegenMana = 1;
        Attributes.RegenStam = 1;
    }

    public override int LabelNumber => 1113868;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override ArmorMaterialType MaterialType => ArmorMaterialType.Plate;
    public override int AosStrReq => 80;
    public override int BasePhysicalResistance => 13;
    public override int BaseFireResistance => 12;
    public override int BaseColdResistance => 8;
    public override int BasePoisonResistance => 9;
    public override int BaseEnergyResistance => 9;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class BladeOfBattle : BaseSword
{
    [Constructible]
    public BladeOfBattle() : base(0x907)
    {
        Hue = 2045;
        WeaponAttributes.HitLowerDefend = 40;
        Attributes.AttackChance = 15;
        Attributes.DefendChance = 10;
        Attributes.WeaponSpeed = 25;
        Attributes.WeaponDamage = 50;
    }

    public override int LabelNumber => 1113525;
    public override int RequiredRaces => Race.AllowGargoylesOnly;
    public override WeaponAbility PrimaryAbility => WeaponAbility.ArmorIgnore;
    public override WeaponAbility SecondaryAbility => WeaponAbility.MortalStrike;
    public override int AosStrengthReq => 45;
    public override int AosMinDamage => 10;
    public override int AosMaxDamage => 13;
    public override int AosSpeed => 43;
    public override float MlSpeed => 2.25f;
    public override int OldStrengthReq => 35;
    public override int OldMinDamage => 4;
    public override int OldMaxDamage => 32;
    public override int OldSpeed => 45;
    public override int DefHitSound => 0x236;
    public override int DefMissSound => 0x238;
    public override SkillName DefSkill => SkillName.Fencing;
    public override WeaponType DefType => WeaponType.Piercing;
    public override WeaponAnimation DefAnimation => WeaponAnimation.Pierce1H;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class JadeWarAxe : WarAxe
{
    [Constructible]
    public JadeWarAxe()
    {
        Hue = 1162;
        WeaponAttributes.HitFireball = 30;
        WeaponAttributes.HitLowerDefend = 60;
        Attributes.WeaponSpeed = 20;
        Attributes.WeaponDamage = 50;
    }

    public override int LabelNumber => 1115445;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class TokenOfHolyFavor : GoldBracelet
{
    [Constructible]
    public TokenOfHolyFavor()
    {
        Hue = 96;
        Attributes.BonusHits = 5;
        Attributes.CastRecovery = 2;
        Attributes.CastSpeed = 1;
        Attributes.DefendChance = 10;
        Attributes.AttackChance = 10;
        Attributes.SpellDamage = 4;
        Resistances.Cold = 5;
        Resistances.Poison = 5;
    }

    public override int LabelNumber => 1113652;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;
}

[SerializationGenerator(0)]
public sealed partial class LegacyOfDespair : DreadSword
{
    [Constructible]
    public LegacyOfDespair()
    {
        Hue = 48;
        Attributes.WeaponSpeed = 30;
        Attributes.WeaponDamage = 60;
        WeaponAttributes.HitLowerDefend = 50;
        WeaponAttributes.HitLowerAttack = 50;
    }

    public override int LabelNumber => 1113519;
    public override int InitMinHits => 255;
    public override int InitMaxHits => 255;

    public override void OnHit(Mobile attacker, Mobile defender, double damageBonus = 1.0)
    {
        var before = defender.Hits;
        base.OnHit(attacker, defender, damageBonus);
        if (!Core.AOS || !defender.Alive || defender.Hits >= before || Utility.RandomDouble() >= 0.10)
        {
            return;
        }
        var duration = TimeSpan.FromSeconds(30);
        defender.AddStatMod(new StatMod(StatType.Str, "[Magic] Str Curse", -10, duration));
        defender.AddStatMod(new StatMod(StatType.Dex, "[Magic] Dex Curse", -10, duration));
        defender.AddStatMod(new StatMod(StatType.Int, "[Magic] Int Curse", -10, duration));
        if (defender is PlayerMobile player)
        {
            player.AddBuff(new BuffInfo(BuffIcon.Curse, 1075835, 1075836, duration, "-10\t-10\t-10\t0\t0\t0\t0"));
        }
        attacker.SendLocalizedMessage(1113717);
        defender.SendLocalizedMessage(1113718);
        defender.FixedParticles(0x374A, 10, 15, 5028, EffectLayer.Waist);
        defender.PlaySound(0x1EA);
    }
}
