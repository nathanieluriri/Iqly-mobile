import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


WORKFLOW = (
    Path(__file__).resolve().parents[1]
    / ".github"
    / "workflows"
    / "play-upload-testing-tracks.yml"
)
RELEASE_WORKFLOW = (
    Path(__file__).resolve().parents[1]
    / ".github"
    / "workflows"
    / "shorebird-release.yml"
)
GIT_BASH = Path(r"C:\Program Files\Git\bin\bash.exe")
BASH = str(GIT_BASH) if GIT_BASH.exists() else "bash"


class PlayUploadWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = yaml.load(
            WORKFLOW.read_text(encoding="utf-8"), Loader=yaml.BaseLoader
        )
        cls.steps = cls.workflow["jobs"]["upload"]["steps"]

    def step(self, name):
        return next(step for step in self.steps if step.get("name") == name)

    def test_uploads_an_existing_aab_to_all_testing_tracks_without_rebuilding(self):
        self.assertIn("workflow_dispatch", self.workflow["on"])
        download = self.step("Download existing release artifact")
        self.assertEqual(download["uses"], "dawidd6/action-download-artifact@v6")
        self.assertEqual(download["with"]["run_id"], "${{ inputs.run_id }}")
        self.assertEqual(
            download["with"]["name"], "${{ inputs.artifact_name }}"
        )

        upload = self.step("Upload AAB to internal alpha and beta")
        self.assertEqual(upload["uses"], "r0adkll/upload-google-play@v1")
        self.assertEqual(upload["with"]["packageName"], "net.iqly.app")
        self.assertEqual(upload["with"]["releaseFiles"], "${{ env.AAB_PATH }}")
        self.assertEqual(upload["with"]["tracks"], "internal,alpha,beta")
        self.assertEqual(upload["with"]["status"], "completed")
        self.assertNotIn("changesNotSentForReview", upload["with"])

        for step in self.steps:
            self.assertNotIn("shorebirdtech/setup-shorebird", step.get("uses", ""))
            self.assertNotRegex(
                step.get("run", ""), r"(?m)^.*\b(shorebird release|flutter build)\b"
            )

    def run_selector(self, filenames):
        script = self.step("Select the AAB")["run"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifacts = root / "artifacts"
            artifacts.mkdir()
            for filename in filenames:
                (artifacts / filename).write_bytes(b"aab")
            env_path = root / "github-env"
            env = os.environ.copy()
            env["GITHUB_ENV"] = env_path.as_posix()
            result = subprocess.run(
                [BASH, "-c", script],
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
            )
            output = env_path.read_text(encoding="utf-8") if env_path.exists() else ""
            return result, output

    def test_selector_rejects_missing_and_multiple_aabs(self):
        for filenames in ([], ["one.aab", "two.aab"]):
            with self.subTest(filenames=filenames):
                result, output = self.run_selector(filenames)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("AAB_PATH=", output)

    def test_selector_exports_exactly_one_aab(self):
        result, output = self.run_selector(["iqly-1.1.1+14.aab"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("AAB_PATH=artifacts/iqly-1.1.1+14.aab\n", output)
        self.assertIn("AAB_SHA256=", output)


class ShorebirdReleaseWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = yaml.load(
            RELEASE_WORKFLOW.read_text(encoding="utf-8"), Loader=yaml.BaseLoader
        )
        cls.steps = cls.workflow["jobs"]["release"]["steps"]

    def test_release_upload_is_manual_and_selectable(self):
        self.assertEqual(set(self.workflow["on"]), {"workflow_dispatch"})
        dispatch = self.workflow["on"]["workflow_dispatch"] or {}
        self.assertIn("inputs", dispatch)
        inputs = dispatch["inputs"]
        self.assertEqual(inputs["upload"]["type"], "boolean")
        self.assertEqual(inputs["upload"]["default"], "true")
        self.assertIn("reuse_release", inputs)
        self.assertEqual(inputs["reuse_release"]["type"], "boolean")
        self.assertEqual(inputs["reuse_release"]["default"], "false")
        self.assertEqual(inputs["track"]["type"], "choice")
        self.assertEqual(
            inputs["track"]["options"], ["internal", "alpha", "beta", "production"]
        )

        testing = yaml.load(
            WORKFLOW.read_text(encoding="utf-8"), Loader=yaml.BaseLoader
        )
        testing_inputs = testing["on"]["workflow_dispatch"]["inputs"]
        self.assertIn("discard_production_draft", testing_inputs)
        self.assertEqual(
            testing_inputs["discard_production_draft"]["type"], "boolean"
        )
        self.assertEqual(
            testing_inputs["discard_production_draft"]["default"], "false"
        )
        self.assertIn("reference_existing", testing_inputs)
        self.assertEqual(testing_inputs["reference_existing"]["type"], "boolean")
        self.assertEqual(testing_inputs["reference_existing"]["default"], "false")
        discard = next(
            step
            for step in testing["jobs"]["upload"]["steps"]
            if step.get("name") == "Discard production draft for this version code"
        )
        self.assertEqual(discard["if"], "inputs.discard_production_draft")
        self.assertIn('release.get("status") != "draft"', discard["run"])
        self.assertIn("tracks().update", discard["run"])

        assign = next(
            step
            for step in testing["jobs"]["upload"]["steps"]
            if step.get("name") == "Assign existing version code to testing tracks"
        )
        self.assertEqual(assign["if"], "inputs.reference_existing")
        self.assertIn('["qa", "alpha", "beta"]', assign["run"])
        self.assertIn('"status": "completed"', assign["run"])
        testing_upload = next(
            step
            for step in testing["jobs"]["upload"]["steps"]
            if step.get("name") == "Upload AAB to internal alpha and beta"
        )
        self.assertEqual(testing_upload["if"], "${{ !inputs.reference_existing }}")

        download = next(
            step
            for step in self.steps
            if step.get("name") == "Download existing AAB from Shorebird"
        )
        self.assertEqual(download["if"], "inputs.reuse_release")
        self.assertIn('/releases"', download["run"])
        self.assertIn('select(.version == $version)', download["run"])
        self.assertIn("/releases/$release_id/artifacts", download["run"])
        self.assertIn('iqly-$version.aab', download["run"])

        upload = next(
            step for step in self.steps if step.get("name") == "Send the AAB to Play"
        )
        self.assertEqual(upload["uses"], "r0adkll/upload-google-play@v1")
        self.assertEqual(upload["if"], "inputs.upload")
        self.assertEqual(upload["with"]["tracks"], "${{ inputs.track }}")
        self.assertEqual(
            upload["with"]["status"],
            "${{ inputs.track == 'production' && 'draft' || 'completed' }}",
        )
        self.assertEqual(
            upload["with"]["changesNotSentForReview"],
            "${{ inputs.track != 'production' && true || false }}",
        )


if __name__ == "__main__":
    unittest.main()
