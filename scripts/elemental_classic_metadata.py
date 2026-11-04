"""Keep the installed runtime gestures when rebuilding the saved carrier."""


def preserve_gestures(record, entries):
    previous = next((row for row in entries if row['kind'] == record['kind']), {})
    routes = previous.get('classic_action_categories', {})
    if not {'7', '8'} <= routes.keys():
        return
    gestures = {slot: routes[slot] for slot in ('7', '8')}
    original = record['stats']['original']
    record['stats']['original'] = dict(original, clips=original['clips'] | {
        label: previous['stats']['original']['clips'][label] for label in gestures.values()})
    record['authored_replacements'].update({
        label: previous['authored_replacements'][label] for label in gestures.values()})
    record['classic_action_categories'] = record.get('classic_action_categories', {}) | gestures
