// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;
using Server.Spells;
using Server.Spells.Fourth;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Direct native APIs in the explicitly enabled disposable world, not AI play.
public static class MageBehaviourFixtures
{
    private sealed record Pair(BaseCreature Caster, Ogre Target)
    {
        public Corpse? Remains { get; set; }
    }
    private static readonly Dictionary<Serial, Pair> _pairs = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedMageTests", false))
        {
            CommandSystem.Register("MageBehaviourFixture", AccessLevel.Player, Execute);
        }
    }

    private static int Flag(bool value) => value ? 1 : 0;

    private static void Cleanup(PlayerMobile player)
    {
        if (_pairs.Remove(player.Serial, out var pair))
        {
            pair.Remains?.Delete();
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
            player.SendMessage("UCMAGE|clean");
            return;
        }
        if (operation == "prepare")
        {
            Cleanup(player);
            var body = args.GetInt32(1);
            // Each case starts on the restricted facet; the prior case travels.
            var observers = new List<Mobile>();
            foreach (var client in player.Map.GetClientsInRange(player.Location))
            {
                if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                {
                    observers.Add(client.Mobile);
                }
            }
            foreach (var observer in observers)
            {
                observer.MoveToWorld(observer.Location, Map.Trammel);
            }
            if (body is not (124 or 125 or 126) || !AquaticFixtures.Prepare(player, false))
            {
                player.SendMessage("UCMAGE|blocked|arena-or-body");
                return;
            }
            BaseCreature? caster = null;
            for (var attempt = 0; attempt < 16; attempt++)
            {
                BaseCreature candidate = body == 124 ? new EvilMage() : new EvilMageLord();
                if (candidate.Body.BodyID == body)
                {
                    caster = candidate;
                    break;
                }
                candidate.Delete();
            }
            if (caster == null)
            {
                player.SendMessage("UCMAGE|blocked|native-constructor-sampling");
                return;
            }
            var target = new Ogre { Frozen = true };
            caster.MoveToWorld(new Point3D(player.X + 1, player.Y + 1, player.Z), player.Map);
            target.MoveToWorld(new Point3D(player.X + 3, player.Y + 1, player.Z), player.Map);
            FixtureAIControls.Stop(caster);
            FixtureAIControls.Stop(target);
            _pairs[player.Serial] = new Pair(caster, target);
            player.SendMessage($"UCMAGE|prepared|{caster.Serial.Value}|{target.Serial.Value}|{caster.Body.BodyID}|{Flag(caster.CanRummageCorpses)}|{Flag(caster.AlwaysMurderer)}|{caster.Meat}|{caster.GetType().Name}");
            return;
        }
        if (!_pairs.TryGetValue(player.Serial, out var current) || current.Caster.Deleted)
        {
            return;
        }
        switch (operation)
        {
            case "ai":
                player.SendMessage($"UCMAGE|ai|{Flag(FixtureAIControls.Stopped(current.Caster))}|{Flag(FixtureAIControls.Stopped(current.Target))}");
                break;
            case "cast" when !current.Target.Deleted:
                player.SendMessage($"UCMAGE|cast|{Flag(new LightningSpell(current.Caster).Cast())}");
                break;
            case "target" when !current.Target.Deleted:
                if (current.Caster.Target is not { } cursor)
                {
                    player.SendMessage($"UCMAGE|waiting|{(current.Caster.Spell as Spell)?.State.ToString() ?? "none"}");
                    break;
                }
                var before = current.Target.Hits;
                cursor.Invoke(current.Caster, current.Target);
                player.SendMessage($"UCMAGE|damage|{before}|{current.Target.Hits}");
                break;
            case "rummage":
            case "rummage-unrestricted":
                if (current.Remains == null)
                {
                    current.Target.Kill();
                    current.Remains = current.Target.Corpse as Corpse;
                }
                if (current.Remains == null || current.Caster.Backpack == null)
                {
                    player.SendMessage("UCMAGE|blocked|native-corpse-or-backpack");
                    break;
                }
                if (operation == "rummage-unrestricted")
                {
                    // Facet rules remain native; the unrestricted test is explicit setup.
                    var observers = new List<Mobile>();
                    foreach (var client in player.Map.GetClientsInRange(player.Location))
                    {
                        if (client.Mobile?.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                        {
                            observers.Add(client.Mobile);
                        }
                    }
                    foreach (var observer in observers)
                    {
                        observer.MoveToWorld(observer.Location, Map.Felucca);
                    }
                    current.Caster.MoveToWorld(current.Caster.Location, Map.Felucca);
                    current.Remains.MoveToWorld(current.Remains.Location, Map.Felucca);
                    FixtureAIControls.Stop(current.Caster);
                }
                var previous = new HashSet<Serial>();
                var amountBefore = 0;
                foreach (var item in current.Caster.Backpack.Items)
                {
                    previous.Add(item.Serial);
                    amountBefore += item.Amount;
                }
                var count = current.Remains.Items.Count;
                var allowed = 0;
                var diagnostics = new List<string>();
                foreach (var item in current.Remains.Items)
                {
                    allowed += Flag(current.Remains.CanLoot(current.Caster, item));
                    diagnostics.Add($"{item.GetType().Name}:range={Flag(current.Caster.InRange(item.GetWorldLocation(), 2))},see={Flag(current.Caster.CanSee(item))},los={Flag(current.Caster.InLOS(item))},move={Flag(item.VerifyMove(current.Caster))},access={Flag(item.IsAccessibleTo(current.Caster))},lift={Flag(item.CheckLift(current.Caster))}");
                }
                var rummaged = current.Caster.Rummage();
                var acquired = false;
                var amountAfter = 0;
                foreach (var item in current.Caster.Backpack.Items)
                {
                    acquired |= !previous.Contains(item.Serial) && item.IsChildOf(current.Caster.Backpack);
                    amountAfter += item.Amount;
                }
                // Native Drop may merge a stack into an existing inventory item.
                acquired |= amountAfter > amountBefore;
                var restricted = (current.Remains.Map.Rules & MapRules.HarmfulRestrictions) != 0;
                player.SendMessage($"UCMAGE|rummage|{Flag(rummaged)}|{count}|{current.Remains.Items.Count}|{Flag(acquired)}|{Flag(restricted)}|{allowed}|{string.Join(';', diagnostics)}");
                break;
        }
    }
}
