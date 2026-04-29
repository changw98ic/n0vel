import unittest

from filter_xcodebuild_test_output import filter_lines


class FilterXcodebuildTestOutputTests(unittest.TestCase):
    def test_filters_known_noise_lines(self) -> None:
        lines = [
            "note: Removed stale file '/tmp/foo'",
            "warning: Stale file '/tmp/bar' is located outside of the allowed root paths.",
            "2026-04-21 11:44:52.474 appintentsmetadataprocessor[95696:23537987] warning: Metadata extraction skipped. No AppIntents.framework dependency found.",
            "2026-04-21 11:44:55.207 xcodebuild[95471:23536994] [MT] IDETestOperationsObserverDebug: 2.310 elapsed -- Testing started completed.",
            "** TEST SUCCEEDED **",
        ]

        self.assertEqual(filter_lines(lines), ["** TEST SUCCEEDED **"])

    def test_keeps_real_errors_and_test_results(self) -> None:
        lines = [
            "Testing started",
            "Test case 'RunnerTests.testWindowSizingMatchesDesignBaseline()' passed on 'My Mac - novel_writer (95754)' (0.002 seconds)",
            "error: Build input file cannot be found",
        ]

        self.assertEqual(filter_lines(lines), lines)


if __name__ == "__main__":
    unittest.main()
