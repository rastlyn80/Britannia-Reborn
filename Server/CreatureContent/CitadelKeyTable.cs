// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using System.Collections.Generic;
using ModernUO.Serialization;
using Server.Engines.PartySystem;
using Server.Gumps;
using Server.Mobiles;

namespace Server.Items;

[SerializationGenerator(1)]
public partial class CitadelKeyTable : Item
{
    public static readonly Point3D BossLocation = new(86, 1955, 0);
    public static readonly Point3D Arrival = new(111, 1955, 0);
    private static readonly Point3D Exit = new(1355, 779, 17);
    private static readonly Rectangle2D Chamber = new(66, 1936, 51, 39);
    private TimerExecutionToken _lifecycle;

    [SerializableField(0)]
    private Travesty? _activeBoss;
    [SerializableField(1)]
    private Mobile? _offeringOwner;
    [SerializableField(2)]
    private int _offeredKeys;
    [SerializableField(3)]
    private DateTime _offeringCloses;
    [SerializableField(4)]
    private DateTime _encounterCloses;
    [SerializableField(5)]
    private List<Mobile> _entrants = [];
    [SerializableField(6)]
    private bool _awaitingFirstEntry;

    [Constructible]
    public CitadelKeyTable() : base(0x207E)
    {
        Movable = false;
    }

    public override string DefaultName => "Citadel key table";

    public override void OnDoubleClick(Mobile from)
    {
        if (CanReachTable(from, 2))
        {
            from.SendMessage("Place each of the three Citadel keys on the table.");
        }
    }

    public override bool OnDragDrop(Mobile from, Item dropped)
    {
        if (!CanReachTable(from, 2))
        {
            return false;
        }

        UpdateEncounter();
        if (_activeBoss != null || _offeringOwner != null && _offeringOwner != from)
        {
            from.SendLocalizedMessage(1075213);
            return false;
        }

        var key = dropped switch
        {
            SerpentFangKey => 1,
            TigerClawKey => 2,
            DragonFlameKey => 4,
            _ => 0
        };
        if (key == 0 || (_offeredKeys & key) != 0)
        {
            from.SendLocalizedMessage(1072682);
            return false;
        }

        var completesOffering = (_offeredKeys | key) == 7;
        if (completesOffering && (!Map.CanSpawnMobile(BossLocation) || !Map.CanSpawnMobile(Arrival)))
        {
            from.SendMessage("The passage to Travesty is unavailable.");
            return false;
        }
        if (_offeringOwner == null)
        {
            _offeringOwner = from;
            _offeringCloses = Core.Now + TimeSpan.FromSeconds(90);
            StartLifecycle();
            from.SendLocalizedMessage(1074575);
        }

        _offeredKeys |= key;
        dropped.Delete();
        if (completesOffering)
        {
            OpenEncounter(from);
        }
        this.MarkDirty();
        return true;
    }

    private void OpenEncounter(Mobile from)
    {
        _offeredKeys = 0;
        _offeringOwner = null;
        _offeringCloses = default;
        _activeBoss = new Travesty { Home = BossLocation, RangeHome = 12, KeyTable = this };
        _activeBoss.MoveToWorld(BossLocation, Map);
        _awaitingFirstEntry = true;
        _encounterCloses = Core.Now + TimeSpan.FromMinutes(10);
        from.SendLocalizedMessage(1072678);
        for (var index = 0; index < 3; index++)
        {
            from.AddToBackpack(new CitadelAdmissionKey(this, _activeBoss));
            from.SendLocalizedMessage(1072680);
        }
    }

    internal void OfferAdmission(Mobile from, CitadelAdmissionKey key)
    {
        if (!CanUseAdmission(from, key) || !CanReachTable(from, 25))
        {
            return;
        }

        var offered = new List<Mobile> { from };
        if (Party.Get(from) is { } party)
        {
            foreach (var member in party.Members)
            {
                var mobile = member.Mobile;
                if (mobile != from && CanReachTable(mobile, 25) && from.InRange(mobile, 25))
                {
                    offered.Add(mobile);
                }
            }
        }
        foreach (var mobile in offered)
        {
            mobile.SendGump(new WarningGump(1072680, 0x7FFF, "Enter Travesty's chamber?", 0x7FFF, 330, 170,
                confirmed =>
                {
                    if (confirmed)
                    {
                        Admit(from, mobile, key);
                    }
                }));
        }
    }

