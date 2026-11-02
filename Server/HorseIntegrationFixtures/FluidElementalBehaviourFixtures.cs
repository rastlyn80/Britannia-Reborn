// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;
using Server.Spells;
using Server.Spells.Fourth;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Native spell/poison APIs in the explicitly enabled disposable world only.
public static class FluidElementalBehaviourFixtures
{
    private sealed record Pair(BaseCreature Caster, Ogre Target);
    private static readonly Dictionary<Serial, Pair> _pairs = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedFluidElementalTests", false))
        {
            CommandSystem.Register("FluidElementalFixture", AccessLevel.Player, Execute);
        }
    }

    private static int Flag(bool value) => value ? 1 : 0;

    private static void Cleanup(PlayerMobile player)
    {
        if (_pairs.Remove(player.Serial, out var pair))
        {
            pair.Caster.Delete();
            pair.Target.Delete();
        }
    }

    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile player || player.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || player.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true)
        {
            return;
        }
        var operation = args.GetString(0);
        if (operation == "cleanup")
        {
            Cleanup(player);
            player.SendMessage("UCFLUID|clean");
            return;
        }
        if (operation == "prepare")
        {
            Cleanup(player);
            if (!AquaticFixtures.Prepare(player, false))
            {
                player.SendMessage("UCFLUID|blocked|arena");
                return;
            }
            BaseCreature caster = args.GetInt32(1) switch
            {
                158 => new AcidElemental(),
                162 => new PoisonElemental(),
                _ => null
            };
            if (caster == null)
            {
                return;
            }
            var target = new Ogre { Frozen = true };
            caster.MoveToWorld(new Point3D(player.X + 1, player.Y + 1, player.Z), player.Map);
            target.MoveToWorld(new Point3D(player.X + 3, player.Y + 1, player.Z), player.Map);
            caster.AIObject?.Deactivate();
            target.AIObject?.Deactivate();
            _pairs[player.Serial] = new Pair(caster, target);
            player.SendMessage($"UCFLUID|prepared|{caster.Serial.Value}|{target.Serial.Value}|{caster.Body.BodyID}|{Flag(caster.BleedImmune)}|{caster.HitPoison?.Level ?? -1}|{caster.HitPoisonChance}|{caster.PoisonImmune?.Level ?? -1}");
            return;
        }
        if (!_pairs.TryGetValue(player.Serial, out var current) || current.Caster.Deleted || current.Target.Deleted)
        {
            return;
        }
        switch (operation)
        {
            case "cast":
                var started = new LightningSpell(current.Caster).Cast();
                player.SendMessage($"UCFLUID|cast|{Flag(started)}");
                break;
            case "target":
                if (current.Caster.Target is not { } cursor)
                {
                    player.SendMessage($"UCFLUID|waiting|{(current.Caster.Spell as Spell)?.State.ToString() ?? "none"}|{current.Caster.Hits}|{Flag(current.Caster.Frozen)}");
                    break;
                }
                var before = current.Target.Hits;
                cursor.Invoke(current.Caster, current.Target);
                player.SendMessage($"UCFLUID|damage|{before}|{current.Target.Hits}");
                break;
            case "poison":
                var applied = current.Target.ApplyPoison(current.Caster, current.Caster.HitPoison);
                var immunity = current.Caster.ApplyPoison(current.Target, Poison.Lethal);
                player.SendMessage($"UCFLUID|poison|{applied}|{current.Target.Poison?.Level ?? -1}|{immunity}|{current.Caster.Poison?.Level ?? -1}");
                break;
        }
    }
}
