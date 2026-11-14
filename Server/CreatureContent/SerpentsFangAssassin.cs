// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Engines.MLQuests.Definitions;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class SerpentsFangAssassin : BaseCreature
{
    private const int DarkClothHue = 0x51D;
    private const int RedTrimHue = 0x2A;

    [Constructible]
    public SerpentsFangAssassin() : this(RedTrimHue, new Sai { Hue = DarkClothHue }, "of the Serpent's Fang Sect")
    {
    }

    protected SerpentsFangAssassin(int trimHue, BaseWeapon weapon, string title)
        : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Female = Utility.RandomBool();
        Body = Race.Human.Body(this);
        Title = title;
        Hue = Race.RandomSkinHue();
        Utility.AssignRandomHair(this);
        Race.RandomFacialHair(this);

        AddItem(new FancyShirt(DarkClothHue));
        AddItem(new ThighBoots(DarkClothHue));
        AddItem(new JinBaori(trimHue));
        AddItem(new StuddedMempo());
        AddItem(new StuddedGloves { Hue = trimHue });
        AddItem(new LeatherNinjaPants { Hue = DarkClothHue });
        AddItem(new LightPlateJingasa { Hue = DarkClothHue });
        AddItem(weapon);

        Fame = 13000;
        Karma = -13000;
        VirtualArmor = 58;
        SetStr(440, 460);
        SetDex(160, 175);
        SetInt(160, 175);
        SetHits(440, 500);
        SetDamage(13, 15);
        SetResistance(ResistanceType.Physical, 65, 75);
        SetResistance(ResistanceType.Fire, 50, 60);
        SetResistance(ResistanceType.Cold, 55, 60);
        SetResistance(ResistanceType.Poison, 30, 50);
        SetResistance(ResistanceType.Energy, 30, 50);
        SetSkill(SkillName.MagicResist, 80.0, 100.0);
        SetSkill(SkillName.Tactics, 115.0, 130.0);
        SetSkill(SkillName.Wrestling, 95.0, 120.0);
        SetSkill(SkillName.Anatomy, 105.0, 120.0);
        SetSkill(SkillName.Fencing, 78.0, 100.0);
        SetSkill(SkillName.Swords, 90.1, 105.0);
        SetSkill(SkillName.Ninjitsu, 90.0, 120.0);
        SetSkill(SkillName.Hiding, 100.0, 120.0);
        SetSkill(SkillName.Stealth, 100.0, 120.0);
    }

    public override string DefaultName => "Black Order Assassin";
    public override string CorpseName => "a black order assassin corpse";
    public override bool AlwaysMurderer => true;
    public override bool ShowFameTitle => false;
    protected virtual double SectBadgeChance => 0.30;
    protected virtual Item CreateSectBadge() => new SerpentFangSectBadge();

    public override void OnKilledBy(Mobile killer)
    {
        base.OnKilledBy(killer);
        CitadelMaleSectObjective.Credit(this, killer);
    }

    public override void OnDeath(Container corpse)
    {
        base.OnDeath(corpse);
        if (Utility.RandomDouble() < SectBadgeChance)
        {
            corpse.DropItem(CreateSectBadge());
        }
    }

    public override void GenerateLoot() => AddLoot(LootPack.FilthyRich, 4);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }
}
