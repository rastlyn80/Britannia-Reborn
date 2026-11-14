// SPDX-License-Identifier: GPL-3.0-or-later
using ModernUO.Serialization;
using Server.Mobiles;
using Server.Targeting;

namespace Server.Items;

[SerializationGenerator(0)]
public abstract partial class AlchemyMetalElixir : Item
{
    protected AlchemyMetalElixir(int hue) : base(0x099B) => Hue = hue;

    protected abstract CraftResource Input { get; }
    protected abstract BaseIngot CreateOutput(int amount);

    public override void OnDoubleClick(Mobile from)
    {
        if (!from.Alive || from.Backpack is not { } pack || !IsChildOf(pack))
        {
            from.SendLocalizedMessage(1113074);
            return;
        }

        BaseIngot? selected = null;
        foreach (var item in pack.FindItems(false))
        {
            if (item is BaseIngot { QuestItem: false } ingot && ingot.Resource == Input)
            {
                selected = ingot;
                break;
            }
        }
        if (selected == null)
        {
            from.SendLocalizedMessage(1078618);
            return;
        }

        var amount = Math.Min(500, selected.Amount);
        var result = CreateOutput(amount);
        var releasedSlots = 1 + (amount == selected.Amount ? 1 : 0);
        if (!pack.CheckHold(from, result, true, true, -releasedSlots, -result.PileWeight - PileWeight))
        {
            result.Delete();
            return;
        }

        selected.Consume(amount);
        Delete();
        pack.DropItem(result);
        from.SendLocalizedMessage(1113048);
    }
}

[SerializationGenerator(0)]
public sealed partial class ElixirOfMetalConversion : AlchemyMetalElixir
{
    [Constructible]
    public ElixirOfMetalConversion() : base(1159) { }
    public override int LabelNumber => 1113011;
    protected override CraftResource Input => CraftResource.Iron;

    protected override BaseIngot CreateOutput(int amount) => Utility.Random(4) switch
    {
        0 => new DullCopperIngot(amount),
        1 => new ShadowIronIngot(amount),
        2 => new CopperIngot(amount),
        _ => new BronzeIngot(amount)
    };
}

[SerializationGenerator(0)]
public sealed partial class ElixirOfGoldConversion : AlchemyMetalElixir
{
    [Constructible]
    public ElixirOfGoldConversion() : base(2213) { }
    public override int LabelNumber => 1113007;
    protected override CraftResource Input => CraftResource.DullCopper;
    protected override BaseIngot CreateOutput(int amount) => new GoldIngot(amount);
}

[SerializationGenerator(0)]
public sealed partial class ElixirOfAgapiteConversion : AlchemyMetalElixir
{
    [Constructible]
    public ElixirOfAgapiteConversion() : base(2425) { }
    public override int LabelNumber => 1113008;
    protected override CraftResource Input => CraftResource.ShadowIron;
    protected override BaseIngot CreateOutput(int amount) => new AgapiteIngot(amount);
}

[SerializationGenerator(0)]
public abstract partial class AlchemyPetReward : Item
{
    protected AlchemyPetReward(int graphic) : base(graphic)
    {
    }

    protected abstract AlchemyPetEffects.Kind Effect { get; }

    public override void OnDoubleClick(Mobile from)
    {
        if (from.Backpack is { } pack && IsChildOf(pack))
        {
            from.BeginTarget(2, false, TargetFlags.Beneficial, (player, target) =>
            {
                if (player.Backpack is { } backpack && IsChildOf(backpack) && target is BaseCreature pet)
                {
                    GiveToPet(player, pet);
                }
            });
        }
    }

    public override bool DropToMobile(Mobile from, Mobile target, Point3D p) =>
        target is BaseCreature pet && GiveToPet(from, pet);

    private bool GiveToPet(Mobile from, BaseCreature pet)
    {
        if (Deleted || InSecureTrade || !from.Alive || !pet.Alive || pet.IsDeadBondedPet || !pet.Controlled ||
            pet.ControlMaster != from || pet.Map != from.Map || !from.InRange(pet, 2) ||
            !from.CanSee(pet) || !from.InLOS(pet) || !AlchemyPetEffects.Apply(from, pet, Effect))
        {
            return false;
        }

        Consume();
        return Deleted;
    }
}

[SerializationGenerator(0)]
public sealed partial class AlchemyTastyTreat : AlchemyPetReward
{
    [Constructible]
    public AlchemyTastyTreat() : base(0x0978) { }
    public override int LabelNumber => 1113003;
    protected override AlchemyPetEffects.Kind Effect => AlchemyPetEffects.Kind.Tasty;
}

[SerializationGenerator(0)]
public sealed partial class AlchemyDeliciousTreat : AlchemyPetReward
{
    [Constructible]
    public AlchemyDeliciousTreat() : base(0x0978) { }
    public override int LabelNumber => 1113004;
    protected override AlchemyPetEffects.Kind Effect => AlchemyPetEffects.Kind.Delicious;
}

