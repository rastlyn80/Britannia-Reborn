// SPDX-License-Identifier: GPL-3.0-or-later
using System.Net;
using Server;
using Server.Commands;
using Server.Mobiles;

namespace BritanniaReborn.HorseIntegrationFixtures;

// Original constructors and mount/death APIs in the disposable loopback world.
public static class SavageRiderFixtures
{
    private sealed record Subject(SavageRider Rider, BaseMount Mount)
    {
        public Item? Corpse { get; set; }
        public Dictionary<Mobile, bool> Protection { get; } = [];
    }
    private static readonly Dictionary<Mobile, Subject> Subjects = [];
    public static void Configure()
    {
        if (ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedHorseTests", false)
            && ServerConfiguration.GetOrUpdateSetting("britanniaReborn.isolatedSavageTests", false))
        {
            CommandSystem.Register("SavageRiderFixture", AccessLevel.Player, Execute);
        }
    }
    private static int Flag(bool value) => value ? 1 : 0;
    private static void Stop(Subject subject)
    {
        FixtureAIControls.Stop(subject.Rider);
        FixtureAIControls.Stop(subject.Mount);
    }
    private static bool Stopped(Subject subject) =>
        FixtureAIControls.Stopped(subject.Rider) && FixtureAIControls.Stopped(subject.Mount);
    private static void Cleanup(Mobile owner)
    {
        if (!Subjects.Remove(owner, out var subject)) { return; }
        subject.Mount.Rider = null;
        subject.Rider.Delete(); subject.Mount.Delete(); subject.Corpse?.Delete();
        foreach (var pair in subject.Protection)
        {
            if (!pair.Key.Deleted) { pair.Key.Blessed = pair.Value; }
        }
    }
    private static void Execute(CommandEventArgs args)
    {
        if (args.Mobile is not PlayerMobile owner || owner.NetState is not { } state
            || !IPAddress.IsLoopback(state.Address)
            || owner.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) != true) { return; }
        var command = args.GetString(0);
        if (command == "cleanup") { Cleanup(owner); owner.SendMessage("UCRIDER|clean"); return; }
        if (command == "prepare")
        {
            Cleanup(owner);
            var body = args.GetInt32(1);
            if (body is not (185 or 186) || !AquaticFixtures.Prepare(owner, false))
            { owner.SendMessage("UCRIDER|blocked|body-or-arena"); return; }
            for (var attempt = 0; attempt < 32; attempt++)
            {
                var rider = new SavageRider();
                var mount = (BaseMount)rider.Mount;
                if (rider.Body.BodyID != body)
                {
                    mount.Rider = null; rider.Delete(); mount.Delete(); continue;
                }
                var subject = new Subject(rider, mount);
                foreach (var client in owner.Map.GetClientsInRange(owner.Location))
                {
                    if (client.Mobile is { } observer
                        && observer.Account?.Username?.StartsWith("brhorse-test-", StringComparison.Ordinal) == true)
                    { subject.Protection[observer] = observer.Blessed; observer.Blessed = true; }
                }
                rider.MoveToWorld(new Point3D(owner.X + 1, owner.Y + 1, owner.Z), owner.Map);
                Stop(subject); Subjects[owner] = subject;
                owner.SendMessage($"UCRIDER|prepared|{rider.Serial.Value}|{body}|{Flag(rider.Female)}|{rider.Hue}|{mount.Serial.Value}|{mount.Body.BodyID}|{mount.ItemID}|{mount.Hue}|{rider.Str}|{rider.Dex}|{rider.Int}|{Flag(Stopped(subject))}");
                return;
            }
            owner.SendMessage("UCRIDER|blocked|constructor-sampling"); return;
        }
        if (!Subjects.TryGetValue(owner, out var current))
        { owner.SendMessage("UCRIDER|blocked|no-subject"); return; }
        switch (command)
        {
            case "colour":
                current.Rider.Hue = Math.Clamp(args.GetInt32(1), 0, 0xFFFF);
                current.Mount.Hue = Math.Clamp(args.GetInt32(2), 0, 0xFFFF);
                owner.SendMessage($"UCRIDER|colour|{current.Rider.Hue}|{current.Mount.Hue}");
                break;
            case "walk":
            case "run":
                Stop(current);
                var moved = current.Rider.Move(command == "walk" ? Direction.East : Direction.West | Direction.Running);
                Stop(current);
                owner.SendMessage($"UCRIDER|move|{Flag(moved)}|{current.Rider.X}|{current.Rider.Y}|{current.Rider.Z}|{(int)current.Rider.Direction}|{Flag(Stopped(current))}");
                break;
            case "action":
                var action = args.GetInt32(1);
                if (action is >= 23 and <= 29)
                { current.Rider.Animate(action, 5, 1, true, false, 0); owner.SendMessage($"UCRIDER|action|{action}"); }
                else { owner.SendMessage("UCRIDER|blocked|action"); }
                break;
            case "dismount":
                current.Mount.Rider = null; Stop(current);
                owner.SendMessage($"UCRIDER|dismount|{current.Mount.Serial.Value}");
                break;
            case "mount":
                current.Mount.Rider = current.Rider; Stop(current);
                owner.SendMessage($"UCRIDER|mount|{current.Mount.Serial.Value}");
                break;
            case "kill":
                Stop(current);
                var mountItem = current.Rider.FindItemOnLayer(Layer.Mount);
                var body = current.Rider.Body.BodyID;
                current.Rider.Kill();
                if (current.Rider.Corpse is { Deleted: false } corpse)
                {
                    current.Corpse = corpse;
                    owner.SendMessage($"UCRIDER|corpse|{corpse.Serial.Value}|{body}|{Flag(current.Mount.Deleted)}|{Flag(current.Rider.Mount == null)}|{Flag(mountItem?.Deleted == true)}");
                }
                else { owner.SendMessage("UCRIDER|blocked|native-death-without-corpse"); }
                break;
        }
    }
}