    private void Admit(Mobile owner, Mobile entrant, CitadelAdmissionKey key)
    {
        if (!CanUseAdmission(owner, key) || !CanReachTable(entrant, 25) ||
            entrant != owner && (Party.Get(owner) is not { } party || Party.Get(entrant) != party) ||
            _entrants.Contains(entrant))
        {
            return;
        }

        if (_awaitingFirstEntry)
        {
            _awaitingFirstEntry = false;
            _encounterCloses = Core.Now + TimeSpan.FromMinutes(90);
        }
        _entrants.Add(entrant);
        this.MarkDirty();
        BaseCreature.TeleportPets(entrant, Arrival, Map);
        entrant.MoveToWorld(Arrival, Map);
    }

    private bool CanUseAdmission(Mobile from, CitadelAdmissionKey key) =>
        !Deleted && !key.Deleted && key.Expiration > Core.Now && key.Table == this && key.IsChildOf(from.Backpack)
        && _activeBoss == key.Boss && _activeBoss is { Alive: true, Deleted: false }
        && Core.Now < _encounterCloses;

    private bool CanReachTable(Mobile from, int range) =>
        from is PlayerMobile { Alive: true } && from.Map == Map && Map == Map.Malas
        && from.Region.IsPartOf("The Citadel") && from.InRange(GetWorldLocation(), range)
        && (range > 2 || from.InLOS(this));

    internal void BossDefeated(Travesty boss)
    {
        if (_activeBoss == boss)
        {
            _awaitingFirstEntry = false;
            _encounterCloses = Core.Now + TimeSpan.FromMinutes(15);
            this.MarkDirty();
        }
    }

    private void StartLifecycle()
    {
        _lifecycle.Cancel();
        Timer.StartTimer(TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5), UpdateEncounter, out _lifecycle);
    }

    private void UpdateEncounter()
    {
        var now = Core.Now;
        if (_offeredKeys != 0 && (now >= _offeringCloses || _offeringOwner is not { Deleted: false }))
        {
            _offeringOwner?.SendLocalizedMessage(1072679);
            _offeringOwner = null;
            _offeredKeys = 0;
            _offeringCloses = default;
            this.MarkDirty();
        }
        if (_encounterCloses != default && now >= _encounterCloses)
        {
            CloseEncounter();
        }
        if (_offeringOwner == null && _encounterCloses == default)
        {
            _lifecycle.Cancel();
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

            if (entrant.Map == Map.Malas && Chamber.Contains(entrant.Location))
            {
                BaseCreature.TeleportPets(entrant, Exit, Map.Tokuno);
                entrant.MoveToWorld(Exit, Map.Tokuno);
            }
            else if (entrant.Map == Map.Internal && entrant.LogoutMap == Map.Malas && Chamber.Contains(entrant.LogoutLocation))
            {
                entrant.LogoutMap = Map.Tokuno;
                entrant.LogoutLocation = Exit;
            }
        }
        _entrants.Clear();
        _activeBoss?.RemoveReinforcements();
        if (_activeBoss is { Alive: true })
        {
            _activeBoss.Delete();
        }
        _activeBoss = null;
        _encounterCloses = default;
        _awaitingFirstEntry = false;
        this.MarkDirty();
    }

    public override void OnDelete()
    {
        _lifecycle.Cancel();
        CloseEncounter();
        base.OnDelete();
    }

    private void MigrateFrom(V0Content content)
    {
        _activeBoss = content.ActiveBoss;
        if (_activeBoss is { Alive: true })
        {
            _encounterCloses = Core.Now + TimeSpan.FromMinutes(90);
        }
    }

    [AfterDeserialization]
    private void ResumeLifecycle()
    {
        if (_activeBoss is { Alive: true })
        {
            _activeBoss.KeyTable = this;
        }
        if (_offeredKeys != 0 || _encounterCloses != default)
        {
            StartLifecycle();
        }
    }
}
