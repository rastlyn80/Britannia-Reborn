// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Ethics;
using Server.Factions;
using Server.Mobiles;
using Server.Spells.Necromancy;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Provides disposable native actors/context; clients send real charm packets.
public static class SilverSerpentBehaviourFixtures
{
    private sealed record Pair(SilverSerpent Snake, Ogre Target, Ogre Other, bool Blessed)
    {
        public DeathAdder Familiar { get; set; }
    }
    private static readonly Dictionary<Serial, Pair> _pairs = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedSilverSerpentTests", false))
        {
            CommandSystem.Register("SilverSerpentFixture", AccessLevel.Player, Execute);
        }
    }

    private static int Flag(bool value) => value ? 1 : 0;

    private static void Cleanup(PlayerMobile player)
    {
        if (!_pairs.Remove(player.Serial, out var pair))
        {
            return;
        }
        if (pair.Familiar != null && SummonFamiliarSpell.Table.GetValueOrDefault(player) == pair.Familiar)
        {
            SummonFamiliarSpell.Table.Remove(player);
        }
        player.Target?.Cancel(player, Server.Targeting.TargetCancelType.Canceled);
        player.Blessed = pair.Blessed;
        pair.Familiar?.Delete();
        pair.Snake.Delete();
        pair.Target.Delete();
        pair.Other.Delete();
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
            player.SendMessage("UCSILVER|clean");
            return;
        }
        if (operation == "prepare")
        {
            Cleanup(player);
            if (player.Target != null || SummonFamiliarSpell.Table.ContainsKey(player)
                || player.Backpack == null || !AquaticFixtures.Prepare(player, false))
            {
                player.SendMessage("UCSILVER|blocked|unrelated-context-or-arena");
                return;
            }
            var snake = new SilverSerpent { Frozen = true };
            var target = new Ogre { Frozen = true };
            var other = new Ogre { Frozen = true };
            snake.MoveToWorld(new Point3D(player.X + 1, player.Y + 1, player.Z), player.Map);
            target.MoveToWorld(new Point3D(player.X + 2, player.Y + 1, player.Z), player.Map);
            other.MoveToWorld(new Point3D(player.X + 3, player.Y + 1, player.Z), player.Map);
            snake.AIObject?.Deactivate();
            target.AIObject?.Deactivate();
            other.AIObject?.Deactivate();
            _pairs[player.Serial] = new Pair(snake, target, other, player.Blessed);
            // CanBeHarmful correctly refuses a blessed actor; restore on cleanup.
            player.Blessed = false;
            player.SendMessage($"UCSILVER|prepared|{snake.Serial.Value}|{target.Serial.Value}|{other.Serial.Value}|{player.Backpack.Serial.Value}|{snake.Body.BodyID}");
            return;
        }
        if (!_pairs.TryGetValue(player.Serial, out var current))
        {
            return;
        }
        switch (operation)
        {
            case "familiar":
                if (current.Familiar != null || SummonFamiliarSpell.Table.ContainsKey(player))
                {
                    return;
                }
                var familiar = new DeathAdder { Frozen = true };
                current.Familiar = familiar;
                if (!BaseCreature.Summon(familiar, player, new Point3D(player.X, player.Y + 1, player.Z), -1, TimeSpan.FromMinutes(1)))
                {
                    player.SendMessage("UCSILVER|blocked|native-summon");
                    return;
                }
                familiar.AIObject?.Deactivate();
                SummonFamiliarSpell.Table[player] = familiar;
                player.SendMessage($"UCSILVER|familiar|{familiar.Serial.Value}|{Flag(familiar.Summoned)}|{Flag(familiar.ControlMaster == player)}");
                break;
            case "status":
                player.SendMessage($"UCSILVER|status|{player.Target?.GetType().Name ?? "none"}|{current.Snake.Combatant?.Serial.Value ?? 0}|{Flag(current.Snake.AIObject?.Action == ActionType.Combat)}");
                break;
            case "poison":
                var attempts = 0;
                while (current.Target.Poison == null && attempts < 32)
                {
                    attempts++;
                    current.Snake.OnGaveMeleeAttack(current.Target, 1);
                }
                var immune = current.Snake.ApplyPoison(current.Target, Poison.Lethal);
                player.SendMessage($"UCSILVER|poison|{attempts}|{current.Target.Poison?.Level ?? -1}|{immune}|{current.Snake.HitPoison?.Level ?? -1}|{current.Snake.HitPoisonChance}|{Flag(current.Snake.DeathAdderCharmable)}|{Flag(current.Snake.FactionAllegiance == TrueBritannians.Instance)}|{Flag(current.Snake.EthicAllegiance == Ethic.Hero)}|{current.Snake.PoisonResistance}");
                break;
        }
    }
}
