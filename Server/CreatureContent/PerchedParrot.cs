// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;
using Server.Network;
using Server.Multis;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public sealed partial class PerchedParrot : BaseCreature
{
    internal const string Unnamed = "a pet parrot";

    [SerializableField(0, getter: "public", setter: "private")]
    private DateTime _birth;

    internal PerchedParrot(int hue, string? name, DateTime? birth) : base(AIType.AI_Animal, FightMode.None)
    {
        Body = 282;
        Hue = hue;
        Name = name ?? Unnamed;
        Title = "the parrot";
        _birth = birth ?? Core.Now;
        BaseSoundID = 0xBF;
        KeepOnPerch();
        SetStr(1, 5);
        SetDex(25, 30);
        SetInt(2);
        SetHits(1, Str);
        SetStam(25, Dex);
        SetMana(0);
        SetResistance(ResistanceType.Physical, 2);
        SetSkill(SkillName.MagicResist, 4);
        SetSkill(SkillName.Tactics, 4);
        SetSkill(SkillName.Wrestling, 4);
    }

    public override string DefaultName => Unnamed;
    public override bool NoHouseRestrictions => true;
    public override FoodType FavoriteFood => FoodType.FruitsAndVeggies;
    public override bool CanBeRenamedBy(Mobile from) => from.AccessLevel > AccessLevel.Player ||
        BaseHouse.FindHouseAt(this)?.IsCoOwner(from) == true;

    public override void OnStatsQuery(Mobile from)
    {
        if (from.AccessLevel == AccessLevel.Player && from.Map == Map &&
            Utility.InUpdateRange(Location, from.Location) && from.CanSee(this) && CanBeRenamedBy(from))
        {
            from.SendLocalizedMessage(1072625);
        }
        base.OnStatsQuery(from);
    }

    public override bool HandlesOnSpeech(Mobile from) =>
        from.Player && from.Alive && from.InRange(this, 12) && from.InLOS(this);

    public override void OnSpeech(SpeechEventArgs speech)
    {
        if (speech.Type is MessageType.Regular or MessageType.Whisper or MessageType.Yell &&
            Utility.RandomDouble() < 0.05)
        {
            Say(speech.Speech);
            PlaySound(0xC0);
        }
    }

    public override bool OnDragDrop(Mobile from, Item dropped)
    {
        if (dropped is not ParrotWafer)
        {
            return false;
        }

        dropped.Consume();
        if (!dropped.Deleted)
        {
            from.AddToBackpack(dropped);
        }
        var phrase = Utility.RandomMinMax(1072602, 1072607);
        if (phrase == 1072602)
        {
            Say(phrase, $"#{Utility.RandomMinMax(1012003, 1012010)}");
        }
        else
        {
            Say(phrase);
        }
        PlaySound(Utility.RandomMinMax(0xBF, 0xC3));
        Direction = Utility.GetDirection(Location, from.Location);
        return true;
    }

    [AfterDeserialization]
    private void KeepOnPerch()
    {
        CantWalk = true;
        Frozen = true;
        Blessed = true;
    }

    public override void GetProperties(IPropertyList list)
    {
        base.GetProperties(list);
        var weeks = (int)((Core.Now - _birth).TotalDays / 7);
        if (weeks == 1)
        {
            list.Add(1072626);
        }
        else if (weeks > 1)
        {
            list.Add(1072627, $"{weeks}");
        }
    }
}

