// SPDX-License-Identifier: GPL-3.0-or-later
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UltimaClone.PreviewTools.DevEdit;

// Server-authoritative developer edit session. Pure logic, no ModernUO types,
// so it can be tested on its own. The converted world is an immutable baseline;
// this session only records overlay states for stable targets:
//   s:X:Y:Z:ID:K  an existing static (K = rank among identical source records)
//   p:N           a placed decorative object (N assigned here)
//   t:X:Y         a terrain height sample
// States are canonical strings; "" means "baseline". Every target carries the
// revision (operation sequence) and author of its last change. Operations are
// totally ordered by sequence. A client must name the revision it edited from;
// undo/redo only succeed while every touched target still holds the revision
// that operation produced, so nobody's newer change is silently overwritten.
public sealed class DevEditRules
{
    public int MinX = 1088, MinY = 1408, MaxX = 1791, MaxY = 1919;
    public HashSet<int> ApprovedAssets = new();
    public const int MaxMove = 8, MaxLift = 40, MaxTerrainDelta = 40, MaxBrushRadius = 6, MaxPlaced = 1024;
    public const int ReservationSeconds = 120;
    public static readonly string[] Surfaces = { "-", "grass", "forest", "dirt", "cobblestones", "sand", "brick" };

    public bool Inside(double x, double y) => x >= MinX && y >= MinY && x <= MaxX && y <= MaxY;

    public static DevEditRules FromCatalog(string json)
    {
        var rules = new DevEditRules();
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        if (root.GetProperty("format").GetString() != "britannia-reborn-dev-edit-assets" || root.GetProperty("schema").GetInt32() != 1)
        {
            throw new InvalidDataException("Unsupported developer asset catalogue.");
        }
        var bounds = root.GetProperty("bounds");
        rules.MinX = bounds.GetProperty("minX").GetInt32();
        rules.MinY = bounds.GetProperty("minY").GetInt32();
        rules.MaxX = bounds.GetProperty("maxX").GetInt32();
        rules.MaxY = bounds.GetProperty("maxY").GetInt32();
        foreach (var asset in root.GetProperty("assets").EnumerateArray())
        {
            rules.ApprovedAssets.Add(asset.GetProperty("id").GetInt32());
        }
        return rules;
    }
}

public sealed class TargetState
{
    public string State = "";
    public int Revision;
    public string Author = "";
}

public sealed class Change
{
    public string Target = "";
    public string Before = "";
    public string After = "";
}

public sealed class Operation
{
    public int Seq;
    public string Author = "";
    public string Action = "";
    public int Reverts;
    public int RevertedBy;
    public List<Change> Changes = new();
}

public sealed class Result
{
    public bool Ok;
    public string Code = "";
    public string Detail = "";
    public Operation? Operation;
    public static Result Fail(string code, string detail) => new() { Code = code, Detail = detail };
    public static Result Done(Operation operation) => new() { Ok = true, Code = "ok", Operation = operation };
}

public sealed class DevEditSession
{
    public const string JournalFormat = "britannia-reborn-dev-session";
    public const string SetFormat = "britannia-reborn-edit-set";
    public string Name { get; }
    public string Baseline { get; }
    public DevEditRules Rules { get; }
    public int Revision => _log.Count;
    public IReadOnlyList<Operation> Log => _log;
    public IReadOnlyDictionary<string, TargetState> Targets => _targets;
    public IReadOnlyDictionary<string, (string Author, DateTime Expires)> Reservations => _reservations;
    public IReadOnlyDictionary<string, Dictionary<string, string>> Previews => _previews;

    private readonly List<Operation> _log = new();
    private readonly SortedDictionary<string, TargetState> _targets = new(StringComparer.Ordinal);
    private readonly SortedDictionary<string, (string Author, DateTime Expires)> _reservations = new(StringComparer.Ordinal);
    private readonly SortedDictionary<string, Dictionary<string, string>> _previews = new(StringComparer.Ordinal);
    private int _nextPlaced = 1;

    public DevEditSession(string name, string baseline, DevEditRules rules)
    {
        Name = name;
        Baseline = baseline;
        Rules = rules;
    }

    public TargetState Current(string target) => _targets.TryGetValue(target, out var state) ? state : new TargetState();

    // ---- canonical formatting and validation ----

