// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Items;
using Server.Mobiles;
using Server.Spells;
using Server.Spells.Fourth;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Direct native callbacks/timers only in the explicitly enabled disposable world.
public static class JukaBehaviourFixtures
{
    private sealed record Pair(BaseCreature Caster, Ogre Target, JukaLord Lord)
    {
        public int HitsMax { get; } = Lord.HitsMaxSeed;
        public int Strength { get; } = Lord.RawStr;
        public int Dexterity { get; } = Lord.RawDex;
        public Corpse? Remains { get; set; }
    }
    private static readonly Dictionary<Serial, Pair> _pairs = new();

    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedJukaTests", false))
        {
            CommandSystem.Register("JukaBehaviourFixture", AccessLevel.Player, Execute);
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
            pair.Lord.Delete();
        }
    }

    private static void MoveObservers(PlayerMobile player, Map map)
    {
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
            observer.MoveToWorld(observer.Location, map);
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
            player.SendMessage("UCJUKA|clean");
            return;
        }
        if (operation == "prepare")
        {
            Cleanup(player);
            MoveObservers(player, Map.Trammel);
            var body = args.GetInt32(1);
            if (body is not (764 or 765) || !AquaticFixtures.Prepare(player, false))
            {
                player.SendMessage("UCJUKA|blocked|arena-or-body");
                return;
            }
            BaseCreature caster = body == 764 ? new JukaWarrior() : new JukaMage();
            var target = new Ogre();
            var lord = new JukaLord();
            caster.MoveToWorld(new Point3D(player.X + 1, player.Y + 1, player.Z), player.Map);
            target.MoveToWorld(new Point3D(player.X + 3, player.Y + 1, player.Z), player.Map);
            lord.MoveToWorld(new Point3D(player.X + 1, player.Y + 2, player.Z), player.Map);
            // This native combat target is the declared precondition of the buff.
            lord.Combatant = target;
            FixtureAIControls.Stop(caster);
            FixtureAIControls.Stop(target);
            FixtureAIControls.Stop(lord);
            _pairs[player.Serial] = new Pair(caster, target, lord);
            player.SendMessage($"UCJUKA|prepared|{caster.Serial.Value}|{target.Serial.Value}|{caster.Body.BodyID}|{caster.GetType().Name}|{Flag(caster.CanRummageCorpses)}|{Flag(caster.AlwaysMurderer)}|{caster.Meat}|{lord.Serial.Value}|{lord.Body.BodyID}");
            return;
        }
        if (!_pairs.TryGetValue(player.Serial, out var current) || current.Caster.Deleted)
        {
            return;
        }
        switch (operation)
        {
            case "ai":
                player.SendMessage($"UCJUKA|ai|{Flag(FixtureAIControls.Stopped(current.Caster))}|{Flag(FixtureAIControls.Stopped(current.Target))}|{Flag(FixtureAIControls.Stopped(current.Lord))}");
                break;
            case "cast" when current.Caster is JukaMage && !current.Target.Deleted:
                player.SendMessage($"UCJUKA|cast|{Flag(new LightningSpell(current.Caster).Cast())}");
                break;
            case "target" when !current.Target.Deleted:
                if (current.Caster.Target is not { } cursor)
                {
                    player.SendMessage($"UCJUKA|waiting|{(current.Caster.Spell as Spell)?.State.ToString() ?? "none"}");
                    break;
                }
                var before = current.Target.Hits;
                cursor.Invoke(current.Caster, current.Target);
                player.SendMessage($"UCJUKA|damage|{before}|{current.Target.Hits}");
                break;
            case "melee" when current.Caster is JukaWarrior warrior && !current.Target.Deleted:
                var oldHits = current.Target.Hits;
                var oldFrozen = current.Target.Frozen;
                warrior.OnGaveMeleeAttack(current.Target, 0);
                player.SendMessage($"UCJUKA|melee|{oldHits}|{current.Target.Hits}|{Flag(oldFrozen)}|{Flag(current.Target.Frozen)}");
                break;
            case "buff" when current.Caster is JukaMage mage && !current.Lord.Deleted:
                mage.OnThink();
                var lord = current.Lord;
                player.SendMessage($"UCJUKA|buff|{current.HitsMax}|{lord.HitsMaxSeed}|{current.Strength}|{lord.RawStr}|{current.Dexterity}|{lord.RawDex}|{Flag(lord.CanBeginAction<JukaMage>())}|{Flag(mage.IsFriend(lord))}|{Flag(lord.Combatant != null)}");
                break;
            case "rummage":
            case "rummage-unrestricted":
                if (current.Remains == null)
                {
                    current.Target.Kill();
                    current.Remains = current.Target.Corpse as Corpse;
                }
                if (current.Remains == null)
                {
                    player.SendMessage("UCJUKA|blocked|native-corpse");
                    break;
                }
                if (current.Caster.Backpack == null)
                {
                    player.SendMessage($"UCJUKA|no-backpack|{Flag(current.Caster.Rummage())}");
                    break;
                }
                if (operation == "rummage-unrestricted")
                {
                    MoveObservers(player, Map.Felucca);
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
                foreach (var item in current.Remains.Items)
                {
                    allowed += Flag(current.Remains.CanLoot(current.Caster, item));
                }
                var rummaged = current.Caster.Rummage();
                var acquired = false;
                var amountAfter = 0;
                foreach (var item in current.Caster.Backpack.Items)
                {
                    acquired |= !previous.Contains(item.Serial) && item.IsChildOf(current.Caster.Backpack);
                    amountAfter += item.Amount;
                }
                acquired |= amountAfter > amountBefore;
                var restricted = (current.Remains.Map.Rules & MapRules.HarmfulRestrictions) != 0;
                player.SendMessage($"UCJUKA|rummage|{Flag(rummaged)}|{count}|{current.Remains.Items.Count}|{Flag(acquired)}|{Flag(restricted)}|{allowed}");
                break;
        }
    }
}
