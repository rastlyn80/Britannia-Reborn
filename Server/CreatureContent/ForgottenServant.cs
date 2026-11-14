// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class ForgottenServant : BaseCreature
{
    [Constructible]
    public ForgottenServant() : base(AIType.AI_Melee, FightMode.Closest, 10, 1)
    {
        Female = Utility.RandomBool();
        Body = Race.Human.Body(this);
        Name = NameList.RandomName(Female ? "female" : "male");
        Title = "Forgotten Servant";
        Hue = 768;
        SpeechHue = Utility.RandomDyedHue();
        Utility.AssignRandomHair(this);

        AddItem(Female ? new Skirt(Utility.RandomNeutralHue()) : new ShortPants(Utility.RandomNeutralHue()));
        AddItem(new Boots(Utility.RandomNeutralHue()));
        AddItem(new FancyShirt());
        AddItem(new Bandana());
        AddItem(CreateWeapon());

        SetStr(147, 215);
        SetDex(91, 115);
        SetInt(61, 85);
        SetHits(95, 123);
        SetDamage(4, 14);
        SetResistance(ResistanceType.Physical, 25, 35);
        SetResistance(ResistanceType.Fire, 30, 40);
        SetResistance(ResistanceType.Cold, 20, 30);
        SetResistance(ResistanceType.Poison, 30, 40);
        SetResistance(ResistanceType.Energy, 30, 40);
        SetSkill(SkillName.MagicResist, 70.1, 85.0);
        SetSkill(SkillName.Swords, 60.1, 85.0);
        SetSkill(SkillName.Tactics, 75.1, 90.0);
        SetSkill(SkillName.Wrestling, 60.1, 85.0);
        Fame = 2500;
        Karma = -2500;
    }

    public override bool AlwaysMurderer => true;
    public override bool ClickTitle => false;

    public override void GenerateLoot() => AddLoot(LootPack.Average);

    public override void GetSpeeds(out double activeSpeed, out double passiveSpeed)
    {
        activeSpeed = 0.2;
        passiveSpeed = 0.4;
    }

    private static BaseWeapon CreateWeapon() => Utility.Random(7) switch
    {
        0 => new Longsword(),
        1 => new Cutlass(),
        2 => new Broadsword(),
        3 => new Axe(),
        4 => new Club(),
        5 => new Dagger(),
        _ => new Spear()
    };
}
