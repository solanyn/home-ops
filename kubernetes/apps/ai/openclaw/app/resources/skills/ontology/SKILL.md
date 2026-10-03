---
name: ontology
description: Typed knowledge graph for structured agent memory. Use when creating/querying entities (Person, Project, Task, Event), linking related objects, showing dependencies, or when asked "what do I know about X". Triggers on "remember that", "who is", "link X to Y", "show dependencies", "what do I know about", entity relationships.
---

# Ontology

Knowledge graph stored as append-only JSONL. Entities have types, properties, and relations.

## Storage

- Graph: `memory/ontology/graph.jsonl`
- Schema: `memory/ontology/schema.yaml`
- Script: `scripts/ontology.py`

## Quick Commands

```bash
# Create
python3 scripts/ontology.py create --type Person --props '{"name":"Mirko","role":"manager","org":"Ericsson"}'

# Query
python3 scripts/ontology.py query --type Person
python3 scripts/ontology.py query --type Person --where '{"org":"Ericsson"}'
python3 scripts/ontology.py get --id p_001

# Link
python3 scripts/ontology.py relate --from p_mirko --rel manages --to p_andrew

# Search
python3 scripts/ontology.py related --id proj_spg --rel depends_on

# Validate
python3 scripts/ontology.py validate
```

## Core Types

```yaml
Person: { name, role?, org?, email?, phone?, notes? }
Organization: { name, type? }
Project: { name, status, owner?, repo?, stack? }
Task: { title, status, due?, priority?, assignee?, blockers[] }
Event: { title, start, end?, location?, attendees[] }
Document: { title, path?, url?, summary? }
Note: { content, tags[], refs[] }
```

## Relation Types

```yaml
manages: Person -> Person
works_on: Person -> Project
owns: Person -> Project
depends_on: Project -> Project
blocks: Task -> Task (acyclic)
assigned_to: Task -> Person
member_of: Person -> Organization
has_task: Project -> Task
```

## JSONL Format

```jsonl
{"op":"create","entity":{"id":"p_mirko","type":"Person","properties":{"name":"Mirko","role":"manager"}}}
{"op":"relate","from":"p_mirko","rel":"manages","to":"p_andrew"}
```

## Rules

- Append-only: never overwrite graph.jsonl, only append
- IDs: `{type_prefix}_{short_name}` (e.g. `p_andrew`, `proj_spg`, `t_001`)
- Updates: append a new create op with same ID (latest wins)
- Deletes: append `{"op":"delete","id":"p_001"}`