    public static string Number(double value) => Math.Round(value, 2, MidpointRounding.AwayFromZero).ToString("0.##", CultureInfo.InvariantCulture);

    private static bool Int(string text, int min, int max, out int value) =>
        int.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out value) && value >= min && value <= max &&
        value.ToString(CultureInfo.InvariantCulture) == text;

    private static bool Real(string text, out double value)
    {
        if (!double.TryParse(text, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out value) ||
            double.IsNaN(value) || double.IsInfinity(value))
        {
            return false;
        }
        return Number(value) == text;
    }

    public static bool ValidName(string name) =>
        name.Length is > 0 and <= 32 && name.All(c => c is >= 'a' and <= 'z' or >= '0' and <= '9' or '-');

    public static bool ValidAuthor(string author) =>
        author.Length is > 0 and <= 32 && author.All(c => char.IsLetterOrDigit(c) || c is ' ' or '-' or '_' or '\'') && author.Trim() == author;

    // Returns null when valid, otherwise a reason. Parses the target identity.
    public string? CheckTarget(string target)
    {
        var parts = target.Split(':');
        switch (parts[0])
        {
            case "s" when parts.Length == 6:
                if (!Int(parts[1], 0, 7167, out var x) || !Int(parts[2], 0, 4095, out var y) || !Int(parts[3], -128, 127, out _) ||
                    !Int(parts[4], 0, 0xFFFF, out _) || !Int(parts[5], 0, 15, out _))
                {
                    return "malformed static identity";
                }
                return Rules.Inside(x, y) ? null : "static outside the development region";
            case "p" when parts.Length == 2:
                return Int(parts[1], 1, DevEditRules.MaxPlaced, out var n) && n < _nextPlaced ? null : "unknown placed object";
            case "t" when parts.Length == 3:
                if (!Int(parts[1], 0, 7167, out var tx) || !Int(parts[2], 0, 4095, out var ty))
                {
                    return "malformed terrain sample";
                }
                return Rules.Inside(tx, ty) ? null : "terrain outside the development region";
        }
        return "unknown target kind";
    }

    public string? CheckState(string target, string state)
    {
        if (state.Length == 0)
        {
            return null;
        }
        var key = target.Split(':');
        var parts = state.Split(':');
        switch (key[0])
        {
            case "s":
                if (state == "hide")
                {
                    return null;
                }
                if (parts.Length != 6 || parts[0] != "m" || !Real(parts[1], out var x) || !Real(parts[2], out var y) ||
                    !Int(parts[3], -128, 127, out var z) || !Int(parts[4], 0, 359, out _) || !Int(parts[5], 0, 0xFFFF, out var id))
                {
                    return "malformed static placement";
                }
                var ox = int.Parse(key[1], CultureInfo.InvariantCulture);
                var oy = int.Parse(key[2], CultureInfo.InvariantCulture);
                var oz = int.Parse(key[3], CultureInfo.InvariantCulture);
                if (Math.Abs(x - ox) > DevEditRules.MaxMove || Math.Abs(y - oy) > DevEditRules.MaxMove || Math.Abs(z - oz) > DevEditRules.MaxLift)
                {
                    return "move exceeds the bounded edit distance";
                }
                if (!Rules.Inside(x, y))
                {
                    return "placement outside the development region";
                }
                return id == int.Parse(key[4], CultureInfo.InvariantCulture) || Rules.ApprovedAssets.Contains(id) ? null : "replacement asset is not approved";
            case "p":
                if (parts.Length != 6 || parts[0] != "a" || !Int(parts[1], 0, 0xFFFF, out var asset) || !Real(parts[2], out var px) ||
                    !Real(parts[3], out var py) || !Int(parts[4], -128, 127, out _) || !Int(parts[5], 0, 359, out _))
                {
                    return "malformed placed object";
                }
                if (!Rules.ApprovedAssets.Contains(asset))
                {
                    return "asset is not approved for placement";
                }
                return Rules.Inside(px, py) ? null : "placement outside the development region";
            case "t":
                if (parts.Length != 3 || parts[0] != "h" || !Int(parts[1], -DevEditRules.MaxTerrainDelta, DevEditRules.MaxTerrainDelta, out var dz) ||
                    !DevEditRules.Surfaces.Contains(parts[2]))
                {
                    return "malformed terrain state";
                }
                return dz == 0 && parts[2] == "-" ? "non-canonical baseline terrain state" : null;
        }
        return "unknown target kind";
    }

    // ---- reservations and shared previews (never persisted) ----

    private string? ReservedBy(string target, string author, DateTime now)
    {
        foreach (var expired in _reservations.Where(r => r.Value.Expires <= now).Select(r => r.Key).ToList())
        {
            _reservations.Remove(expired);
        }
        if (_reservations.TryGetValue(target, out var direct) && direct.Author != author)
        {
            return direct.Author;
        }
        if (target.StartsWith("t:", StringComparison.Ordinal))
        {
            var parts = target.Split(':');
            var x = int.Parse(parts[1], CultureInfo.InvariantCulture);
            var y = int.Parse(parts[2], CultureInfo.InvariantCulture);
            foreach (var (key, value) in _reservations)
            {
                if (value.Author == author || !key.StartsWith("r:", StringComparison.Ordinal))
                {
                    continue;
                }
                var region = key.Split(':');
                var cx = int.Parse(region[1], CultureInfo.InvariantCulture);
                var cy = int.Parse(region[2], CultureInfo.InvariantCulture);
                var r = int.Parse(region[3], CultureInfo.InvariantCulture);
                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r)
                {
                    return value.Author;
                }
            }
        }
        return null;
    }

    // Region reservation "r:X:Y:R" covers the same disc a brush would.
    public string? CheckReservable(string target)
    {
        var parts = target.Split(':');
        if (parts[0] == "r")
        {
            return parts.Length == 4 && Int(parts[1], 0, 7167, out var x) && Int(parts[2], 0, 4095, out var y) &&
                   Int(parts[3], 0, DevEditRules.MaxBrushRadius, out _) && Rules.Inside(x, y) ? null : "malformed region";
        }
        return CheckTarget(target);
    }

    public Result Reserve(string author, string target, DateTime now)
    {
        if (CheckReservable(target) is { } reason)
        {
            return Result.Fail("invalid", reason);
        }
        if (ReservedBy(target, author, now) is { } holder)
        {
            return Result.Fail("reserved", $"{target} is reserved by {holder}");
        }
        if (target.StartsWith("r:", StringComparison.Ordinal))
        {
            foreach (var cell in Disc(target))
            {
                if (ReservedBy(cell, author, now) is { } other)
                {
                    return Result.Fail("reserved", $"region overlaps a reservation by {other}");
                }
            }
        }
        _reservations[target] = (author, now.AddSeconds(DevEditRules.ReservationSeconds));
        return new Result { Ok = true, Code = "reserved" };
    }

    public bool Release(string author, string target) =>
        _reservations.TryGetValue(target, out var held) && held.Author == author && _reservations.Remove(target);

    public List<string> ReleaseAll(string author)
    {
        var released = _reservations.Where(r => r.Value.Author == author).Select(r => r.Key).ToList();
        foreach (var target in released)
        {
            _reservations.Remove(target);
        }
        _previews.Remove(author);
        return released;
    }

    private IEnumerable<string> Disc(string region)
    {
        var parts = region.Split(':');
        var cx = int.Parse(parts[1], CultureInfo.InvariantCulture);
        var cy = int.Parse(parts[2], CultureInfo.InvariantCulture);
        var r = int.Parse(parts[3], CultureInfo.InvariantCulture);
        for (var y = cy - r; y <= cy + r; y++)
        {
            for (var x = cx - r; x <= cx + r; x++)
            {
                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r)
                {
                    yield return $"t:{x}:{y}";
                }
            }
        }
    }

    // Previews are shared but temporary; they are validated like real edits.
    // "b:X:Y:R:DZ:SURF" previews a terrain brush; "n" previews a new placement.
    public Result Preview(string author, string target, string state)
    {
        if (target == "n")
        {
            if (CheckState("p:1", state) is { } placeReason)
            {
                return Result.Fail("invalid", placeReason);
            }
        }
        else if (target.StartsWith("g:", StringComparison.Ordinal))
        {
            // Group preview: "g:N" with a compact rule (or "selection") every
            // client evaluates on its own loaded source records.
            if (!Int(target[2..], 1, MaxBatch, out _) || !ValidRule(state))
            {
                return Result.Fail("invalid", "malformed group preview");
            }
        }
        else if (target.StartsWith("b:", StringComparison.Ordinal))
        {
            var parts = target.Split(':');
            var brushReason = parts.Length == 6 ? BrushCells(parts[1], parts[2], parts[3], parts[4], parts[5], out _) : "malformed brush";
            if (brushReason != null)
            {
                return Result.Fail("invalid", brushReason);
            }
        }
        else if ((CheckTarget(target) ?? CheckState(target, state)) is { } reason)
        {
            return Result.Fail("invalid", reason);
        }
        if (!_previews.TryGetValue(author, out var mine))
        {
            _previews[author] = mine = new Dictionary<string, string>();
        }
        if (mine.Count >= 8 && !mine.ContainsKey(target))
        {
            return Result.Fail("limit", "at most eight previews per editor");
        }
        mine[target] = state;
        return new Result { Ok = true, Code = "preview" };
    }

    public bool ClearPreview(string author, string target = "")
    {
        if (!_previews.TryGetValue(author, out var mine))
        {
            return false;
        }
        if (target.Length == 0)
        {
            return _previews.Remove(author);
        }
        return mine.Remove(target);
    }

    // ---- accepted operations ----

    private Result Commit(string author, string action, List<Change> changes, int reverts = 0)
    {
        if (!ValidAuthor(author))
        {
            return Result.Fail("invalid", "unattributable editor name");
        }
        var operation = new Operation { Seq = _log.Count + 1, Author = author, Action = action, Reverts = reverts, Changes = changes };
        foreach (var change in changes)
        {
            _targets[change.Target] = new TargetState { State = change.After, Revision = operation.Seq, Author = author };
        }
        if (reverts > 0)
        {
            _log[reverts - 1].RevertedBy = operation.Seq;
        }
        _log.Add(operation);
        return Result.Done(operation);
    }

    public Result Set(string author, string target, int baseRevision, string state, DateTime now, string action = "set")
    {
        if ((CheckTarget(target) ?? CheckState(target, state)) is { } reason)
        {
            return Result.Fail("invalid", reason);
        }
        var current = Current(target);
        if (current.Revision != baseRevision)
        {
            return Result.Fail("conflict", $"{target} is at revision {current.Revision} by {current.Author}; you edited revision {baseRevision}");
        }
        if (ReservedBy(target, author, now) is { } holder)
        {
            return Result.Fail("reserved", $"{target} is reserved by {holder}");
        }
        if (current.State == state)
        {
            return Result.Fail("noop", "state is unchanged");
        }
        Touch(author, target, now);
        return Commit(author, action, new List<Change> { new() { Target = target, Before = current.State, After = state } });
    }

    public const int MaxBatch = 256;

    public static bool ValidRule(string rule) =>
        rule.Length is > 0 and <= 100 && rule.All(c => c is >= 'a' and <= 'z' or >= '0' and <= '9' or ':' or ',' or '.' or '~' or '=' or ';' or '_' or '-');

    // Several targets in one ordered, attributed operation: all validated
    // first, all applied or none; one undo reverts the whole group.
    public Result Batch(string author, IReadOnlyList<(string Target, int Base, string State)> items, DateTime now, string action)
    {
        if (items.Count is 0 or > MaxBatch)
        {
            return Result.Fail("invalid", $"a batch holds 1-{MaxBatch} targets");
        }
        if (action is not ("move" or "rotate" or "replace" or "hide" or "restore" or "remove" or "set" or "commit"))
        {
            return Result.Fail("invalid", "unknown batch action");
        }
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var changes = new List<Change>();
        foreach (var (target, baseRevision, state) in items)
        {
            if (!seen.Add(target))
            {
                return Result.Fail("invalid", $"{target} appears twice in the batch");
            }
            if ((CheckTarget(target) ?? CheckState(target, state)) is { } reason)
            {
                return Result.Fail("invalid", $"{target}: {reason}");
            }
            var current = Current(target);
            if (current.Revision != baseRevision)
            {
                return Result.Fail("conflict", $"{target} is at revision {current.Revision} by {current.Author}; you edited revision {baseRevision}");
            }
            if (ReservedBy(target, author, now) is { } holder)
            {
                return Result.Fail("reserved", $"{target} is reserved by {holder}");
            }
            if (current.State != state)
            {
                changes.Add(new Change { Target = target, Before = current.State, After = state });
            }
        }
        return changes.Count == 0 ? Result.Fail("noop", "every target already has that state") : Commit(author, action, changes);
    }

    public Result Place(string author, int asset, string x, string y, int z, int yaw)
    {
        if (_nextPlaced > DevEditRules.MaxPlaced)
        {
            return Result.Fail("limit", "placed-object limit reached");
        }
        var state = $"a:{asset}:{x}:{y}:{z}:{yaw}";
        if (CheckState("p:1", state) is { } reason)
        {
            return Result.Fail("invalid", reason);
        }
        var target = $"p:{_nextPlaced++}";
        return Commit(author, "place", new List<Change> { new() { Target = target, Before = "", After = state } });
    }

    // Integer, deterministic falloff shared with the client preview:
    // delta = round_away(DZ * (R + 1 - d) / (R + 1)), d = Euclidean distance.
    public string? BrushCells(string sx, string sy, string sr, string sdz, string surface, out List<(string Target, int Delta)> cells)
    {
        cells = new List<(string, int)>();
        if (!Int(sx, 0, 7167, out var cx) || !Int(sy, 0, 4095, out var cy) || !Int(sr, 0, DevEditRules.MaxBrushRadius, out var r) ||
            !Int(sdz, -DevEditRules.MaxTerrainDelta, DevEditRules.MaxTerrainDelta, out var dz) || !DevEditRules.Surfaces.Contains(surface))
        {
            return "malformed brush";
        }
        if (dz == 0 && surface == "-")
        {
            return "brush changes nothing";
        }
        for (var y = cy - r; y <= cy + r; y++)
        {
            for (var x = cx - r; x <= cx + r; x++)
            {
                var square = (x - cx) * (x - cx) + (y - cy) * (y - cy);
                if (square > r * r)
                {
                    continue;
                }
                if (!Rules.Inside(x, y))
                {
                    return "brush reaches outside the development region";
                }
                var delta = (int)Math.Round(dz * (r + 1 - Math.Sqrt(square)) / (r + 1), MidpointRounding.AwayFromZero);
                cells.Add(($"t:{x}:{y}", delta));
            }
        }
        return null;
    }

    public Result Brush(string author, string x, string y, string r, string dz, string surface, DateTime now)
    {
        if (BrushCells(x, y, r, dz, surface, out var cells) is { } reason)
        {
            return Result.Fail("invalid", reason);
        }
        var changes = new List<Change>();
        foreach (var (target, delta) in cells)
        {
            if (ReservedBy(target, author, now) is { } holder)
            {
                return Result.Fail("reserved", $"terrain at {target} is reserved by {holder}");
            }
            var before = Current(target).State;
            var parts = before.Length == 0 ? new[] { "h", "0", "-" } : before.Split(':');
            var height = Math.Clamp(int.Parse(parts[1], CultureInfo.InvariantCulture) + delta, -DevEditRules.MaxTerrainDelta, DevEditRules.MaxTerrainDelta);
            var paint = surface == "-" ? parts[2] : surface;
            var after = height == 0 && paint == "-" ? "" : $"h:{height}:{paint}";
            if (after != before)
            {
                changes.Add(new Change { Target = target, Before = before, After = after });
            }
        }
        if (changes.Count == 0)
        {
            return Result.Fail("noop", "brush changes nothing (limits reached)");
        }
        return Commit(author, "brush", changes);
    }

    private string? Blocked(Operation operation, string author, DateTime now, int expected)
    {
        foreach (var change in operation.Changes)
        {
            var current = Current(change.Target);
            if (current.Revision != expected)
            {
                return $"{change.Target} was changed by {current.Author} at revision {current.Revision}";
            }
            if (ReservedBy(change.Target, author, now) is { } holder)
            {
                return $"{change.Target} is reserved by {holder}";
            }
        }
        return null;
    }

    public Result Undo(string author, int seq, DateTime now)
    {
        if (seq < 1 || seq > _log.Count)
        {
            return Result.Fail("invalid", "unknown operation");
        }
        var operation = _log[seq - 1];
        if (operation.Author != author)
        {
            return Result.Fail("denied", $"operation {seq} belongs to {operation.Author}");
        }
        if (operation.Action == "undo" || operation.RevertedBy != 0)
        {
            return Result.Fail("invalid", $"operation {seq} is already undone or is an undo");
        }
        if (operation.Action == "commit")
        {
            // Undoing would re-apply the edits on top of the rebaked world.
            return Result.Fail("invalid", "committed work is part of the converted world; revert it with scripts/revert-commits.ps1");
        }
        if (Blocked(operation, author, now, seq) is { } reason)
        {
            return Result.Fail("conflict", reason);
        }
        var changes = operation.Changes.Select(c => new Change { Target = c.Target, Before = c.After, After = c.Before }).ToList();
        return Commit(author, "undo", changes, seq);
    }

    // Redo re-applies what an undo removed, under the same revision rule.
    public Result Redo(string author, int undoSeq, DateTime now)
    {
        if (undoSeq < 1 || undoSeq > _log.Count)
        {
            return Result.Fail("invalid", "unknown operation");
        }
        var undo = _log[undoSeq - 1];
        if (undo.Author != author || undo.Action != "undo" || undo.RevertedBy != 0)
        {
            return Result.Fail("invalid", $"operation {undoSeq} is not your pending undo");
        }
        if (Blocked(undo, author, now, undoSeq) is { } reason)
        {
            return Result.Fail("conflict", reason);
        }
        var changes = undo.Changes.Select(c => new Change { Target = c.Target, Before = c.After, After = c.Before }).ToList();
        return Commit(author, "redo", changes, undoSeq);
    }

    private void Touch(string author, string target, DateTime now)
    {
        if (_reservations.TryGetValue(target, out var held) && held.Author == author)
        {
            _reservations[target] = (author, now.AddSeconds(DevEditRules.ReservationSeconds));
        }
    }

    // ---- persistence ----

    public string Serialize()
    {
        using var stream = new MemoryStream();
        using (var json = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
        {
            json.WriteStartObject();
            json.WriteString("format", JournalFormat);
            json.WriteNumber("schema", 1);
            json.WriteString("session", Name);
            json.WriteString("baseline", Baseline);
            json.WriteNumber("placedNext", _nextPlaced);
            json.WriteStartArray("operations");
            foreach (var operation in _log)
            {
                json.WriteStartObject();
                json.WriteNumber("seq", operation.Seq);
                json.WriteString("author", operation.Author);
                json.WriteString("action", operation.Action);
                json.WriteNumber("reverts", operation.Reverts);
                json.WriteStartArray("changes");
                foreach (var change in operation.Changes)
                {
                    json.WriteStartArray();
                    json.WriteStringValue(change.Target);
                    json.WriteStringValue(change.Before);
                    json.WriteStringValue(change.After);
                    json.WriteEndArray();
                }
                json.WriteEndArray();
                json.WriteEndObject();
            }
            json.WriteEndArray();
            json.WriteEndObject();
        }
        return Encoding.UTF8.GetString(stream.ToArray()).Replace("\r\n", "\n") + "\n";
    }

    // Replays and re-validates the whole journal. Any inconsistency rejects the
    // file instead of loading a partially corrupted overlay.
    public static DevEditSession Load(string text, DevEditRules rules, string expectedName, string expectedBaseline)
    {
        using var document = JsonDocument.Parse(text);
        var root = document.RootElement;
        if (root.GetProperty("format").GetString() != JournalFormat || root.GetProperty("schema").GetInt32() != 1)
        {
            throw new InvalidDataException("Not a schema 1 developer session journal.");
        }
        var session = new DevEditSession(root.GetProperty("session").GetString() ?? "", root.GetProperty("baseline").GetString() ?? "", rules);
        if (session.Name != expectedName || session.Baseline != expectedBaseline)
        {
            throw new InvalidDataException($"Journal is for session {session.Name} / baseline {session.Baseline}.");
        }
        session._nextPlaced = root.GetProperty("placedNext").GetInt32();
        if (session._nextPlaced < 1 || session._nextPlaced > DevEditRules.MaxPlaced + 1)
        {
            throw new InvalidDataException("Placed-object counter out of range.");
        }
        foreach (var entry in root.GetProperty("operations").EnumerateArray())
        {
            var seq = entry.GetProperty("seq").GetInt32();
            var author = entry.GetProperty("author").GetString() ?? "";
            var action = entry.GetProperty("action").GetString() ?? "";
            var reverts = entry.GetProperty("reverts").GetInt32();
            if (seq != session._log.Count + 1 || !ValidAuthor(author) || reverts < 0 || reverts >= seq ||
                action is not ("set" or "move" or "rotate" or "replace" or "hide" or "restore" or "remove" or "place" or "brush" or "undo" or "redo" or "import" or "commit"))
            {
                throw new InvalidDataException($"Invalid operation header at {seq}.");
            }
            if (reverts > 0 && session._log[reverts - 1].RevertedBy != 0)
            {
                throw new InvalidDataException($"Operation {reverts} reverted twice.");
            }
            var changes = new List<Change>();
            foreach (var item in entry.GetProperty("changes").EnumerateArray())
            {
                var change = new Change { Target = item[0].GetString() ?? "", Before = item[1].GetString() ?? "", After = item[2].GetString() ?? "" };
                if ((session.CheckTarget(change.Target) ?? session.CheckState(change.Target, change.After)) is { } reason ||
                    session.Current(change.Target).State != change.Before)
                {
                    throw new InvalidDataException($"Operation {seq} does not replay at {change.Target}.");
                }
                changes.Add(change);
            }
            session.Commit(author, action, changes, reverts);
        }
        return session;
    }

    // Deterministic, reviewable edit set: final states only, sorted by target.
    // It contains exact source coordinates and graphic ids of local game data,
    // so it is marked private; publishing needs an explicit owner review.
    public string ExportSet()
    {
        using var stream = new MemoryStream();
        using (var json = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
        {
            json.WriteStartObject();
            json.WriteString("format", SetFormat);
            json.WriteNumber("schema", 1);
            json.WriteString("baseline", Baseline);
            json.WriteString("session", Name);
            json.WriteNumber("revision", Revision);
            json.WriteString("privacy", "local: exact source coordinates and graphic ids; review before publishing");
            json.WriteStartArray("targets");
            foreach (var (target, state) in _targets)
            {
                if (state.State.Length == 0)
                {
                    continue;
                }
                json.WriteStartArray();
                json.WriteStringValue(target);
                json.WriteStringValue(state.State);
                json.WriteStringValue(state.Author);
                json.WriteEndArray();
            }
            json.WriteEndArray();
            json.WriteEndObject();
        }
        return Encoding.UTF8.GetString(stream.ToArray()).Replace("\r\n", "\n") + "\n";
    }

    public static string Digest(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();

    // Imports a saved set as one undoable operation that makes the overlay equal
    // to the file. Placed objects keep their numbers so the set round-trips.
    public Result Import(string author, string text, DateTime now)
    {
        var wanted = new SortedDictionary<string, string>(StringComparer.Ordinal);
        try
        {
            using var document = JsonDocument.Parse(text);
            var root = document.RootElement;
            if (root.GetProperty("format").GetString() != SetFormat || root.GetProperty("schema").GetInt32() != 1)
            {
                return Result.Fail("invalid", "not a schema 1 edit set");
            }
            if (root.GetProperty("baseline").GetString() != Baseline)
            {
                return Result.Fail("invalid", "edit set is for a different baseline");
            }
            foreach (var item in root.GetProperty("targets").EnumerateArray())
            {
                var target = item[0].GetString() ?? "";
                var state = item[1].GetString() ?? "";
                if (target.StartsWith("p:", StringComparison.Ordinal) && int.TryParse(target.AsSpan(2), out var n) && n >= _nextPlaced && n <= DevEditRules.MaxPlaced)
                {
                    _nextPlaced = n + 1;
                }
                var reason = CheckTarget(target) ?? CheckState(target, state) ?? (state.Length == 0 || !wanted.TryAdd(target, state) ? "duplicate or empty" : null);
                if (reason != null)
                {
                    return Result.Fail("invalid", $"edit set entry {target}: {reason}");
                }
            }
        }
        catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException or IndexOutOfRangeException)
        {
            return Result.Fail("invalid", "edit set is not valid JSON of the expected shape");
        }
        var changes = new List<Change>();
        foreach (var target in _targets.Keys.Union(wanted.Keys).OrderBy(t => t, StringComparer.Ordinal))
        {
            var before = Current(target).State;
            var after = wanted.GetValueOrDefault(target, "");
            if (before == after)
            {
                continue;
            }
            if (ReservedBy(target, author, now) is { } holder)
            {
                return Result.Fail("reserved", $"{target} is reserved by {holder}");
            }
            changes.Add(new Change { Target = target, Before = before, After = after });
        }
        return changes.Count == 0 ? Result.Fail("noop", "overlay already matches the edit set") : Commit(author, "import", changes);
    }
}
