# PQL.Assert – Fabric Notebook Example

This example provides a Microsoft Fabric Notebook that iterates through a set of Fabric workspace GUIDs, identifies every semantic model in each workspace using **semantic-link-labs**, retrieves the PQL.Assert tests defined in each model, executes them, and consolidates all results into a single output table.

## File

| File | Description |
|------|-------------|
| `RunPQLAssertTests.ipynb` | Fabric Notebook – multi-workspace PQL.Assert test runner |

## How It Works

```
For each workspace GUID
  └─ List semantic models          (semantic-link-labs: labs.list_datasets)
       └─ For each semantic model
            ├─ Discover tests      (PQL.Assert.RetrieveTestsByEnvironmentV2)
            └─ For each test
                 ├─ With impersonation  → sempy_labs.evaluate_dax_impersonation
                 └─ Without            → sempy.fabric.evaluate_dax (XMLA)

Output: combined DataFrame with WorkspaceName, SemanticModelName,
        TestFunctionName, TestName, Expected, Actual, Passed
```

## Prerequisites

1. **Microsoft Fabric workspace** – run the notebook from a Fabric Lakehouse or as a standalone notebook.
2. **PQL.Assert installed** in every target semantic model:
   - Add the contents of `src/lib/functions.tmdl` to the model's TMDL definition and refresh.
   - See the [main README](../../src/README.md) for full installation instructions.
3. **Permissions** – the notebook identity must have at least **Build** access on every target workspace.
4. **RLS / impersonation** – for tests that carry a `PQLAssert_ImpersonatedUserName` annotation the notebook calls `sempy_labs.evaluate_dax_impersonation`.  The semantic model must have RLS roles defined and the target user must exist in the tenant.

## Quickstart

1. **Import the notebook** into a Fabric workspace:
   - In Fabric, choose *New > Import notebook* and upload `RunPQLAssertTests.ipynb`.

2. **Set the configuration** in Cell 3:
   ```python
   WORKSPACE_GUIDS = [
       "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  # Workspace A
       "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",  # Workspace B
   ]
   ENVIRONMENT = "ANY"   # DEV | TEST | PROD | ANY | "" for all
   ```

3. **Run All Cells** (or *Run > Run all*).

4. **Review results** in the final cell output – a combined DataFrame is displayed with the columns below.

## Output Schema

| Column | Description |
|--------|-------------|
| `WorkspaceId` | GUID of the Fabric workspace |
| `WorkspaceName` | Display name of the workspace |
| `SemanticModelId` | GUID of the semantic model |
| `SemanticModelName` | Display name of the semantic model |
| `TestFunctionName` | PQL.Assert test function that was invoked |
| `TestName` | Individual assertion description |
| `Expected` | Expected value / expression |
| `Actual` | Actual value returned by the model |
| `Passed` | `True` if the assertion passed, `False` otherwise |

## Notes

- `PQL.Assert.RetrieveTestsByEnvironmentV2` uses `INFO.USERDEFINEDFUNCTIONS` and `INFO.ANNOTATIONS` which require the XMLA endpoint. This function **cannot** be called via the Power Automate *Execute Dataset Query* action — use `PQL.Assert.RetrieveTestsByEnvironment` (V1) for Power Automate flows instead. The XMLA endpoint used by `sempy.fabric.evaluate_dax` in a Fabric Notebook supports these INFO functions without restriction.
- Tests without an impersonated user are executed via `sempy.fabric.evaluate_dax` (XMLA endpoint).
- Tests with an impersonated user are executed via `sempy_labs.evaluate_dax_impersonation`, which wraps the Power BI `executeQueries` REST API with the `impersonatedUserName` field set to the UPN stored in the `PQLAssert_ImpersonatedUserName` annotation.
