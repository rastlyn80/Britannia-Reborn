// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Gumps;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class SutekTrainingMechanism : Item
{
    private const int RequiredIngredients = 20;
    private static readonly (int Body, int Label, string Name)[] _constructs =
    [
        (756, 1075914, "an exodus overseer"),
        (767, 1029734, "a betrayer"),
        (717, 1112861, "a clockwork scorpion"),
        (293, 1112860, "a vollem"),
        (768, 1029746, "a juggernaut"),
        (757, 1075915, "an exodus minion"),
        (739, 1112859, "a leather wolf")
    ];

    [SerializableField(0)]
    private int _constructIndex;
    [SerializableField(1)]
    private int _ingredient;
    [SerializableField(2)]
    private int _collected;
    [SerializableField(3)]
    private DateTime _deadline;

    private TimerExecutionToken _expiry;

    [Constructible]
    public SutekTrainingMechanism() : base(0x1EAE)
    {
        _constructIndex = Utility.Random(_constructs.Length);
        Hue = 0x450;
    }

    public override bool Nontransferable => true;
    public override double DefaultWeight => 1.0;
    public override int LabelNumber => 1112858;

    public override void AddNameProperty(IPropertyList list) =>
        list.Add(LabelNumber, $"#{_constructs[_constructIndex].Label}");

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not PlayerMobile { Alive: true } player || !IsChildOf(player.Backpack) ||
            !PerfectTiming.IsActive(player) || !SutekWorkshop.IsInWorkshop(player))
        {
            return;
        }
        if (_ingredient != 0)
        {
            if (_deadline <= Core.Now)
            {
                Expire();
            }
            else
            {
                Hint(player);
            }
            return;
        }

        player.SendGump(new WarningGump(1112855, 0x7FFF, 1112856, 0x7FFF, 330, 170, accepted =>
        {
            if (accepted && !Deleted && _ingredient == 0 && player.Alive && IsChildOf(player.Backpack) &&
                SutekWorkshop.IsInWorkshop(player) && PerfectTiming.IsActive(player))
            {
                RequestIngredient(player);
            }
        }));
    }

    internal void AddIngredient(PlayerMobile player, int label)
    {
        if (_ingredient == 0 || !PerfectTiming.IsActive(player))
        {
            return;
        }
        if (_deadline <= Core.Now)
        {
            Expire();
            return;
        }
        if (_ingredient != label)
        {
            player.SendLocalizedMessage(1112820);
            Hint(player);
            return;
        }

        player.SendLocalizedMessage(1112819);
        _collected++;
        if (_collected < RequiredIngredients)
        {
            RequestIngredient(player);
            return;
        }

        var (body, _, name) = _constructs[_constructIndex];
        var place = player.Location;
        var map = player.Map;
        Delete();
        player.AddToBackpack(new CompletedTrainingAssembly());
        var construct = new SutekTrainingConstruct(body, name);
        construct.MoveToWorld(place, map);
        Effects.SendLocationEffect(place, map, 0x1FD4, 30, 16, 0x21, 4);
        player.PlaySound(0x5C7);
        Timer.StartTimer(TimeSpan.FromSeconds(5), () =>
        {
            if (!player.Deleted)
            {
                player.SendLocalizedMessage(1112987);
            }
        });
    }

    private void Hint(PlayerMobile player) => player.SendLocalizedMessage(1112821, $"#{_ingredient}");

    private void RequestIngredient(PlayerMobile player)
    {
        _ingredient = SutekWorkshop.NextIngredient();
        _deadline = Core.Now + TimeSpan.FromSeconds(15);
        this.MarkDirty();
        ResumeExpiry();
        Hint(player);
    }

    private void Expire()
    {
        if (RootParent is PlayerMobile player)
        {
            player.SendLocalizedMessage(1112822);
        }
        Delete();
    }

    [AfterDeserialization]
    private void ResumeExpiry()
    {
        _expiry.Cancel();
        if (_ingredient != 0)
        {
            Timer.StartTimer(Utility.Max(_deadline - Core.Now, TimeSpan.Zero), Expire, out _expiry);
        }
    }

    public override void OnDelete()
    {
        _expiry.Cancel();
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public partial class SutekWorkshopIngredient : Item
{
    [SerializableField(0)]
    private int _label;

    internal SutekWorkshopIngredient(int graphic, int label, int hue) : base(graphic)
    {
        _label = label;
        Hue = hue;
        Movable = false;
    }

    public override int LabelNumber => _label;

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not PlayerMobile { Alive: true, Backpack: { } pack } player || !SutekWorkshop.IsInWorkshop(player))
        {
            return;
        }
        if (!player.InRange(this, 2) || !player.InLOS(this))
        {
            player.SendLocalizedMessage(1019045);
            return;
        }
        pack.FindItemByType<SutekTrainingMechanism>()?.AddIngredient(player, _label);
    }
}

[SerializationGenerator(0)]
public partial class CompletedTrainingAssembly : Item
{
    [Constructible]
    public CompletedTrainingAssembly() : base(0x1EAE)
    {
    }

    public override bool Nontransferable => true;
    public override int LabelNumber => 1112879;
}

[SerializationGenerator(0)]
public partial class SuteksDirtyGear : Item
{
    [Constructible]
    public SuteksDirtyGear() : base(0x1053) => Hue = 1102;

    public override int LabelNumber => 1115722;

    public override void OnDoubleClick(Mobile from)
    {
        if (from is not { Alive: true, Backpack: { } pack } || !IsChildOf(pack))
        {
            return;
        }

        var gear = Utility.RandomDouble() < 0.05 ? DawnsMusicGear.RandomRare :
            Utility.RandomBool() ? DawnsMusicGear.RandomCommon : DawnsMusicGear.RandomUncommon;
        if (pack.TryDropItem(from, gear, true))
        {
            from.SendLocalizedMessage(1115723);
            Delete();
        }
        else
        {
            gear.Delete();
        }
    }
}
