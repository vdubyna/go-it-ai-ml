#!/usr/bin/env python3
"""Export a torchvision MobileNetV2 model to TorchScript."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

# Keep downloaded torchvision weights inside the project workspace.
os.environ.setdefault("TORCH_HOME", str(Path(__file__).with_name(".cache") / "torch"))

import torch
from torchvision import models
from torchvision.models import MobileNet_V2_Weights


def parse_args() -> argparse.Namespace:
    default_output = Path(__file__).with_name("model.pt")
    parser = argparse.ArgumentParser(
        description="Export torchvision MobileNetV2 to a TorchScript .pt file."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=default_output,
        help=f"Output model path. Default: {default_output}",
    )
    parser.add_argument(
        "--no-pretrained",
        action="store_true",
        help="Do not download ImageNet weights; export randomly initialized weights.",
    )
    parser.add_argument(
        "--strict-pretrained",
        action="store_true",
        help="Fail instead of falling back to random weights if pretrained weights cannot be loaded.",
    )
    return parser.parse_args()


def build_model(use_pretrained: bool, strict_pretrained: bool) -> torch.nn.Module:
    if not use_pretrained:
        print("Exporting MobileNetV2 with random weights.")
        return models.mobilenet_v2(weights=None)

    try:
        print("Loading MobileNetV2 with ImageNet pretrained weights.")
        return models.mobilenet_v2(weights=MobileNet_V2_Weights.DEFAULT)
    except Exception as exc:
        if strict_pretrained:
            raise

        print(
            "WARNING: pretrained weights could not be loaded. "
            "Falling back to random weights so the export remains reproducible offline."
        )
        print(f"Original error: {exc}")
        return models.mobilenet_v2(weights=None)


def export_torchscript(model: torch.nn.Module, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    model.eval()

    dummy_input = torch.rand(1, 3, 224, 224)
    with torch.inference_mode():
        traced_model = torch.jit.trace(model, dummy_input)
        traced_model = torch.jit.optimize_for_inference(traced_model)

    traced_model.save(str(output_path))
    size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"Saved TorchScript model to {output_path} ({size_mb:.2f} MB).")


def main() -> None:
    args = parse_args()
    model = build_model(
        use_pretrained=not args.no_pretrained,
        strict_pretrained=args.strict_pretrained,
    )
    export_torchscript(model, args.output)


if __name__ == "__main__":
    main()
