# Sourced by run.sh; isolated panel regressions for 1.13.
python3 - "$SCRIPTS/panel.py" "$EST" <<'PY'
import json, subprocess, sys
from pathlib import Path
script, root = sys.argv[1], Path(sys.argv[2])
base = json.loads((root / 'a.json').read_text())
def render(data, *args):
    path = root / 'panel-113.json'
    path.write_text(json.dumps(data))
    out = subprocess.run([sys.executable, script, '--estimate', str(path), '--usage', '探讨', '--json', *args], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)
for tier, connected, expected in [('空', True, '空'), ('紧', True, '紧'), (None, False, '读不到')]:
    base['providers']['claude'].update(tier=tier, tier_text=tier, connected=connected)
    preview = '\n'.join(render(base)['preview'])
    assert f'（Haiku 停用：Claude {expected}）' in preview, preview
for model in ['Opus 5.5', 'Fable 5.1']:
    intro = render(base, '--host-model', model)['discuss'][0]
    assert f'我用 {model} 主持' in intro, intro
intro = render(base)['discuss'][0]
assert '我主持' in intro and '我用' not in intro and 'Fable' not in intro, intro
for strategy in ['auto', 'quality', 'thrift', 'rush']:
    for switch in [False, True]:
        for logged_in in [False, True]:
            base['try_new_models'] = switch
            base['providers']['grok']['logged_in'] = logged_in
            preview = render(base, '--strategy', strategy)['preview']
            assert (' 试用 Grok：取证、复核（只读，记战绩）' in preview) == (switch and logged_in), preview
PY
pass 'panel C1: Claude 空、紧、读不到 reported literally in Haiku note'
pass 'panel C2: actual host model supplied or omitted, never hard-coded'
pass 'panel C4: Grok trial row appears only when switch on AND logged in, in all four strategies'