[SerializationGenerator(0)]
public sealed partial class VialOfArmorEssence : AlchemyPetReward
{
    [Constructible]
    public VialOfArmorEssence() : base(0x5722) { }
    public override int LabelNumber => 1113018;
    protected override AlchemyPetEffects.Kind Effect => AlchemyPetEffects.Kind.Armor;
}

public sealed class AlchemyPetEffects : GenericPersistence
{
    public enum Kind : byte { Tasty, Delicious, Armor }

    private const string _modifier = "BritanniaRebornAlchemyPet";
    private static readonly Dictionary<(Serial Pet, bool Armor), EffectState> _active = [];
    private readonly record struct EffectState(Kind Kind, DateTime End, DateTime Recovery);

    public AlchemyPetEffects() : base("BritanniaRebornAlchemyPetEffects", 10)
    {
    }

    public static void Configure() => _ = new AlchemyPetEffects();

    public static void Initialize()
    {
        var now = Core.Now;
        foreach (var (key, state) in _active)
        {
            if (World.FindMobile(key.Pet) is BaseCreature pet)
            {
                SetEffects(pet, state);
            }
            ScheduleRecovery(key, state);
        }
    }

    internal static bool Apply(Mobile owner, BaseCreature pet, Kind kind)
    {
        var armor = kind == Kind.Armor;
        var key = (pet.Serial, armor);
        var now = Core.Now;
        if (_active.TryGetValue(key, out var current) && current.Recovery > now)
        {
            owner.SendLocalizedMessage(armor
                ? (current.End > now ? 1113075 : 1113076)
                : (current.End > now ? 1113051 : 1113049));
            return false;
        }

        var end = now + TimeSpan.FromMinutes(kind == Kind.Tasty ? 20 : 10);
        var recovery = end + TimeSpan.FromMinutes(kind switch { Kind.Tasty => 2, Kind.Delicious => 60, _ => 120 });
        var state = new EffectState(kind, end, recovery);
        _active[key] = state;
        SetEffects(pet, state);
        ScheduleRecovery(key, state);
        pet.Loyalty = BaseCreature.MaxLoyalty;
        pet.PlaySound(0x1EA);
        pet.FixedParticles(0x373A, 10, 15, 5018, EffectLayer.Waist);
        owner.SendLocalizedMessage(1113050);
        return true;
    }

    private static void ScheduleRecovery((Serial Pet, bool Armor) key, EffectState state)
    {
        Timer.DelayCall(state.Recovery - Core.Now, () =>
        {
            if (_active.GetValueOrDefault(key) == state)
            {
                _active.Remove(key);
            }
        });
    }

    private static void SetEffects(BaseCreature pet, EffectState state)
    {
        var remaining = state.End - Core.Now;
        if (remaining <= TimeSpan.Zero)
        {
            return;
        }
        if (state.Kind == Kind.Armor)
        {
            pet.RemoveResistanceMod(_modifier);
            var mod = new ResistanceMod(ResistanceType.Physical, _modifier, 10);
            pet.AddResistanceMod(mod);
            Timer.DelayCall(remaining, () => pet.RemoveResistanceMod(mod));
            return;
        }

        var percent = state.Kind == Kind.Tasty ? 5 : 10;
        AddStat(pet, StatType.Str, pet.RawStr * percent / 100, remaining);
        AddStat(pet, StatType.Dex, pet.RawDex * percent / 100, remaining);
        AddStat(pet, StatType.Int, pet.RawInt * percent / 100, remaining);
    }

    private static void AddStat(BaseCreature pet, StatType stat, int offset, TimeSpan duration)
    {
        var name = _modifier + stat;
        pet.RemoveStatMod(name);
        pet.AddStatMod(new StatMod(stat, name, offset, duration));
    }

    public override void Serialize(IGenericWriter writer)
    {
        writer.WriteEncodedInt(0);
        var now = Core.Now;
        var pending = _active.Where(pair => pair.Value.Recovery > now).ToArray();
        writer.WriteEncodedInt(pending.Length);
        foreach (var (key, state) in pending)
        {
            writer.Write(key.Pet.Value);
            writer.Write((byte)state.Kind);
            writer.Write(state.End);
            writer.Write(state.Recovery);
        }
    }

    public override void Deserialize(IGenericReader reader)
    {
        if (reader.ReadEncodedInt() != 0)
        {
            throw new InvalidOperationException("Unsupported alchemist pet effects save version.");
        }

        _active.Clear();
        var count = reader.ReadEncodedInt();
        for (var i = 0; i < count; i++)
        {
            var pet = (Serial)reader.ReadUInt();
            var kind = (Kind)reader.ReadByte();
            var state = new EffectState(kind, reader.ReadDateTime(), reader.ReadDateTime());
            if (state.Recovery > Core.Now)
            {
                _active[(pet, kind == Kind.Armor)] = state;
            }
        }
    }
}
