// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Misc;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public abstract partial class CavernRatman : BaseCreature
{
    protected CavernRatman(int body, AIType ai, (int Min, int Max) str, (int Min, int Max) dex,
        (int Min, int Max) intel, (int Min, int Max) hits, (int Min, int Max) damage)
        : base(ai, FightMode.Closest, 10, ai == AIType.AI_Archer ? 6 : 1)
    {
        Body = body;
        BaseSoundID = 437;
        SetStr(str.Min, str.Max);
        SetDex(dex.Min, dex.Max);
        SetInt(intel.Min, intel.Max);
        SetHits(hits.Min, hits.Max);
        SetDamage(damage.Min, damage.Max);
        SetDamageType(ResistanceType.Physical, 100);
        Karma = -1500;
        Fame = 1500;
    }

    public override InhumanSpeech SpeechType => InhumanSpeech.Ratman;
    public override string CorpseName => $"a {DefaultName} corpse";
    public override bool CanRummageCorpses => true;
    public override int Meat => 1;
    public override int Hides => 9;
    public override HideType HideType => HideType.Spined;
    public override int TreasureMapLevel => 2;
    public override FoodType FavoriteFood => FoodType.Meat;

    protected void SetCombat(
        (int Min, int Max) physical, (int Min, int Max) fire, (int Min, int Max) cold,
        (int Min, int Max) poison, (int Min, int Max) energy,
        (double Min, double Max) wrestling, (double Min, double Max) tactics, (double Min, double Max) resist)
    {
        SetResistance(ResistanceType.Physical, physical.Min, physical.Max);
        SetResistance(ResistanceType.Fire, fire.Min, fire.Max);
        SetResistance(ResistanceType.Cold, cold.Min, cold.Max);
        SetResistance(ResistanceType.Poison, poison.Min, poison.Max);
        SetResistance(ResistanceType.Energy, energy.Min, energy.Max);
        SetSkill(SkillName.Wrestling, wrestling.Min, wrestling.Max);
        SetSkill(SkillName.Tactics, tactics.Min, tactics.Max);
        SetSkill(SkillName.MagicResist, resist.Min, resist.Max);
    }

    protected void EquipBow()
    {
        SetSkill(SkillName.Archery, 80.1, 90.0);
        AddItem(new Bow());
        PackItem(new Arrow(Utility.RandomMinMax(30, 60)));
    }

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}

[SerializationGenerator(0)]
public sealed partial class ClanChitterAssistant : CavernRatman
{
    [Constructible]
    public ClanChitterAssistant() : base(142, AIType.AI_Archer, (146, 172), (101, 126), (120, 131), (121, 143), (4, 10))
    {
        SetCombat((23, 34), (22, 27), (33, 49), (15, 19), (10, 19), (62.3, 74.5), (53.8, 74.5), (81.0, 89.2));
        EquipBow();
    }

    public override string DefaultName => "Clan Chitter Assistant";
}

[SerializationGenerator(0)]
public sealed partial class ClanChitterTinkerer : CavernRatman
{
    [Constructible]
    public ClanChitterTinkerer() : base(142, AIType.AI_Archer, (303, 328), (222, 238), (242, 271), (2027, 2068), (8, 10))
    {
        SetCombat((23, 29), (22, 30), (37, 48), (10, 18), (14, 20), (62.8, 82.6), (64.2, 84.4), (76.8, 93.3));
        EquipBow();
    }

    public override string DefaultName => "Clan Chitter Tinkerer";
}

[SerializationGenerator(0)]
public sealed partial class ClanRibbonSupplicant : CavernRatman
{
    [Constructible]
    public ClanRibbonSupplicant() : base(42, AIType.AI_Melee, (173, 173), (117, 117), (207, 207), (127, 127), (7, 14))
    {
        SetCombat((56, 56), (32, 32), (80, 80), (47, 47), (29, 29), (56.4, 56.4), (62.1, 62.1), (78.9, 78.9));
        SetDamageType(ResistanceType.Physical, 80);
        SetDamageType(ResistanceType.Cold, 20);
    }

    public override string DefaultName => "Clan Ribbon Supplicant";
}

[SerializationGenerator(0)]
public sealed partial class ClanRibbonCourtier : CavernRatman
{
    [Constructible]
    public ClanRibbonCourtier() : base(42, AIType.AI_Melee, (231, 231), (252, 252), (125, 125), (2054, 2193), (7, 14))
    {
        SetCombat((40, 45), (10, 20), (12, 20), (10, 20), (10, 20), (50.6, 50.6), (65, 65), (113.1, 113.1));
    }

    public override string DefaultName => "Clan Ribbon Courtier";
    public override void GenerateLoot() => AddLoot(LootPack.Average);
}

[SerializationGenerator(0)]
public sealed partial class ClanScratchScrounger : CavernRatman
{
    [Constructible]
    public ClanScratchScrounger() : base(42, AIType.AI_Melee, (97, 97), (98, 98), (49, 49), (135, 135), (4, 5))
    {
        SetCombat((26, 26), (22, 22), (49, 49), (14, 14), (10, 10), (72.8, 72.8), (59, 59), (49.9, 49.9));
        SetSkill(SkillName.Anatomy, 51.5);
    }

    public override string DefaultName => "Clan Scratch Scrounger";
    public override void GenerateLoot() => AddLoot(LootPack.Meager);
}

[SerializationGenerator(0)]
public sealed partial class ClanScratchHenchrat : CavernRatman
{
    [Constructible]
    public ClanScratchHenchrat() : base(42, AIType.AI_Melee, (227, 227), (183, 183), (93, 93), (2065, 2065), (5, 7))
    {
        SetCombat((26, 26), (29, 29), (32, 32), (17, 17), (13, 13), (64.2, 64.2), (61.1, 61.1), (35.4, 35.4));
        SetSkill(SkillName.Anatomy, 74.4);
    }

    public override string DefaultName => "Clan Scratch Henchrat";
    public override void GenerateLoot() => AddLoot(LootPack.Meager);
}
