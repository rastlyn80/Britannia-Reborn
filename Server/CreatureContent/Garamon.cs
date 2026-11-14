// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Items;

namespace Server.Mobiles;

[SerializationGenerator(0)]
public partial class Garamon : BaseCreature
{
    [Constructible]
    public Garamon() : base(AIType.AI_Vendor, FightMode.None, 2)
    {
        Race = Race.Human;
        Body = 0x190;
        Hue = 33821;
        HairItemID = 0x2044;
        HairHue = 0x44E;
        FacialHairItemID = 0x204B;
        Direction = Direction.South;
        CantWalk = true;
        InitStats(100, 100, 100);
        AddItem(new Shoes(1810));
        AddItem(new Robe(946));
    }

    public override string DefaultName => "Garamon";
    public override bool IsInvulnerable => true;

    public override bool HandlesOnSpeech(Mobile from) => CanSpeakWith(from) || base.HandlesOnSpeech(from);

    public override void OnSpeech(SpeechEventArgs speech)
    {
        if (!speech.Handled && CanSpeakWith(speech.Mobile))
        {
            var reply = speech.Speech.Trim().TrimEnd('?', '!', '.').ToLowerInvariant() switch
            {
                "hello" => "Welcome, traveller. Ask me about the Abyss.",
                "abyss" or "stone guardian" => "Stone guardians bar the Abyss. You must show them a Tripartite Key.",
                "key" or "parts" => "Two parts lie in secret rooms here. A shadow of evil holds the third.",
                "secret" => "Examine the walls. Something growing on them may conceal a passage.",
                "vines" => "Those vines can be burned away. Find something in the dungeon that will do it.",
                "burn" => "Fire will not help. Try what you can recover from the creatures deeper inside.",
                "shadow of evil" => "Bring both pieces to the Shrine beyond the void and challenge the traitor there.",
                "shrine" or "teleporter" => "Use the dungeon teleporters to reach the Shrine beyond the void.",
                _ => null
            };
            if (reply != null)
            {
                Say(reply);
                speech.Handled = true;
            }
        }

        base.OnSpeech(speech);
    }

    private bool CanSpeakWith(Mobile from) =>
        from is PlayerMobile { Alive: true } && from.Map == Map && from.InRange(this, 2) && from.InLOS(this);
}
