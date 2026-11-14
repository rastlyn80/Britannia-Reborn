// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Commands;
using Server.Engines.PartySystem;
using Server.Gumps;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class BlightedGroveBasket : Item
{
    private static readonly Point3D BossHome = new(6483, 947, 23);
    private static readonly Point3D Arrival = new(6518, 946, 36);
    private static readonly Point3D Exit = new(587, 1641, -1);
    private static readonly Rectangle2D Chamber = new(6456, 922, 84, 47);

    [SerializableField(0)]
    private LadyMelisande? _boss;

    [SerializableField(1)]
    private DateTime _closes;

    [SerializableField(2)]
    private List<Mobile> _entrants = [];

    private TimerExecutionToken _timer;

    [Constructible]
    public BlightedGroveBasket() : base(0x207B) => Movable = false;

    public override string DefaultName => "the Frightened Dryad's basket";

    internal IReadOnlyList<Mobile> Fighters => _entrants;

    public static void Initialize() =>
        CommandSystem.Register("PlaceBlightedGroveBasket", AccessLevel.Administrator, Place);

    private static void Place(CommandEventArgs args)
    {
        var actor = args.Mobile;
        var map = actor.Map;
        var home = FrightenedDryad.GroveHome;
        if (map != Map.Trammel && map != Map.Felucca || !actor.Region.IsPartOf("Blighted Grove")
            || !actor.InRange(home, 2) || !map.CanFit(actor.Location, 16, checkMobiles: false))
        {
            actor.SendMessage("Stand on a clear tile beside the Frightened Dryad.");
            return;
        }
        foreach (var basket in map.GetItemsInRange<BlightedGroveBasket>(home, 2))
        {
            actor.SendMessage("The Frightened Dryad's basket is already in place.");
            return;
        }

        var placed = new BlightedGroveBasket();
        placed.MoveToWorld(actor.Location, map);
        actor.SendMessage("The Frightened Dryad's basket is in place.");
    }

    public override bool OnDragDrop(Mobile from, Item dropped)
    {
        if (!CanReach(from, 2) || dropped is not DryadsBlessing blessing || blessing.Expiration <= Core.Now)
        {
            return false;
        }

        CheckWindow();
        if (_closes != default || !Map.CanSpawnMobile(BossHome) || !Map.CanSpawnMobile(Arrival))
        {
            from.SendLocalizedMessage(1075213);
            return false;
        }
        var boss = new LadyMelisande { Home = BossHome, RangeHome = 12, Basket = this };
        var key = new DryadsCurse(this, boss);
        if (!from.PlaceInBackpack(key))
        {
            key.Delete();
            boss.Delete();
            return false;
        }

        blessing.Delete();
        _boss = boss;
        boss.MoveToWorld(BossHome, Map);
        boss.CallInitialSatyrs();
        _closes = Core.Now + TimeSpan.FromMinutes(10);
        BeginTimer();
        this.MarkDirty();
        return true;
    }

    internal void OfferAdmission(Mobile owner, DryadsCurse key)
    {
        if (!CanAdmit(owner, key))
        {
            return;
        }
        if (!_entrants.Contains(owner))
        {
            Offer(owner, owner, key);
        }
        if (Party.Get(owner) is { } party)
        {
            foreach (var member in party.Members)
            {
                if (member.Mobile != owner && !_entrants.Contains(member.Mobile) && CanReach(member.Mobile, 25))
                {
                    Offer(owner, member.Mobile, key);
                }
            }
        }
    }

    private void Offer(Mobile owner, Mobile entrant, DryadsCurse key)
    {
        entrant.SendGump(new WarningGump(1072680, 0x7FFF, "Enter Lady Melisande's lair?", 0x7FFF, 330, 170,
            accepted =>
            {
                if (accepted && CanAdmit(owner, key) && CanReach(entrant, 25) && !_entrants.Contains(entrant)
                    && (entrant == owner || Party.Get(owner) is { } party && Party.Get(entrant) == party))
                {
                    if (_entrants.Count == 0)
                    {
                        _closes = Core.Now + TimeSpan.FromMinutes(90);
                    }
                    _entrants.Add(entrant);
                    this.MarkDirty();
                    BaseCreature.TeleportPets(entrant, Arrival, Map);
                    entrant.MoveToWorld(Arrival, Map);
                }
            }));
    }

    private bool CanAdmit(Mobile owner, DryadsCurse key) =>
        !Deleted && !key.Deleted && key.Expiration > Core.Now && key.IsChildOf(owner.Backpack)
        && _boss is { Alive: true, Deleted: false } && _boss == key.Boss && Core.Now < _closes
        && (CanReach(owner, 25) || _entrants.Contains(owner) && owner.Map == Map && Chamber.Contains(owner.Location));

    private bool CanReach(Mobile actor, int range) =>
        actor is PlayerMobile { Alive: true } && actor.Map == Map && (Map == Map.Trammel || Map == Map.Felucca)
        && actor.Region.IsPartOf("Blighted Grove") && actor.InRange(GetWorldLocation(), range)
        && (range > 2 || actor.InLOS(this));

    [AfterDeserialization]
    private void BeginTimer()
    {
        if (_boss is { Deleted: false })
        {
            _boss.Basket = this;
        }
        if (_closes != default)
        {
            Timer.StartTimer(TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5), CheckWindow, out _timer);
        }
    }

    private void CheckWindow()
    {
        if (_closes == default)
        {
            return;
        }
        if (_boss is null or { Deleted: true } && _entrants.Count > 0 && _closes > Core.Now + TimeSpan.FromMinutes(15))
        {
            _closes = Core.Now + TimeSpan.FromMinutes(15);
            this.MarkDirty();
        }
        if (Core.Now >= _closes)
        {
            CloseEncounter();
        }
    }

    private void CloseEncounter()
    {
        foreach (var entrant in _entrants)
        {
            if (entrant.Deleted)
            {
                continue;
            }
            if (entrant.Map == Map && Chamber.Contains(entrant.Location))
            {
                BaseCreature.TeleportPets(entrant, Exit, Map);
                entrant.MoveToWorld(Exit, Map);
            }
            else if (entrant.Map == Map.Internal && entrant.LogoutMap == Map && Chamber.Contains(entrant.LogoutLocation))
            {
                entrant.LogoutLocation = Exit;
            }
        }
        _entrants.Clear();
        _boss?.Delete();
        _boss = null;
        _closes = default;
        _timer.Cancel();
        this.MarkDirty();
    }

    public override void OnDelete()
    {
        CloseEncounter();
        base.OnDelete();
    }
}

[SerializationGenerator(0)]
public sealed partial class DryadsCurse : TransientItem
{
    [SerializableField(0)]
    private BlightedGroveBasket? _basket;

    [SerializableField(1)]
    private LadyMelisande? _boss;

    internal DryadsCurse(BlightedGroveBasket basket, LadyMelisande boss) : base(0x021C, TimeSpan.FromMinutes(10))
    {
        _basket = basket;
        _boss = boss;
        LootType = LootType.Blessed;
    }

    public override int LabelNumber => 1074346;

    public override void OnDoubleClick(Mobile from) => _basket?.OfferAdmission(from, this);
}
