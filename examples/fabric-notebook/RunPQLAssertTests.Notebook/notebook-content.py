# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # PQL.Assert – Multi-Workspace Test Runner
# 
# This notebook iterates through a configurable list of Microsoft Fabric workspace GUIDs, discovers all semantic models in each workspace using **semantic-link-labs**, retrieves the PQL.Assert test functions defined in each model using `PQL.Assert.RetrieveTestsByEnvironmentV2`, and executes every test—applying user impersonation where specified by the `PQLAssert_ImpersonatedUserName` annotation.
# 
# All test results are collected into a single output table that includes the workspace name, semantic model name, test function name, and the standard PQL.Assert columns (`TestName`, `Expected`, `Actual`, `Passed`).
# 
# ## Requirements
# - Run this notebook inside a **Microsoft Fabric** environment (Lakehouse or Warehouse attached, or standalone notebook)
# - The `semantic-link-labs` package (installed in Cell 2)
# - The **PQL.Assert** library loaded into every target semantic model (`functions.tmdl` imported and model refreshed)
# - The notebook identity (or the capacity admin token) must have **at least Build access** on each target workspace
# - For impersonated tests the workspace must use **Row-Level Security (RLS)** and the target user must exist in the tenant


# MARKDOWN ********************

# ## Cell 1 – Install dependencies

# CELL ********************

# Install semantic-link-labs (includes sempy.fabric)
%pip install semantic-link-labs

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Cell 2 – Imports

# CELL ********************

import sempy.fabric as fabric
import sempy_labs as labs
import pandas as pd

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Cell 3 – Configuration
# 
# Replace the placeholder GUIDs with the real workspace GUIDs you want to scan, and set `ENVIRONMENT` to the test environment you want to run (`DEV`, `TEST`, `PROD`, `ANY`, or `""` for all tests).

# CELL ********************

# ── Configuration ─────────────────────────────────────────────────────────────

# List every Fabric workspace GUID whose semantic models should be tested.
WORKSPACE_GUIDS: list[str] = [
    "daeadd4c-c82a-493e-b610-a21a46a3e914",  # Replace with your workspace GUID
    "00000000-0000-0000-0000-000000000002",  # Replace with your workspace GUID
]

# Environment filter passed to PQL.Assert.RetrieveTestsByEnvironmentV2.
# Options: "DEV" | "TEST" | "PROD" | "ANY" | "" (empty string = all tests)
ENVIRONMENT: str = "ANY"

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Cell 4 – Helper functions

# CELL ********************

def _retrieve_tests(workspace_id: str, dataset_id: str, environment: str) -> pd.DataFrame:
    """Call PQL.Assert.RetrieveTestsByEnvironmentV2 via XMLA (sempy.fabric.evaluate_dax).

    Returns a DataFrame with columns:
        Name                        – function name (e.g. "DataQuality.ANY.Tests")
        Description                 – optional description annotation
        PQLAssert_ImpersonatedUserName – UPN to impersonate for RLS tests (may be blank)

    Note: RetrieveTestsByEnvironmentV2 uses INFO.USERDEFINEDFUNCTIONS and
    INFO.ANNOTATIONS which require the XMLA endpoint. This is NOT compatible
    with the Power Automate "Execute Dataset Query" action; use
    PQL.Assert.RetrieveTestsByEnvironment (V1) for Power Automate flows.
    """
    env_escaped = environment.replace('"', '""')  # escape any embedded quotes
    dax = f'EVALUATE PQL.Assert.RetrieveTestsByEnvironmentV2("{env_escaped}")'
    return fabric.evaluate_dax(workspace=workspace_id, dataset=dataset_id, dax_string=dax)


def _execute_test(workspace_id: str, dataset_id: str, test_name: str) -> pd.DataFrame:
    """Execute a PQL.Assert test function via sempy.fabric.evaluate_dax (XMLA).

    Returns a DataFrame with the standard PQL.Assert result columns:
        TestName, Expected, Actual, Passed
    """
    dax = f"EVALUATE {test_name}()"
    return fabric.evaluate_dax(workspace=workspace_id, dataset=dataset_id, dax_string=dax)


