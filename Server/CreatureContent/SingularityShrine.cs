// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Gumps;
using Server.Mobiles;
using Server.Network;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class SingularityShrine : Item
{
    public static readonly Point3D Altar = new(995, 3802, -24);

    [Constructible]
    public SingularityShrine() : base(0x1BC3)
    {
        Visible = false;
        Movable = false;
    }

    public override bool HandlesOnSpeech => true;

    public override void OnSpeech(SpeechEventArgs e)
    {
        if (e.Mobile is not PlayerMobile player || !CanReach(player) ||
            !e.Speech.Trim().Equals("unorus", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        if (AbyssAdmission.HasAccess(player) || !TheArisen.IsCompletedBy(player) || !AbyssAdmission.ShrineCanRetry(player))
        {
            player.SendLocalizedMessage(1112683);
            return;
        }

        player.SendLocalizedMessage(1112697);
        player.CloseGump<TrialGump>();
        player.SendGump(new TrialGump(this, player, Offer, []));
    }

    public static void Initialize() =>
        CommandSystem.Register("PlaceSingularityShrine", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = Map.TerMur;
        if (actor.Map != map || !actor.InRange(Altar, 5) || Math.Abs(actor.Z - Altar.Z) > 8)
        {
            actor.SendMessage("Stand near the altar at the Shrine of Singularity.");
            return;
        }

        foreach (var shrine in map.GetItemsInRange<SingularityShrine>(Altar, 0))
        {
            actor.SendMessage("The shrine already listens for the mantra.");
            return;
        }

        new SingularityShrine().MoveToWorld(Altar, map);
        actor.SendMessage("The shrine now listens for the mantra.");
    }

    private bool CanReach(PlayerMobile player) => !Deleted && player.Alive && player.Map == Map &&
        player.InRange(this, 3) && Math.Abs(Z - player.Z) <= 5;

    private const int Offer = -1;
    private const int Failed = -2;
    private const int Completed = -3;
    private const int RequiredAnswers = 4;
    private readonly record struct Question(int Text, int Correct, int[] Options);

    private static readonly Question[] _questions =
    [
        new(1112601, 1112628, [1112632, 1112633, 1112628, 1112636]),
        new(1112602, 1112628, [1112628, 1112634, 1112629, 1112630]),
        new(1112603, 1112632, [1112632, 1112635, 1112633, 1112628]),
        new(1112604, 1112633, [1112638, 1112639, 1112628, 1112633]),
        new(1112605, 1112641, [1112652, 1112641, 1112645, 1112644]),
        new(1112606, 1112649, [1112644, 1112641, 1112646, 1112649]),
        new(1112607, 1112640, [1112653, 1112640, 1112655, 1112654])
    ];

    private sealed class TrialGump(SingularityShrine shrine, PlayerMobile player, int step, Question[] questions)
        : DynamicGump(85, 70)
    {
        protected override void BuildLayout(ref DynamicGumpBuilder builder)
        {
            builder.AddPage();
            builder.AddBackground(0, 0, 410, 250, 5054);
            builder.AddHtmlLocalized(25, 15, 355, 23, 1112681, 0x7FFF);
            var description = step switch
            {
                Offer => 1112682,
                Failed => 1112680,
                Completed => 1112700,
                _ => questions[step].Text
            };
            builder.AddHtmlLocalized(25, 45, 355, step < 0 ? 150 : 42, description, 0x7FFF);
            if (step >= 0)
            {
                var options = questions[step].Options;
                for (var i = 0; i < options.Length; i++)
                {
                    var y = 90 + 30 * i;
                    builder.AddButton(25, y, 4005, 4007, i + 1);
                    builder.AddHtmlLocalized(60, y, 325, 22, options[i], 0x7FFF);
                }
            }
            else
            {
                builder.AddButton(25, 215, 4005, 4007, step == Offer ? 1 : 0);
                builder.AddHtmlLocalized(60, 215, 300, 24, step == Offer ? 1011037 : 1011036, 0x7FFF);
            }
        }

        public override void OnResponse(NetState sender, in RelayInfo info)
        {
            if (sender.Mobile != player || !shrine.CanReach(player) || !TheArisen.IsCompletedBy(player) ||
                AbyssAdmission.HasAccess(player) || !AbyssAdmission.ShrineCanRetry(player) || info.ButtonID < 1)
            {
                return;
            }

            if (step == Offer && info.ButtonID == 1)
            {
                var ordered = (Question[])_questions.Clone();
                ordered.Shuffle();
                player.SendGump(new TrialGump(shrine, player, 0, ordered));
            }
            else if (step >= 0 && info.ButtonID <= questions[step].Options.Length)
            {
                var correct = questions[step].Options[info.ButtonID - 1] == questions[step].Correct;
                if (!correct)
                {
                    AbyssAdmission.FailShrineTrial(player);
                    player.SendGump(new TrialGump(shrine, player, Failed, []));
                }
                else if (step + 1 == RequiredAnswers)
                {
                    AbyssAdmission.CompleteShrineTrial(player);
                    player.SendGump(new TrialGump(shrine, player, Completed, []));
                }
                else
                {
                    player.SendGump(new TrialGump(shrine, player, step + 1, questions));
                }
            }
        }
    }
}
