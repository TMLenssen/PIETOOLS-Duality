import argparse
import shutil
import subprocess
from pathlib import Path


def pdf_to_eps(pdf_path: Path, eps_path: Path, force: bool = False) -> bool:
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF file not found: {pdf_path}")

    if eps_path.exists() and not force and eps_path.stat().st_mtime >= pdf_path.stat().st_mtime:
        print(f"Skipping {pdf_path} -> {eps_path} (up to date)")
        return False

    eps_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pdftops", "-eps", str(pdf_path), str(eps_path)], check=True)
    print(f"Converted {pdf_path} -> {eps_path}")
    return True


def convert_figures(figures_dir: Path, force: bool = False) -> int:
    if shutil.which("pdftops") is None:
        raise RuntimeError("Could not find 'pdftops'. Install Poppler or make sure pdftops is on PATH.")

    if not figures_dir.exists():
        raise FileNotFoundError(f"Figures directory not found: {figures_dir}")

    pdf_files = sorted(figures_dir.rglob("*.pdf"))
    if not pdf_files:
        print(f"No PDF files found in {figures_dir}")
        return 0

    converted = 0
    for pdf_path in pdf_files:
        eps_path = pdf_path.with_suffix(".eps")
        converted += int(pdf_to_eps(pdf_path, eps_path, force=force))

    return converted


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert PDF figures to EPS.")
    parser.add_argument(
        "figures_dir",
        nargs="?",
        default="Figures",
        help="Directory containing PDF figures. Defaults to Figures.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate EPS files even when they are newer than the source PDFs.",
    )
    args = parser.parse_args()

    converted = convert_figures(Path(args.figures_dir), force=args.force)
    print(f"Done. Converted {converted} PDF file(s).")


if __name__ == "__main__":
    main()
