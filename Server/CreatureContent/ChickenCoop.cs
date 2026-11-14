// SPDX-License-Identifier: GPL-3.0-or-later
using System.Collections.Generic;
using ModernUO.Serialization;
using Server.Collections;
using Server.ContextMenus;
using Server.Engines.Craft;
using Server.Gumps;
using Server.Mobiles;
using Server.Multis;
using Server.Targeting;

namespace Server.Items;

[Flippable(0x4513, 0x4514)]
[SerializationGenerator(0)]
public partial class ChickenCoop : Item, ISecurable
{
    private const int Capacity = 3;

    [SerializableField(0)]
    private SecureLevel _level;

    [SerializableField(1)]
    private List<Mobile> _birds = [];

    [SerializableField(2)]
    private List<Mobile> _birdOwners = [];

    [AfterDeserialization]
    private void RestoreStabledBirds()
    {
        Timer.DelayCall(TimeSpan.Zero, () =>
        {
            if (Deleted)
            {
                return;
            }

            for (var index = 0; index < _birds.Count; index++)
            {
                if (_birds[index] is BaseCreature { Deleted: false, Map: var map } pet && map == Map.Internal)
                {
                    pet.IsStabled = true;
                    pet.StabledBy = _birdOwners[index];
                }
            }
        });
    }

    [Constructible]
    public ChickenCoop() : base(0x4513)
    {
        Level = SecureLevel.CoOwners;
    }

    public override int LabelNumber => 1112570;
    public override double DefaultWeight => 20;

    public static void Configure() => EventSink.ServerStarted += RegisterRecipes;

    private static void RegisterRecipes()
    {
        if (Core.SA && DefCarpentry.CraftSystem is { } craft)
        {
            craft.AddCraft(typeof(ChickenIncubator), 1044294, 1112479, 90.0, 115.0, typeof(Board), 1044041, 100, 1044351);
            craft.AddCraft(typeof(ChickenCoop), 1044294, 1112570, 90.0, 115.0, typeof(Board), 1044041, 150, 1044351);
        }
    }

    private bool CanUse(Mobile from) =>
        !Deleted && Parent == null && from.Alive && from.Map == Map && from.InRange(Location, 2) && from.InLOS(this) &&
        BaseHouse.FindHouseAt(this) is { } house && (house.HasSecureItem(this) || house.HasLockedDownItem(this)) &&
        house.HasSecureAccess(from, Level);

    public override void GetContextMenuEntries(Mobile from, ref PooledRefList<ContextMenuEntry> list)
    {
        base.GetContextMenuEntries(from, ref list);
        if (CanUse(from))
        {
            SetSecureLevelEntry.AddTo(from, this, ref list);
            list.Add(new CoopEntry(this, 6126, stable: true));
            if (_birds.Exists(pet => pet is BaseCreature { Deleted: false } bird && bird.StabledBy == from))
            {
                list.Add(new CoopEntry(this, 6127, stable: false));
            }
        }
    }

    private void BeginStable(Mobile from)
    {
        if (CanUse(from))
        {
            from.SendLocalizedMessage(1112559);
            from.BeginTarget(2, false, TargetFlags.None, Stable);
        }
    }

    private void Stable(Mobile from, object selected)
    {
        if (!CanUse(from))
        {
            return;
        }

        if (selected is not BaseCreature pet || pet is not (Chicken or ChickenLizardBase))
        {
            from.SendLocalizedMessage(1112558);
            return;
        }

        if (!pet.Controlled || pet.ControlMaster != from || pet.Summoned || !pet.Alive || pet.IsDeadBondedPet)
        {
            from.SendLocalizedMessage(1042562);
            return;
        }

        if (pet.Combatant is { } opponent && pet.InRange(opponent, 12))
        {
            from.SendLocalizedMessage(1042564);
            return;
        }

        for (var index = _birds.Count - 1; index >= 0; index--)
        {
            if (_birds[index] is not { Deleted: false })
            {
                RemoveBird(index);
            }
        }
        if (_birds.Count >= Capacity)
        {
            from.SendLocalizedMessage(1114325);
            return;
        }

        pet.Internalize();
        pet.SetControlMaster(null);
        pet.IsStabled = true;
        pet.StabledBy = from;
        _birds.Add(pet);
        _birdOwners.Add(from);
        this.MarkDirty();
        from.SendLocalizedMessage(1049677);
    }

    private void Claim(Mobile from)
    {
        if (!CanUse(from))
        {
            return;
        }

        var claimed = false;
        for (var index = _birds.Count - 1; index >= 0; index--)
        {
            if (_birds[index] is not BaseCreature { Deleted: false } pet)
            {
                RemoveBird(index);
                continue;
            }

            if (pet.StabledBy != from || !pet.SetControlMaster(from))
            {
                continue;
            }

            pet.IsStabled = false;
            pet.StabledBy = null;
            pet.ControlTarget = from;
            pet.ControlOrder = OrderType.Follow;
            pet.MoveToWorld(from.Location, from.Map);
            RemoveBird(index);
            claimed = true;
        }

        if (claimed)
        {
            from.SendLocalizedMessage(1042559);
        }
    }

    private void RemoveBird(int index)
    {
        _birds.RemoveAt(index);
        _birdOwners.RemoveAt(index);
        this.MarkDirty();
    }

    public override void OnAfterDelete()
    {
        foreach (var bird in _birds)
        {
            if (bird is BaseCreature { Deleted: false, IsStabled: true })
            {
                bird.Delete();
            }
        }
        _birds.Clear();
        _birdOwners.Clear();
        base.OnAfterDelete();
    }

    private sealed class CoopEntry(ChickenCoop coop, int label, bool stable) : ContextMenuEntry(label, 2)
    {
        public override void OnClick(Mobile from, IEntity target)
        {
            if (stable)
            {
                coop.BeginStable(from);
            }
            else
            {
                coop.Claim(from);
            }
        }
    }
}
