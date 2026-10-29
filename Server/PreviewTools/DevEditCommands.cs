// SPDX-License-Identifier: GPL-3.0-or-later
using System.Globalization;
using System.Net;
using Server;
using Server.Commands;
using UltimaClone.PreviewTools.DevEdit;

namespace UltimaClone.PreviewTools;

// ModernUO adapter for the developer edit session. It never changes the map
// or items: the overlay lives in its own journal under DevEdit/. The one
// server-only exception is "pet", which adds a tame creature (DevEditPets).
// Disabled unless ultimaClone.devEdit=True; callers must be on loopback AND
// their account must be listed in ultimaClone.devEdit.accounts (local config,
// never in the repository). Commands use the native speech protocol; replies
// are system messages prefixed UCEDIT1| so one textual command model serves
// the in-game panel, scripted tests and a future conversational assistant.
public static class DevEditCommands
{
    private static DevEditSession? _session;
    private static readonly Dictionary<Mobile, string> Joined = new();
    private static readonly DevEditConversation Conversation = new();
    private static readonly Dictionary<Mobile, (int Request, string Action, int Count, List<(string, int, string)> Items)> Batches = new();
    private static HashSet<string> _accounts = new(StringComparer.OrdinalIgnoreCase);
    private static string _directory = "";
    private static string _journal = "";
    private static string _failure = "";

