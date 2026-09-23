import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "cleanup_images", Path(__file__).with_name("cleanup-images.py")
)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


def digest(number):
    return f"sha256:{number:064x}"


def signature(number):
    return f"sha256-{number:064x}.sig"


def version(number, *tags, day=1):
    return {
        "id": number, "name": digest(number),
        "created_at": f"2026-09-{day:02d}T00:00:00Z",
        "metadata": {"container": {"tags": list(tags)}},
    }


def builds():
    return [version(n, "latest" if n == 5 else f"build-{n}", day=n)
            for n in range(1, 6)]


class CleanupTests(unittest.TestCase):
    def selected(self, versions, manifests=None, protect=5):
        manifests = manifests or {}
        return [v["id"] for v in cleanup.plan_cleanup(
            versions, lambda d: manifests.get(d, {}), digest(protect),
        )]

    def test_latest_plus_two_recent_builds_and_their_signatures(self):
        versions = builds() + [version(10 + n, signature(n)) for n in range(1, 6)]
        self.assertEqual(self.selected(versions), [1, 2, 11, 12])

    def test_sort_by_creation_not_response_order(self):
        self.assertEqual(set(self.selected(list(reversed(builds())))), {1, 2})

    def test_latest_is_kept_even_when_old(self):
        versions = builds()
        versions[-1]["created_at"] = "2020-01-01T00:00:00Z"
        self.assertEqual(self.selected(versions), [1, 2])

    def test_current_digest_is_protected_even_if_not_latest(self):
        self.assertEqual(self.selected(builds(), protect=1), [2])

    def test_nested_untagged_children_and_their_signatures_are_kept(self):
        versions = builds() + [version(6), version(7), version(8),
                               version(16, signature(6)), version(17, signature(7))]
        manifests = {
            digest(5): {"manifests": [{"digest": digest(6)}]},
            digest(6): {"manifests": [{"digest": digest(8)}]},
        }
        self.assertEqual(self.selected(versions, manifests), [1, 2, 7, 17])

    def test_unknown_artifacts_mixed_tags_and_shared_signatures(self):
        versions = builds() + [
            version(20, signature(1), "manual"),
            version(21, "sha256-invalid.sig"),
            version(22, f"sha256-{'a' * 64}.att"),
            version(23, signature(1), signature(5)),
            version(24, signature(99)),
        ]
        self.assertEqual(self.selected(versions), [1, 2, 24])

    def test_retained_artifact_subject_is_kept(self):
        versions = builds() + [version(20, "sha256-artifact.att")]
        self.assertEqual(self.selected(versions, {
            digest(20): {"subject": {"digest": digest(1)}},
        }), [2])

    def test_missing_latest_or_current_aborts(self):
        for versions in ([], builds()[:-1], [version(5, "build-5")]):
            with self.subTest(versions=versions), self.assertRaises(ValueError):
                self.selected(versions)

    @patch.object(cleanup.subprocess, "run")
    def test_pagination_and_deletion_order(self, run):
        versions = builds() + [version(11, signature(1)), version(15, signature(5))]
        def response(command, **kwargs):
            if "--paginate" in command:
                return Mock(stdout=json.dumps([versions[:3], versions[3:]]))
            return Mock(stdout="{}")
        run.side_effect = response
        cleanup.cleanup("Drostina", "ember", digest(5), delete=True)
        calls = [c.args[0] for c in run.call_args_list]
        self.assertIn("--slurp", calls[0])
        deletions = [c[-1].rsplit("/", 1)[1] for c in calls if "DELETE" in c]
        self.assertEqual(deletions, ["1", "2", "11"])
        first_delete = next(i for i, c in enumerate(calls) if "DELETE" in c)
        self.assertTrue(all("DELETE" in c for c in calls[first_delete:]))

    @patch.object(cleanup.subprocess, "run")
    def test_dry_run_never_deletes(self, run):
        run.side_effect = lambda command, **kw: Mock(stdout=(
            json.dumps([builds()]) if "--paginate" in command else "{}"
        ))
        cleanup.cleanup("Drostina", "ember", digest(5))
        self.assertFalse(any("DELETE" in c.args[0] for c in run.call_args_list))

    @patch.object(cleanup.subprocess, "run")
    def test_listing_or_manifest_failure_never_deletes(self, run):
        for failure_at in (0, 1):
            with self.subTest(failure_at=failure_at):
                run.reset_mock()
                run.side_effect = ([Mock(stdout=json.dumps([builds()]))] * failure_at
                                   + [subprocess.CalledProcessError(1, "read")])
                with self.assertRaises(subprocess.CalledProcessError):
                    cleanup.cleanup("Drostina", "ember", digest(5), delete=True)
                self.assertFalse(any("DELETE" in c.args[0] for c in run.call_args_list))

    @patch.object(cleanup.subprocess, "run")
    def test_failed_image_deletion_stops_before_signatures(self, run):
        versions = builds() + [version(11, signature(1))]
        def response(command, **kwargs):
            if "DELETE" in command:
                raise subprocess.CalledProcessError(1, command)
            return Mock(stdout=json.dumps([versions]) if "--paginate" in command else "{}")
        run.side_effect = response
        with self.assertRaises(subprocess.CalledProcessError):
            cleanup.cleanup("Drostina", "ember", digest(5), delete=True)
        self.assertEqual(sum("DELETE" in c.args[0] for c in run.call_args_list), 1)


if __name__ == "__main__":
    unittest.main()
