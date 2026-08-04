import json
import zlib
import gzip
import io

with open(r'd:\Organized_Downloads\Projects\Kreo Projects\IT-Feels\performance\dart_devtools_2026-08-04_17_19_45.848.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

perf = data.get('performance', {})
trace_binary = perf.get('traceBinary', [])
byte_array = bytes(trace_binary)

trace_str = None
try:
    trace_str = byte_array.decode('utf-8')
except UnicodeDecodeError:
    try:
        trace_str = zlib.decompress(byte_array).decode('utf-8')
    except:
        try:
            trace_str = gzip.decompress(byte_array).decode('utf-8')
        except Exception as e:
            print('Could not decompress:', e)

if trace_str:
    trace_data = json.loads(trace_str)
    events = trace_data.get('traceEvents', [])
    print(f'Total Trace Events: {len(events)}')

    durations = []
    for e in events:
        if 'dur' in e:
            dur_ms = e['dur'] / 1000.0
            if dur_ms > 50:
                durations.append((e.get('name', 'Unknown'), dur_ms, e.get('args', {})))

    durations.sort(key=lambda x: x[1], reverse=True)

    print('\nTop 20 Longest Events (>50ms):')
    for name, dur, args in durations[:20]:
        print(f'{dur:.2f} ms | {name} | {str(args)[:100]}')
