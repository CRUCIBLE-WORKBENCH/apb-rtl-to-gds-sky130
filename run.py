import os
import sys
import shutil
import subprocess
from pathlib import Path


# ==============================================================================
# PATH HELPERS
# ==============================================================================

def resolve_path(project_root, path_value):
    """
    Resolve relative paths from PROJECT_ROOT.
    Absolute paths are returned unchanged.
    """

    project_root = Path(project_root).resolve()
    path = Path(path_value)

    if path.is_absolute():
        return path

    return project_root / path


# ==============================================================================
# CLEAN OPERATIONS
# ==============================================================================

def clean_files(project_root, *files):
    """
    Cross-platform replacement for:

        rm -f file1 file2 file3
    """

    for file_name in files:
        if not file_name:
            continue

        file_path = resolve_path(project_root, file_name)

        if file_path.exists():
            if file_path.is_file() or file_path.is_symlink():
                file_path.unlink()
                print(f"Deleted: {file_path}")
            else:
                print(f"Skipped, not a file: {file_path}")
        else:
            print(f"Not found, skipping: {file_path}")


def clean_dirs(project_root, *directories):
    """
    Cross-platform replacement for:

        rm -rf dir1 dir2 dir3
    """

    for directory_name in directories:
        if not directory_name:
            continue

        directory = resolve_path(
            project_root,
            directory_name
        )

        if directory.exists() and directory.is_dir():
            shutil.rmtree(directory)
            print(f"Deleted directory: {directory}")
        else:
            print(
                f"Directory not found, skipping: "
                f"{directory}"
            )


def clean_pycache(project_root, search_root):
    """
    Recursively remove all __pycache__ directories.
    """

    root = resolve_path(
        project_root,
        search_root
    )

    if not root.exists():
        print(f"Directory not found: {root}")
        return

    pycache_dirs = list(
        root.rglob("__pycache__")
    )

    for directory in pycache_dirs:
        if directory.is_dir():
            shutil.rmtree(directory)
            print(
                f"Deleted directory: {directory}"
            )


def clean_glob(project_root, *patterns):
    """
    Cross-platform replacement for wildcard cleanup:

        rm -f results/*.log results/*.ext
    """

    project_root = Path(
        project_root
    ).resolve()

    for pattern in patterns:
        if not pattern:
            continue

        matches = list(
            project_root.glob(pattern)
        )

        if not matches:
            print(
                f"No matches, skipping: "
                f"{pattern}"
            )
            continue

        for path in matches:
            if path.is_file() or path.is_symlink():
                path.unlink()
                print(f"Deleted: {path}")


# ==============================================================================
# WAVEFORM
# ==============================================================================

def move_waveform(project_root, wave_out):
    """
    Move apbWaveform.vcd from PROJECT_ROOT
    to the requested output path.
    """

    project_root = Path(
        project_root
    ).resolve()

    source = (
        project_root
        / "apbWaveform.vcd"
    )

    destination = resolve_path(
        project_root,
        wave_out
    )

    if not source.exists():
        print(
            f"Waveform not found: {source}"
        )
        return

    destination.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    if destination.exists():
        if destination.is_file():
            destination.unlink()

    shutil.move(
        str(source),
        str(destination)
    )

    print(
        f"Moved: {source} -> {destination}"
    )


# ==============================================================================
# PDK DETECTION
# ==============================================================================

def find_pdk_root():
    """
    Cross-platform replacement for:

        find ~/.ciel -path \
        "*/sky130A/libs.tech/netgen/sky130A_setup.tcl"
    """

    ciel_root = (
        Path.home()
        / ".ciel"
    )

    if not ciel_root.exists():
        return None

    for setup_file in ciel_root.rglob(
        "sky130A_setup.tcl"
    ):
        normalized = (
            setup_file
            .as_posix()
        )

        if normalized.endswith(
            "/sky130A/libs.tech/"
            "netgen/sky130A_setup.tcl"
        ):
            return setup_file.parents[3]

    return None


def prepare_environment():
    """
    Prepare environment variables for EDA tools.
    """

    env = os.environ.copy()

    if not env.get("PDK_ROOT"):
        pdk_root = find_pdk_root()

        if pdk_root is not None:
            env["PDK_ROOT"] = str(
                pdk_root
            )

            print(
                f"PDK_ROOT: {pdk_root}"
            )

        else:
            print(
                "Warning: PDK_ROOT could "
                "not be detected."
            )

    return env


# ==============================================================================
# PREREQUISITE STAGES
# ==============================================================================

