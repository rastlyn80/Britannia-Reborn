// SPDX-License-Identifier: GPL-3.0-or-later
using Server;
using Server.Mobiles;
using Server.Network;

namespace UltimaClone.PreviewTools;

// Your own pets, for the client to draw in their own colour (owner request,
// 1 November 2026). The protocol has no ownership packet: the status packet's
// "may rename" flag is also true for every creature when the viewer is staff,
// which marked wild monsters as pets. This reads ModernUO's own ControlMaster
// (it never changes it) and tells each player's client which creatures near
// them are theirs whenever that set changes, as the system line
// "UCPET1|serial,serial,..." (empty after the bar when none), hidden by the
// client. Read-only; disable with ultimaClone.petReport.
public static class PetReport
{
    private static readonly Dictionary<Mobile, string> _sent = new();

    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.petReport", true)) return;
        Server.Timer.DelayCall(TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(1), Poll);
    }

    private static void Poll()
    {
        foreach (var state in NetState.Instances)
        {
            if (state.Mobile is not { Deleted: false, Map: not null } mobile) continue;
            var mine = new List<uint>();
            foreach (var other in mobile.GetMobilesInRange(Core.GlobalUpdateRange))
            {
                if (other is BaseCreature { Controlled: true } creature && creature.ControlMaster == mobile) mine.Add(creature.Serial.Value);
            }
            mine.Sort();
            var line = "UCPET1|" + string.Join(",", mine);
            if (_sent.TryGetValue(mobile, out var last) && last == line) continue;
            _sent[mobile] = line;
            mobile.SendMessage(line);
        }
        if (_sent.Count > NetState.Instances.Count * 2 + 16)
        {
            foreach (var gone in _sent.Keys.Where(m => m.NetState == null || m.Deleted).ToList()) _sent.Remove(gone);
        }
    }
}
