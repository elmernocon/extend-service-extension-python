import unittest

from argparse import ArgumentParser


def main(**kwargs):
    loader = unittest.TestLoader()
    runner = None

    if (fmt := kwargs.get("format")) and fmt == "tap":
        try:
            import tap  # pip install tap.py

            runner = tap.TAPTestRunner()
            runner.set_stream(True)
        except ImportError:
            pass

    if runner is None:
        runner = unittest.TextTestRunner()

    import app_tests.services
    suite = unittest.TestSuite(
        [
            loader.loadTestsFromModule(app_tests.services),
        ]
    )
    result = runner.run(suite)

    if not result.wasSuccessful():
        exit(1)


def parse_args():
    parser = ArgumentParser()

    parser.add_argument(
        "-f",
        "--format",
        default="tap",
        choices=("default", "tap"),
    )

    result = vars(parser.parse_args())

    return result


if __name__ == "__main__":
    main(**parse_args())
