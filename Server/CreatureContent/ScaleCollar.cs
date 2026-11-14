// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Engines.Craft;
using Server.Mobiles;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class ScaleCollar : Item
{
    private const int TargetRange = 12;
    private BattleChickenLizard? _snaredBird;

    [Constructible]
    public ScaleCollar() : base(0x108B)
    {
        Hue = 2125;
    }

    public override int LabelNumber => 1112480;

    public static void Configure() => EventSink.ServerStarted += RegisterRecipe;

    private static void RegisterRecipe()
    {
        if (Core.SA && DefTinkering.CraftSystem is { } craft)
        {
            var index = craft.AddCraft(typeof(ScaleCollar), 1044050, 1112480, 50.0, 100.0,
                typeof(BaseScales), 1053139, 4, 1060884);
            craft.AddRes(index, typeof(Scourge), 1032677, 1, 1044253);
        }
    }

    public override void OnDoubleClick(Mobile from)
    {
        if (CanThrow(from))
        {
            from.SendLocalizedMessage(1112481);
            from.BeginTarget(TargetRange, false, TargetFlags.None, Throw);
        }
    }

    private bool CanThrow(Mobile from)
    {
        if (Deleted || !from.Alive || !IsChildOf(from.Backpack))
        {
            from.SendLocalizedMessage(1042004);
            return false;
        }

        if (_snaredBird != null)
        {
            from.SendLocalizedMessage(501789);
            return false;
        }

        return true;
    }

    private void Throw(Mobile from, object target)
    {
        if (!CanThrow(from) || target is not BattleChickenLizard
            { Alive: true, Deleted: false, Controlled: false, Summoned: false, Frozen: false, Paralyzed: false } bird ||
            bird.Map != from.Map || !from.InRange(bird, TargetRange))
        {
            return;
        }

        var distance = Math.Max(1, (int)from.GetDistanceToSqrt(bird));
        if (Utility.Random(100) >= 50 / distance)
        {
            from.SendLocalizedMessage(1112483);
            return;
        }

        _snaredBird = bird;
        bird.BeginCollarHold(this, from);
        from.SendLocalizedMessage(1112484);
    }

    internal void ClearHold(BattleChickenLizard bird)
    {
        if (_snaredBird == bird)
        {
            _snaredBird = null;
        }
    }

    public override void OnAfterDelete()
    {
        _snaredBird?.EndCollarHold();
        base.OnAfterDelete();
    }
}