    public static void Configure()
    {
        if (!ServerConfiguration.GetOrUpdateSetting("ultimaClone.devEdit", false))
        {
            return;
        }
        var accounts = ServerConfiguration.GetOrUpdateSetting("ultimaClone.devEdit.accounts", "");
        _accounts = new HashSet<string>(accounts.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries), StringComparer.OrdinalIgnoreCase);
        var name = ServerConfiguration.GetOrUpdateSetting("ultimaClone.devEdit.session", "britain-dev");
        _directory = Path.Combine(Core.BaseDirectory, "DevEdit");
        Directory.CreateDirectory(Path.Combine(_directory, "sets"));
        try
        {
            if (!DevEditSession.ValidName(name))
            {
                throw new InvalidDataException("ultimaClone.devEdit.session must be 1-32 characters a-z, 0-9 or '-'.");
            }
            var rules = DevEditRules.FromCatalog(File.ReadAllText(Path.Combine(Core.BaseDirectory, "Data", "ultimaclone-dev-edit-assets.json")));
            _journal = Path.Combine(_directory, $"session-{name}.json");
            _session = File.Exists(_journal)
                ? DevEditSession.Load(File.ReadAllText(_journal), rules, name, Baseline)
                : new DevEditSession(name, Baseline, rules);
            Console.WriteLine($"Developer edit session '{name}': revision {_session.Revision}, {_accounts.Count} authorized account(s).");
        }
        catch (Exception error) when (error is IOException or InvalidDataException or System.Text.Json.JsonException or KeyNotFoundException or UnauthorizedAccessException)
        {
            // A bad journal is never overwritten; the session stays closed.
            _failure = error.Message;
            Console.WriteLine($"Developer edit session unavailable: {error.Message}");
        }
        CommandSystem.Register("DevEdit", AccessLevel.Player, Handle);
        EventSink.Disconnected += Leave;
        EventSink.Logout += Leave;
    }

    public const string Baseline = "trammel-britain-1088-1408-704x512";

    private static void Reply(Mobile mobile, string line) => mobile.SendMessage("UCEDIT1|" + line);

    private static void Broadcast(string line)
    {
        foreach (var mobile in Joined.Keys.ToList())
        {
            if (mobile.NetState == null)
            {
                Joined.Remove(mobile);
                continue;
            }
            Reply(mobile, line);
        }
    }

    private static bool Authorized(Mobile mobile, out string reason)
    {
        reason = "";
        if (mobile.NetState is not { } state || !IPAddress.IsLoopback(state.Address))
        {
            reason = "developer editing is available only on the local development connection";
        }
        else if (mobile.Account is not { } account || !_accounts.Contains(account.Username))
        {
            reason = "this account is not authorized for developer editing";
        }
        else if (_session == null)
        {
            reason = "session unavailable: " + _failure;
        }
        else if (!DevEditSession.ValidAuthor(mobile.Name ?? ""))
        {
            reason = "character name cannot attribute edits";
        }
        return reason.Length == 0;
    }

    private static void Leave(Mobile mobile)
    {
        if (!Joined.Remove(mobile, out var author) || _session == null || Joined.ContainsValue(author))
        {
            return;
        }
        foreach (var target in _session.ReleaseAll(author))
        {
            Broadcast($"unlock|{target}");
        }
        Broadcast($"pvclear|{author}");
        Broadcast($"who|{author}|off");
    }

    private static void Handle(CommandEventArgs args)
    {
        var mobile = args.Mobile;
        if (!Authorized(mobile, out var reason))
        {
            Reply(mobile, $"denied|{reason}");
            return;
        }
        var session = _session!;
        var author = mobile.Name!;
        var a = args.Arguments;
        var verb = a.Length > 0 ? a[0].ToLowerInvariant() : "";
        if (verb == "join")
        {
            // An assistant (Claude Code via the bridge) edits under its own
            // name; authorization is still that of the account it uses.
            if (a.Length > 1 && a[1] == "assistant")
            {
                author = DevEditSession.AssistantAuthor;
            }
            Joined[mobile] = author;
            Snapshot(mobile, session, author);
            Broadcast($"who|{author}|on");
            return;
        }
        if (!Joined.ContainsKey(mobile))
        {
            Reply(mobile, "reject|0|state|join the session first");
            return;
        }
        author = Joined[mobile];
        if (verb == "leave")
        {
            Leave(mobile);
            Reply(mobile, "left");
            return;
        }
        if (verb is "ask" or "answer" or "propose" or "resolve")
        {
            Converse(mobile, author, verb, args.ArgString);
            return;
        }
        var request = a.Length > 1 && int.TryParse(a[1], NumberStyles.None, CultureInfo.InvariantCulture, out var req) ? req : 0;
        if (author == DevEditSession.AssistantAuthor && !DevEditSession.AssistantMay(verb))
        {
            Reply(mobile, $"reject|{request}|assistant|{verb}: the assistant proposes; the developer who asked reviews and accepts");
            return;
        }
        var now = Core.Now;
        Result result;
        switch (verb)
        {
            case "set" when a.Length == 4 || a.Length == 5:
                {
                    var state = a.Length == 5 ? a[4] : "";
                    if (state == "-")
                    {
                        state = "";
                    }
                    var action = ActionFor(a[2], session.Current(a[2]).State, state);
                    result = int.TryParse(a[3], NumberStyles.None, CultureInfo.InvariantCulture, out var baseRevision)
                        ? session.Set(author, a[2], baseRevision, state, now, action)
                        : Result.Fail("invalid", "malformed base revision");
                    break;
                }
            case "place" when a.Length == 7:
                result = Parse(a[2], out var asset) && Parse(a[5], out var z) && Parse(a[6], out var yaw)
                    ? session.Place(author, asset, a[3], a[4], z, yaw)
                    : Result.Fail("invalid", "malformed placement");
                break;
            // batch <req> begin <count> <action> | add <target> <base> [state] | commit | cancel
            case "batch" when a.Length >= 3:
                {
                    switch (a[2])
                    {
                        case "begin" when a.Length == 5 && Parse(a[3], out var count) && count is > 0 and <= DevEditSession.MaxBatch:
                            Batches[mobile] = (request, a[4], count, new List<(string, int, string)>());
                            return;
                        case "add" when (a.Length == 5 || a.Length == 6) && Batches.TryGetValue(mobile, out var open) && open.Request == request &&
                                        Parse(a[4], out var baseRevision) && open.Items.Count < open.Count:
                            open.Items.Add((a[3], baseRevision, a.Length == 6 && a[5] != "-" ? a[5] : ""));
                            return;
                        case "commit" when Batches.Remove(mobile, out var ready) && ready.Request == request:
                            result = ready.Items.Count != ready.Count
                                ? Result.Fail("invalid", $"batch received {ready.Items.Count} of {ready.Count} targets")
                                : session.Batch(author, ready.Items, now, ready.Action);
                            break;
                        case "cancel":
                            Batches.Remove(mobile);
                            return;
                        default:
                            Batches.Remove(mobile);
                            result = Result.Fail("invalid", "malformed or out-of-order batch");
                            break;
                    }
                    break;
                }
            case "brush" when a.Length == 7:
                result = session.Brush(author, a[2], a[3], a[4], a[5], a[6], now);
                break;
            case "undo" when a.Length == 3:
                result = Parse(a[2], out var undo) ? session.Undo(author, undo, now) : Result.Fail("invalid", "malformed operation");
                break;
            case "redo" when a.Length == 3:
                result = Parse(a[2], out var redo) ? session.Redo(author, redo, now) : Result.Fail("invalid", "malformed operation");
                break;
            case "lock" when a.Length == 3:
                result = session.Reserve(author, a[2], now);
                if (result.Ok)
                {
                    Broadcast($"lock|{a[2]}|{author}");
                }
                break;
            case "unlock" when a.Length == 3:
                if (session.Release(author, a[2]))
                {
                    Broadcast($"unlock|{a[2]}");
                }
                result = new Result { Ok = true, Code = "unlocked" };
                break;
            // preview <target|n|b:...> <state>  (no request id; replies only on rejection)
            case "preview" when a.Length == 2 || a.Length == 3:
                {
                    if (a[1] == "clear")
                    {
                        session.ClearPreview(author);
                        Broadcast($"pvclear|{author}");
                        return;
                    }
                    var state = a.Length == 3 && a[2] != "-" ? a[2] : "";
                    var preview = session.Preview(author, a[1], state);
                    if (preview.Ok)
                    {
                        Broadcast($"pv|{author}|{a[1]}|{state}");
                    }
                    else
                    {
                        Reply(mobile, $"reject|{request}|{preview.Code}|{preview.Detail}");
                    }
                    return;
                }
            case "save" when a.Length == 3:
                result = Save(session, a[2], out var savedLine);
                if (result.Ok)
                {
                    Reply(mobile, $"saved|{request}|{savedLine}");
                    return;
                }
                break;
            case "load" when a.Length == 3:
                {
                    var path = Path.Combine(_directory, "sets", a[2] + ".edits.json");
                    result = !DevEditSession.ValidName(a[2]) ? Result.Fail("invalid", "edit set names use a-z, 0-9 and '-'")
                        : !File.Exists(path) ? Result.Fail("invalid", "no such saved edit set")
                        : session.Import(author, File.ReadAllText(path), now);
                    break;
                }
            case "pet" when a.Length == 3:
                result = !DevEditSession.ValidPet(a[2]) ? Result.Fail("invalid", "pet kinds: " + string.Join(", ", DevEditSession.PetKinds))
                    : DevEditPets.Conjure(mobile, a[2]);
                break;
            case "status":
                Reply(mobile, $"status|{session.Name}|{session.Revision}|{session.Targets.Count(t => t.Value.State.Length > 0)}|{string.Join(',', Joined.Values.Distinct())}");
                return;
            default:
                result = Result.Fail("invalid", "unknown or malformed developer edit command");
                break;
        }
        if (!result.Ok)
        {
            Reply(mobile, $"reject|{request}|{result.Code}|{result.Detail}");
            return;
        }
        if (result.Operation is not { } operation)
        {
            Reply(mobile, $"ack|{request}|{result.Code}");
            return;
        }
        // Persist before announcing, so an announced edit is never lost.
        if (!Persist(session, out var error))
        {
            Reply(mobile, $"reject|{request}|storage|{error}");
            _failure = "journal write failed: " + error;
            _session = null;
            return;
        }
        Announce(operation, request);
    }

    private static void Converse(Mobile mobile, string author, string verb, string argString)
    {
        var words = argString.Trim().Split(' ', 3, StringSplitOptions.RemoveEmptyEntries);
        Result result;
        switch (verb)
        {
            case "ask" when words.Length >= 3:
                result = Conversation.AddPart(author, words[1], words[2], out var ask);
                if (ask != null)
                {
                    Broadcast($"ask|{ask.Id}|{ask.Author}|{ask.Text}");
                    Log($"ask {ask.Id} {ask.Author}: {ask.Text}");
                }
                break;
            case "answer" when words.Length >= 3 && Parse(words[1], out var answerId):
                result = Conversation.Answer(answerId, author, words[2]);
                if (result.Ok)
                {
                    Broadcast($"answer|{answerId}|{author}|{DevEditConversation.Clean(words[2])}");
                    Log($"answer {answerId} {author}: {words[2]}");
                }
                break;
            case "propose" when words.Length >= 3 && Parse(words[1], out var proposeId):
                var parts = argString.Trim().Split(' ', 4, StringSplitOptions.RemoveEmptyEntries);
                result = parts.Length == 4
                    ? Conversation.ProposePart(proposeId, author, parts[2], parts[3], out _)
                    : Result.Fail("invalid", "propose <id> <n/total> <command>");
                if (result.Ok && result.Code == "proposed" && Conversation.Find(proposeId) is { } proposed)
                {
                    for (var i = 0; i < proposed.Proposal.Length; i++)
                    {
                        Broadcast($"prop|{proposeId}|{author}|{i + 1}|{proposed.Proposal.Length}|{proposed.Proposal[i]}");
                    }
                    Log($"proposal {proposeId} {author}: {string.Join(" ; ", proposed.Proposal)}");
                }
                break;
            case "resolve" when words.Length >= 3 && Parse(words[1], out var resolveId):
                result = Conversation.Resolve(resolveId, author, words[2]);
                if (result.Ok)
                {
                    Broadcast($"resolved|{resolveId}|{author}|{words[2]}");
                    Log($"resolved {resolveId} {words[2]}");
                }
                break;
            default:
                result = Result.Fail("invalid", "ask <n/total> <text> | answer <id> <text> | propose <id> <n/total> <command> | resolve <id> applied|declined");
                break;
        }
        if (!result.Ok)
        {
            Reply(mobile, $"reject|0|{result.Code}|{result.Detail}");
        }
    }

    // Conversation audit trail next to the journal (local, ignored).
    private static void Log(string line)
    {
        try
        {
            File.AppendAllText(Path.Combine(_directory, "conversation.log"), $"{Core.Now:O} {line}{Environment.NewLine}");
        }
        catch (IOException)
        {
            // The audit log is informational; edits are journaled separately.
        }
    }

    private static bool Parse(string text, out int value) =>
        int.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out value);

    private static string ActionFor(string target, string before, string after)
    {
        if (after.Length == 0)
        {
            return target.StartsWith("p:", StringComparison.Ordinal) ? "remove" : "restore";
        }
        if (after == "hide")
        {
            return "hide";
        }
        var b = before.Split(':');
        var n = after.Split(':');
        if (target.StartsWith("s:", StringComparison.Ordinal) && n.Length == 6)
        {
            var original = target.Split(':');
            var previousId = b.Length == 6 ? b[5] : original[4];
            if (n[5] != previousId)
            {
                return "replace";
            }
            var previousYaw = b.Length == 6 ? b[4] : "0";
            var samePlace = b.Length == 6 ? b[1] == n[1] && b[2] == n[2] && b[3] == n[3] : n[1] == original[1] && n[2] == original[2] && n[3] == original[3];
            return samePlace && n[4] != previousYaw ? "rotate" : "move";
        }
        return target.StartsWith("p:", StringComparison.Ordinal) ? "move" : "set";
    }

    private static void Announce(Operation operation, int request)
    {
        Broadcast($"op|{operation.Seq}|{operation.Author}|{operation.Action}|{operation.Changes.Count}|{request}|{operation.Reverts}");
        foreach (var change in operation.Changes)
        {
            Broadcast($"chg|{operation.Seq}|{change.Target}|{change.After}");
        }
        Broadcast($"end|{operation.Seq}");
    }

    private static void Snapshot(Mobile mobile, DevEditSession session, string author)
    {
        Reply(mobile, $"hello|{session.Name}|{author}|{session.Revision}|{session.Baseline}");
        foreach (var (target, state) in session.Targets)
        {
            Reply(mobile, $"cur|{target}|{state.Revision}|{state.Author}|{state.State}");
        }
        // Recent history lets a reconnecting editor rebuild its undo/redo stacks.
        foreach (var operation in session.Log.Skip(Math.Max(0, session.Log.Count - 200)))
        {
            Reply(mobile, $"hist|{operation.Seq}|{operation.Author}|{operation.Action}|{operation.Reverts}|{operation.RevertedBy}|{operation.Changes.Count}");
        }
        foreach (var (target, held) in session.Reservations)
        {
            Reply(mobile, $"lock|{target}|{held.Author}");
        }
        foreach (var (editor, previews) in session.Previews)
        {
            foreach (var (target, state) in previews)
            {
                Reply(mobile, $"pv|{editor}|{target}|{state}");
            }
        }
        foreach (var editor in Joined.Values.Distinct())
        {
            Reply(mobile, $"who|{editor}|on");
        }
        // Open conversation so a late-joining editor or assistant can respond.
        foreach (var ask in Conversation.Asks.Where(a => a.Status is "open" or "answered" or "proposed"))
        {
            Reply(mobile, $"ask|{ask.Id}|{ask.Author}|{ask.Text}");
            foreach (var answer in ask.Answers)
            {
                var split = answer.IndexOf(": ", StringComparison.Ordinal);
                Reply(mobile, $"answer|{ask.Id}|{answer[..split]}|{answer[(split + 2)..]}");
            }
            for (var i = 0; i < ask.Proposal.Length; i++)
            {
                Reply(mobile, $"prop|{ask.Id}|{ask.ProposedBy}|{i + 1}|{ask.Proposal.Length}|{ask.Proposal[i]}");
            }
        }
        Reply(mobile, $"synced|{session.Revision}");
    }

    private static bool Persist(DevEditSession session, out string error)
    {
        error = "";
        try
        {
            var temporary = _journal + ".pending";
            File.WriteAllText(temporary, session.Serialize());
            File.Move(temporary, _journal, true);
            return true;
        }
        catch (Exception failure) when (failure is IOException or UnauthorizedAccessException)
        {
            error = failure.Message;
            return false;
        }
    }

    private static Result Save(DevEditSession session, string name, out string line)
    {
        line = "";
        if (!DevEditSession.ValidName(name))
        {
            return Result.Fail("invalid", "edit set names use a-z, 0-9 and '-'");
        }
        var text = session.ExportSet();
        try
        {
            var path = Path.Combine(_directory, "sets", name + ".edits.json");
            File.WriteAllText(path + ".pending", text);
            File.Move(path + ".pending", path, true);
        }
        catch (Exception failure) when (failure is IOException or UnauthorizedAccessException)
        {
            return Result.Fail("storage", failure.Message);
        }
        line = $"{name}|{session.Targets.Count(t => t.Value.State.Length > 0)}|{DevEditSession.Digest(text)[..16]}";
        return new Result { Ok = true, Code = "saved" };
    }
}