def ensure_stage(
    project_root,
    required_file,
    stage_dir,
    target=None
):
    """
    If required_file does not exist,
    run the prerequisite Makefile stage.
    """

    project_root = Path(
        project_root
    ).resolve()

    required_path = resolve_path(
        project_root,
        required_file
    )

    if required_path.exists():
        print(
            f"Found required file: "
            f"{required_path}"
        )
        return

    print(
        f"Required file missing: "
        f"{required_path}"
    )

    command = [
        "make",
        "-C",
        stage_dir,
    ]

    if target:
        command.append(target)

    print(
        "Running prerequisite:",
        " ".join(command)
    )

    result = subprocess.run(
        command,
        cwd=project_root,
        check=False,
    )

    if result.returncode != 0:
        print(
            "Prerequisite stage failed "
            f"with exit code "
            f"{result.returncode}"
        )

        sys.exit(
            result.returncode
        )

    if not required_path.exists():
        print(
            "Error: prerequisite stage "
            "completed, but required file "
            f"was not created: "
            f"{required_path}"
        )

        sys.exit(1)


# ==============================================================================
# OPENROAD
# ==============================================================================

def run_openroad(
    project_root,
    tcl_script
):
    """
    Run an OpenROAD TCL script through Igny.
    """

    project_root = Path(
        project_root
    ).resolve()

    script_path = resolve_path(
        project_root,
        tcl_script
    )

    if not script_path.exists():
        print(
            "OpenROAD TCL script "
            f"not found: {script_path}"
        )
        sys.exit(1)

    env = prepare_environment()

    command = [
        "igny",
        "run",
        "openroad",
        "-exit",
        tcl_script,
    ]

    print(
        "Running:",
        " ".join(command)
    )

    result = subprocess.run(
        command,
        cwd=project_root,
        env=env,
        check=False,
    )

    if result.returncode != 0:
        print(
            "OpenROAD failed with "
            f"exit code "
            f"{result.returncode}"
        )

        sys.exit(
            result.returncode
        )


# ==============================================================================
# STA
# ==============================================================================

