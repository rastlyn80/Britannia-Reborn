// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;
using Server.Gumps;
using Server.Mobiles;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public partial class ChickenLizardEgg : Item
{
    private static readonly int[] _battleHues =
        [660, 60, 2001, 1372, 71, 678, 291, 1151, 691, 1154, 1165, 1173, 1301, 1159, 55, 50, 1002, 35, 1168, 1105];
    private static readonly TimeSpan _hour = TimeSpan.FromHours(1);

    [SerializableField(0)]
    private TimeSpan _incubated;

    [SerializableField(1)]
    [SerializedCommandProperty(AccessLevel.GameMaster)]
    private DateTime _heatingSince;

    [SerializableField(2)]
    private int _stage;

    [SerializableField(3)]
    private int _waterings;

    [SerializableField(4)]
    private int _worstDryness;

    [SerializableField(5)]
    private bool _battle;

    private TimerExecutionToken _timer;

    [Constructible]
    public ChickenLizardEgg() : base(0x41BD)
    {
    }

    public override int LabelNumber => _stage switch
    {
        0 => 1112469,
        1 or 2 => 1112462 + Math.Clamp(_stage - _waterings, 0, 3),
        3 => _battle ? 1112468 : 1112467,
        _ => 1112466
    };

    public override void OnAdded(IEntity parent)
    {
        base.OnAdded(parent);
        if (parent is ChickenIncubator { HeatsEggs: true })
        {
            StartHeating();
        }
    }

    public override void OnRemoved(IEntity parent)
    {
        StopHeating();
        base.OnRemoved(parent);
    }

    public override void OnAfterDelete()
    {
        _timer.Cancel();
        base.OnAfterDelete();
    }

    [AfterDeserialization]
    private void ResumeIncubation()
    {
        Timer.DelayCall(TimeSpan.Zero, () =>
        {
            if (Deleted)
            {
                return;
            }

            if (Parent is ChickenIncubator { HeatsEggs: true })
            {
                StartHeating();
                UpdateStage();
            }
            else
            {
                HeatingSince = DateTime.MinValue;
            }
        });
    }

    internal void StartHeating()
    {
        if (_stage == 4 || Deleted)
        {
            return;
        }

        if (_heatingSince == DateTime.MinValue)
        {
            HeatingSince = Core.Now;
        }

        _timer.Cancel();
        Timer.StartTimer(_hour, _hour, UpdateStage, out _timer);
    }

    internal void StopHeating()
    {
        _timer.Cancel();
        if (_heatingSince != DateTime.MinValue)
        {
            Incubated = Age;
            HeatingSince = DateTime.MinValue;
        }
    }

    private TimeSpan Age => _heatingSince == DateTime.MinValue ? _incubated :
        _incubated + (Core.Now > _heatingSince ? Core.Now - _heatingSince : TimeSpan.Zero);

    private void UpdateStage()
    {
        if (Parent is not ChickenIncubator { HeatsEggs: true })
        {
            StopHeating();
            return;
        }

        var hours = Age.TotalHours;
        if (_stage < 4 && hours >= 120)
        {
            Burn();
            return;
        }

        while (_stage < 3 && hours >= 24 * (_stage + 1))
        {
            var elapsedWateringDays = Math.Min(3, (int)(hours / 24) - 1);
            var missed = Math.Max(0, elapsedWateringDays - _waterings);
            RecordDryness(missed);
            WorstDryness = Math.Max(_worstDryness, missed);
            if (_stage == 4)
            {
                return;
            }
            if (missed >= 2)
            {
                InvalidateProperties();
                return;
            }

            Stage = _stage + 1;
            ItemID = _stage == 1 ? 0x41BE : 0x41BF;
            if (_stage == 3)
            {
                var chance = _worstDryness switch { 0 => 0.10, 1 => 0.05, _ => 0.01 };
                Battle = Utility.RandomDouble() < chance;
                Hue = _battle ? Utility.RandomList(_battleHues) : 651;
            }
            InvalidateProperties();
        }
    }

    private void RecordDryness(int missed)
    {
        if (missed <= _worstDryness)
        {
            return;
        }

        var burnRisk = missed switch { 1 => 0.05, 2 => 0.50, _ => 1.0 };
        if (Utility.RandomDouble() < burnRisk)
        {
            Burn();
        }
    }

    private void Burn()
    {
        Stage = 4;
        ItemID = 0x41BF;
        Hue = 1109;
        StopHeating();
        InvalidateProperties();
    }

    public override void OnDoubleClick(Mobile from)
    {
        if (Parent is ChickenIncubator incubator && incubator.CanUseAt(from))
        {
            UpdateStage();
            if (_stage < 3)
            {
                from.SendMessage("Select a pitcher of water to moisten the egg.");
                from.BeginTarget(2, false, TargetFlags.None, Water);
            }
        }
        else if (IsChildOf(from.Backpack))
        {
            var detail = _stage == 3 ? 1112446 : 1112445;
            from.SendGump(new WarningGump(1112444, 0x7FFF, detail, 0x7FFF, 325, 160, confirmed =>
            {
                if (confirmed)
                {
                    Hatch(from);
                }
            }));
        }
    }

    private void Water(Mobile from, object target)
    {
        if (Deleted || Parent is not ChickenIncubator incubator || !incubator.CanUseAt(from) ||
            target is not Pitcher { IsEmpty: false, Content: BeverageType.Water } pitcher ||
            !pitcher.IsChildOf(from.Backpack) || !pitcher.ValidateUse(from, true))
        {
            return;
        }

        UpdateStage();
        var required = Math.Max(_stage, Math.Min(3, (int)(Age.TotalHours / 24) - 1));
        if (_stage is < 1 or > 2 || _waterings >= required)
        {
            return;
        }

        pitcher.Quantity--;
        Waterings = _waterings + 1;
        from.PlaySound(0x4E);
        from.SendLocalizedMessage(1112461);
        UpdateStage();
        InvalidateProperties();
    }

    private void Hatch(Mobile from)
    {
        if (Deleted || !from.Alive || !IsChildOf(from.Backpack) || from.Map is not { } map || map == Map.Internal)
        {
            return;
        }

        if (_stage == 3)
        {
            ChickenLizardBase bird = _battle ? new BattleChickenLizard { Hue = Hue } : new ChickenLizard();
            bird.MoveToWorld(from.Location, map);
            from.SendLocalizedMessage(_battle ? 1112478 : 1112477);
        }
        else
        {
            from.SendLocalizedMessage(1112447);
        }

        Delete();
    }
}
