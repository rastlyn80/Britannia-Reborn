// SPDX-License-Identifier: GPL-3.0-or-later
using System;
using ModernUO.Serialization;

namespace Server.Items;

[SerializationGenerator(0)]
public sealed partial class TreefellowWood : Item
{
    [Constructible]
    public TreefellowWood() : base(0x1BDD)
    {
        Hue = 2425;
    }

    public override string DefaultName => "Treefellow Wood";
}

[SerializationGenerator(0)]
public sealed partial class FairyDragonWing : Item
{
    [Constructible]
    public FairyDragonWing() : base(0x1084)
    {
        Stackable = true;
        Amount = 1;
    }

    public override string DefaultName => "fairy dragon wing";
}

[SerializationGenerator(0)]
public sealed partial class DraconicOrb : Item
{
    [SerializableField(0)]
    private DateTime _expiration;

    [Constructible]
    public DraconicOrb() : base(0x573E)
    {
        Hue = 0x80F;
        Weight = 1.0;
        LootType = LootType.Blessed;
        _expiration = Core.Now.AddHours(12);
        ScheduleExpiry();
    }

    public override int LabelNumber => 1113515;

    [AfterDeserialization]
    private void ScheduleExpiry()
    {
        var remaining = _expiration - Core.Now;
        if (remaining <= TimeSpan.Zero)
        {
            Delete();
            return;
        }

        Timer.StartTimer(remaining, Delete, out _expiryTimer);
    }

    private TimerExecutionToken _expiryTimer;

    public override void OnAfterDelete()
    {
        _expiryTimer.Cancel();
        base.OnAfterDelete();
    }
}