def run_sta(
    project_root,
    corner,
    report_file
):
    """
    Cross-platform replacement for:

        STA_CORNER=tt igny run openroad ... | tee report.txt
    """

    project_root = Path(
        project_root
    ).resolve()

    report_path = resolve_path(
        project_root,
        report_file
    )

    report_path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    env = prepare_environment()

    env["STA_CORNER"] = corner

    print(
        f"STA_CORNER: {corner}"
    )

    print(
        f"Timing report: "
        f"{report_path}"
    )

    command = [
        "igny",
        "run",
        "openroad",
        "-exit",
        "08_sta/openroad_sta.tcl",
    ]

    print(
        "Running:",
        " ".join(command)
    )

    with report_path.open(
        "w",
        encoding="utf-8",
        errors="replace",
    ) as report:

        process = subprocess.Popen(
            command,
            cwd=project_root,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        if process.stdout is not None:
            for line in process.stdout:
                print(
                    line,
                    end=""
                )

                report.write(line)
                report.flush()

        return_code = (
            process.wait()
        )

    if return_code != 0:
        print(
            "STA failed with exit "
            f"code {return_code}"
        )

        sys.exit(
            return_code
        )

    print(
        f"STA completed successfully: "
        f"{corner}"
    )


# ==============================================================================
# GDS
# ==============================================================================

def run_gds(project_root):
    """
    Run the GDS streamout shell script.

    Currently requires Bash.
    """

    project_root = Path(
        project_root
    ).resolve()

    env = prepare_environment()

    script = (
        project_root
        / "10_gds"
        / "run_gds_streamout.sh"
    )

    if not script.exists():
        print(
            "GDS streamout script "
            f"not found: {script}"
        )

        sys.exit(1)

    bash = shutil.which(
        "bash"
    )

    if bash is None:
        print(
            "Error: Bash was not found. "
            "run_gds_streamout.sh "
            "currently requires Bash."
        )

        sys.exit(1)

    command = [
        bash,
        str(script),
    ]

    print(
        "Running:",
        " ".join(command)
    )

    result = subprocess.run(
        command,
        cwd=project_root,
        env=env,
        check=False,
    )

    if result.returncode != 0:
        print(
            "GDS streamout failed "
            f"with exit code "
            f"{result.returncode}"
        )

        sys.exit(
            result.returncode
        )


# ==============================================================================
# PHYSICAL VERIFICATION
# ==============================================================================

def run_physical(project_root):
    """
    Run physical verification shell script.

    Currently requires Bash.
    """

    project_root = Path(
        project_root
    ).resolve()

    script = (
        project_root
        / "11_physical_verification"
        / "run_physical_verification.sh"
    )

    if not script.exists():
        print(
            "Physical verification "
            f"script not found: {script}"
        )

        sys.exit(1)

    bash = shutil.which(
        "bash"
    )

    if bash is None:
        print(
            "Error: Bash was not found. "
            "run_physical_verification.sh "
            "currently requires Bash."
        )

        sys.exit(1)

    command = [
        bash,
        str(script),
    ]

    print(
        "Running:",
        " ".join(command)
    )

    result = subprocess.run(
        command,
        cwd=project_root,
        check=False,
    )

    if result.returncode != 0:
        print(
            "Physical verification "
            f"failed with exit code "
            f"{result.returncode}"
        )

        sys.exit(
            result.returncode
        )


# ==============================================================================
# COMMAND LINE
# ==============================================================================

def print_usage():
    print("Usage:")

    print(
        "  python run.py clean_files "
        "<project_root> "
        "<file1> [file2 ...]"
    )

    print(
        "  python run.py clean_dirs "
        "<project_root> "
        "<dir1> [dir2 ...]"
    )

    print(
        "  python run.py clean_pycache "
        "<project_root> "
        "<search_root>"
    )

    print(
        "  python run.py clean_glob "
        "<project_root> "
        "<pattern1> [pattern2 ...]"
    )

    print(
        "  python run.py move_waveform "
        "<project_root> "
        "<wave_out>"
    )

    print(
        "  python run.py ensure_stage "
        "<project_root> "
        "<required_file> "
        "<stage_dir> [target]"
    )

    print(
        "  python run.py run_openroad "
        "<project_root> "
        "<tcl_script>"
    )

    print(
        "  python run.py run_sta "
        "<project_root> "
        "<corner> <report>"
    )

    print(
        "  python run.py run_gds "
        "<project_root>"
    )

    print(
        "  python run.py run_physical "
        "<project_root>"
    )


def main():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    command = sys.argv[1]

    try:

        if command == "clean_files":

            if len(sys.argv) < 4:
                print_usage()
                sys.exit(1)

            clean_files(
                sys.argv[2],
                *sys.argv[3:]
            )

        elif command == "clean_dirs":

            if len(sys.argv) < 4:
                print_usage()
                sys.exit(1)

            clean_dirs(
                sys.argv[2],
                *sys.argv[3:]
            )

        elif command == "clean_pycache":

            if len(sys.argv) != 4:
                print_usage()
                sys.exit(1)

            clean_pycache(
                sys.argv[2],
                sys.argv[3]
            )

        elif command == "clean_glob":

            if len(sys.argv) < 4:
                print_usage()
                sys.exit(1)

            clean_glob(
                sys.argv[2],
                *sys.argv[3:]
            )

        elif command == "move_waveform":

            if len(sys.argv) != 4:
                print_usage()
                sys.exit(1)

            move_waveform(
                sys.argv[2],
                sys.argv[3]
            )

        elif command == "ensure_stage":

            if len(sys.argv) not in (
                5,
                6
            ):
                print_usage()
                sys.exit(1)

            ensure_stage(
                sys.argv[2],
                sys.argv[3],
                sys.argv[4],
                (
                    sys.argv[5]
                    if len(sys.argv) == 6
                    else None
                )
            )

        elif command == "run_openroad":

            if len(sys.argv) != 4:
                print_usage()
                sys.exit(1)

            run_openroad(
                sys.argv[2],
                sys.argv[3]
            )

        elif command == "run_sta":

            if len(sys.argv) != 5:
                print_usage()
                sys.exit(1)

            run_sta(
                sys.argv[2],
                sys.argv[3],
                sys.argv[4]
            )

        elif command == "run_gds":

            if len(sys.argv) != 3:
                print_usage()
                sys.exit(1)

            run_gds(
                sys.argv[2]
            )

        elif command == "run_physical":

            if len(sys.argv) != 3:
                print_usage()
                sys.exit(1)

            run_physical(
                sys.argv[2]
            )

        else:
            print(
                f"Unknown command: "
                f"{command}"
            )

            print_usage()

            sys.exit(1)

    except KeyboardInterrupt:
        print(
            "\nOperation cancelled."
        )

        sys.exit(130)

    except Exception as error:
        print(
            f"Error: {error}"
        )

        sys.exit(1)


if __name__ == "__main__":
    main()