def _execute_test_as_user(
    workspace_id: str,
    dataset_id: str,
    test_name: str,
    username: str,
) -> pd.DataFrame:
    """Execute a PQL.Assert test function via sempy_labs.evaluate_dax_impersonation.

    Uses the semantic-link-labs REST API wrapper which handles the Power BI
    executeQueries endpoint with impersonation internally.

    Args:
        workspace_id: GUID of the Fabric workspace.
        dataset_id:   GUID of the semantic model (dataset).
        test_name:    Fully-qualified test function name (e.g. "RLS.ANY.Tests").
        username:     UPN of the user to impersonate (e.g. "user@contoso.com").

    Returns:
        DataFrame with TestName, Expected, Actual, Passed columns.
    """
    dax = f"EVALUATE {test_name}()"
    return labs.evaluate_dax_impersonation(
        dataset=dataset_id,
        dax_query=dax,
        user_name=username,
        workspace=workspace_id,
    )

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Cell 5 – Iterate workspaces, discover and execute tests

# CELL ********************

all_results: list[pd.DataFrame] = []

for workspace_id in WORKSPACE_GUIDS:

    # ── Resolve workspace display name ────────────────────────────────────────
    try:
        workspace_name = fabric.resolve_workspace_name(workspace_id)
    except Exception:
        workspace_name = workspace_id

    print(f"\n🗂  Workspace: {workspace_name} ({workspace_id})")

    # ── List semantic models using semantic-link-labs ─────────────────────────
    try:
        semantic_models: pd.DataFrame = labs.list_datasets(workspace=workspace_id)
    except Exception as exc:
        print(f"  ⚠  Could not list datasets: {exc}")
        continue

    if semantic_models is None or semantic_models.empty:
        print("  ℹ  No semantic models found in this workspace.")
        continue

    for _, model_row in semantic_models.iterrows():
        dataset_id: str = str(model_row["Dataset Id"])
        dataset_name: str = str(model_row["Dataset Name"])

        print(f"\n  📊 Semantic Model: {dataset_name} ({dataset_id})")

        # ── Retrieve tests via PQL.Assert.RetrieveTestsByEnvironmentV2 ────────
        try:
            tests_df = _retrieve_tests(workspace_id, dataset_id, ENVIRONMENT)
        except Exception as exc:
            print(f"    ⚠  Could not retrieve tests (is PQL.Assert installed?): {exc}")
            continue

        if tests_df is None or tests_df.empty:
            print(f"    ℹ  No tests found for environment '{ENVIRONMENT}'.")
            continue

        print(f"    ✅ {len(tests_df)} test function(s) found for environment '{ENVIRONMENT}'.")

        # ── Execute each test ─────────────────────────────────────────────────
        for _, test_row in tests_df.iterrows():
            # Column names returned by evaluate_dax match the SELECTCOLUMNS
            # aliases in the function definition: "Name", "Description",
            # "PQLAssert_ImpersonatedUserName"
            test_name: str = str(test_row.get("Name", test_row.iloc[0]))

            raw_user = test_row.get("PQLAssert_ImpersonatedUserName", "")
            impersonated_user: str = (
                ""
                if (raw_user is None or (isinstance(raw_user, float) and pd.isna(raw_user)))
                else str(raw_user).strip()
            )

            try:
                if impersonated_user:
                    print(
                        f"    ▶ Executing '{test_name}' "
                        f"as '{impersonated_user}' (impersonated)…"
                    )
                    result_df = _execute_test_as_user(
                        workspace_id, dataset_id, test_name, impersonated_user
                    )
                else:
                    print(f"    ▶ Executing '{test_name}'…")
                    result_df = _execute_test(workspace_id, dataset_id, test_name)
            except Exception as exc:
                print(f"    ✗ Error executing '{test_name}': {exc}")
                continue

            # Annotate results with workspace / model context
            result_df.insert(0, "TestFunctionName", test_name)
            result_df.insert(0, "SemanticModelName", dataset_name)
            result_df.insert(0, "SemanticModelId", dataset_id)
            result_df.insert(0, "WorkspaceName", workspace_name)
            result_df.insert(0, "WorkspaceId", workspace_id)

            all_results.append(result_df)

print("\n✅ Test execution complete.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## Cell 6 – Display results
# 
# All results are combined into a single DataFrame. The summary line shows totals for passed and failed tests across all workspaces and models.

# CELL ********************

if not all_results:
    print(
        "No test results were collected.\n"
        "Verify that:\n"
        "  1. WORKSPACE_GUIDS contains valid workspace GUIDs.\n"
        "  2. PQL.Assert is installed in the target semantic models.\n"
        "  3. The notebook has Build (or higher) access to each workspace."
    )
else:
    results_df = pd.concat(all_results, ignore_index=True)

    # Summary
    total = len(results_df)
    passed = int(results_df["Passed"].sum()) if "Passed" in results_df.columns else 0
    failed = total - passed
    print(f"Results  |  Total: {total}  |  ✅ Passed: {passed}  |  ❌ Failed: {failed}")
    print()

    # Display the full results table
    display(results_df)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
