# Context layer

An AI agent is only as good as the context it is given. This project ships that
context in three layers, each one machine-readable, each one owned in git next to
the code it describes, so it cannot drift from the models.

```
                 +-------------------------------------------------+
  Questions ---> | Agent (dbt MCP, dbt Wizard, Cortex, Genie, ...)  |
                 +-------------------------------------------------+
                      |                    |                    |
                      v                    v                    v
        1. dbt metadata          2. context/ docs       3. Fivetran Context Layer
        (in the YAML)            (this folder)          (AGENTS.* in Snowflake)
        descriptions, meta,      glossary, caveats,     DBT_MODEL / COLUMN /
        contracts, PII tags,     agent rules, verified  DEPENDENCY / METRIC rows,
        Semantic Layer metrics   sample Q&A             metric SQL recipes, routing
```

## 1. dbt metadata (the source of truth)

Lives in `platform/models/**/*.yml` and the consumer projects.

- Every gold column has a description that states units, nulls and caveats
  ("NULL means not applicable", "percent, not fraction").
- `meta` on every model: `owner`, `domain`, `tier`, `pii_contains`, `pii_columns`,
  `freshness_sla`, `semantic_layer_enabled`. PII columns carry `meta: {pii: true}`.
- Contracts are enforced on all public platform marts, so a column cannot change type
  or vanish without a failed build.
- The Semantic Layer (`04_marts/core/*.yml` + `05_semantic_layer/metrics.yml`) holds 28
  governed platform metrics, the definitions an agent must not reinvent. `finance` and
  `marketing` own 12 more on their own models.
- Singular tests in `platform/tests/` turn each verified caveat into a check, so the
  context stays true when the data changes.

The dbt MCP server and dbt Wizard read this layer directly.

## 2. context/ documents (for agents and people)

| File | Use it for |
|---|---|
| [`agent_instructions.md`](agent_instructions.md) | The rules: routing, definitions, what never to say. Paste into an agent's system prompt or Cortex / Genie instructions |
| [`data_caveats.md`](data_caveats.md) | Every verified fact about the source, with numbers |
| [`business_glossary.md`](business_glossary.md) | Business terms mapped to models and metrics |
| [`sample_questions.md`](sample_questions.md) | 15 questions with verified answers: a walkthrough and the agent eval set |
| [`fivetran_context_layer_routing.md`](fivetran_context_layer_routing.md) | Template for this project's section in the Fivetran Context Layer routing note |

## 3. Fivetran Context Layer

The Fivetran Context Layer is a set of `AGENTS.*` tables in the warehouse that any
agent can read with plain SQL, starting from `SELECT * FROM AGENTS.ROOT`. Alongside
what Fivetran catalogs from connectors (tables, columns, concepts, lineage), it holds
dbt context in `AGENTS.DBT_MODEL`, `DBT_COLUMN`, `DBT_DEPENDENCY` and `DBT_METRIC`,
partitioned by a `PROJECT` key, plus a routing note in `AGENTS.ROOT`.

`context_layer/publish_context_layer.py` turns this Mesh into those rows:

```bash
# 1. build each project so target/manifest.json and target/semantic_manifest.json exist
#    (in the dbt platform: download them from the latest production run)
# 2. generate the load script
python3 context_layer/publish_context_layer.py \
    --agents-schema <DB>.AGENTS \
    --gold-database <your PROD database> \
    --raw-schema <your LANDING database>.<your FINANCIAL_SERVICES schema>
# 3. review context_layer/generated/load_context_layer.sql, then run it in Snowflake
```

The script is scoped: it deletes and reloads only `PROJECT = 'finserv_mesh_lab'`
rows, and replaces only this project's section of the routing note (between its start
and end markers). Other projects sharing the `AGENTS` schema are untouched. Each
metric row carries a `recipe_sql` that reproduces the governed number on the gold
table, so an agent without Semantic Layer access still computes it the governed way.

## Why it matters (the business value)

- **Trust:** the same question gets the same number from every tool, because every
  tool reads the same definitions. "Approval rate" is 65.3% in the dashboard, in the
  agent and in the Context Layer.
- **Time to value:** the caveats that took hours of profiling are written down once.
  The next team, and the next agent, starts from them.
- **Governance travels:** PII tags, contracts and ownership defined in dbt are what
  the agent sees, so governance does not stop at the warehouse boundary.
