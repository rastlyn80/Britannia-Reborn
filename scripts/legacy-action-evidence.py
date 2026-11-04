"""Compose a reviewed local alias with a separately verified base package."""
import json
from pathlib import Path

MANIFEST = Path(__file__).resolve().parents[1] / 'Viewer/Presentation/legacy-late-action-aliases.json'


def expected_with_legacy_alias(base, active):
    if 'legacy_slot11_evidence' not in active:
        return base
    identity, = base['bodies']
    body = str(int(identity['body']))
    proof = json.loads(MANIFEST.read_text(encoding='utf-8'))[body]
    if (active['legacy_slot11_evidence'] != proof or proof['kind'] != base['kind']
            or proof['family'] != base['family']
            or base.get('classic_action_categories', {}).get('11', 'Fidget') != 'Fidget'):
        raise ValueError(f'Unreviewed legacy slot 11 alias for body {body}')
    return dict(base, legacy_slot11_evidence=proof,
                classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Fidget'})
