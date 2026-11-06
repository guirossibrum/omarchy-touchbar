#!/usr/bin/env python3
"""Export every simple node-to-node route; never used in the frame loop."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
topology = json.loads((ROOT / 'assets/omarchy-topology.json').read_text())
adjacency = {node['id']: [] for node in topology['nodes']}
for edge in topology['edges']:
    adjacency[edge['from']].append((edge['to'], edge['length']))
    adjacency[edge['to']].append((edge['from'], edge['length']))
for neighbors in adjacency.values():
    neighbors.sort()


def routes(source, target):
    result = []

    def visit(node, path, length):
        if node == target:
            result.append({'nodes': path, 'length': round(length, 9)})
            return
        for neighbor, distance in adjacency[node]:
            if neighbor not in path:
                visit(neighbor, path + [neighbor], length + distance)

    visit(source, [source], 0.0)
    return sorted(result, key=lambda route: (route['length'], route['nodes']))


nodes = sorted(adjacency)
entries = []
for i, source in enumerate(nodes):
    for target in nodes[i + 1:]:
        entries.append({'from': source, 'to': target, 'routes': routes(source, target)})
output = ROOT / 'assets/omarchy-routes.json'
output.write_text('[\n' + ',\n'.join(json.dumps(entry, separators=(',', ':')) for entry in entries) + '\n]\n')
print(f'{len(nodes)} nodes, {len(topology["edges"])} rails, '
      f'{len(entries)} node pairs, {sum(len(entry["routes"]) for entry in entries)} simple routes')
