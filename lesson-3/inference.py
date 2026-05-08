#!/usr/bin/env python3
"""Run top-k image classification with a TorchScript MobileNetV2 model."""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from PIL import Image
from torchvision.models import MobileNet_V2_Weights


DEFAULT_MODEL_PATH = Path(__file__).with_name("model.pt")
DEFAULT_TOP_K = 3


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run TorchScript image inference and print top-k predictions."
    )
    parser.add_argument("image", type=Path, help="Path to an input image.")
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL_PATH,
        help=f"Path to TorchScript model. Default: {DEFAULT_MODEL_PATH}",
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=DEFAULT_TOP_K,
        help=f"Number of classes to print. Default: {DEFAULT_TOP_K}",
    )
    return parser.parse_args()


def load_image(image_path: Path) -> Image.Image:
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    return Image.open(image_path).convert("RGB")


def run_inference(model_path: Path, image_path: Path, top_k: int) -> list[tuple[int, str, float]]:
    if not model_path.exists():
        raise FileNotFoundError(
            f"Model not found: {model_path}. Run `python3 export_model.py` first."
        )

    weights = MobileNet_V2_Weights.DEFAULT
    transform = weights.transforms()
    categories = weights.meta["categories"]

    image = load_image(image_path)
    input_tensor = transform(image).unsqueeze(0)

    model = torch.jit.load(str(model_path), map_location="cpu")
    model.eval()

    with torch.inference_mode():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)
        limit = min(max(top_k, 1), probabilities.shape[0])
        scores, class_ids = torch.topk(probabilities, limit)

    predictions: list[tuple[int, str, float]] = []
    for class_id, score in zip(class_ids.tolist(), scores.tolist()):
        label = categories[class_id] if class_id < len(categories) else f"class_{class_id}"
        predictions.append((class_id, label, score))

    return predictions


def main() -> None:
    args = parse_args()
    predictions = run_inference(args.model, args.image, args.top_k)

    print(f"Image: {args.image}")
    print(f"Model: {args.model}")
    print(f"Top-{len(predictions)} predictions:")
    for rank, (class_id, label, score) in enumerate(predictions, start=1):
        print(f"{rank}. class_id={class_id} label={label} probability={score:.4f}")


if __name__ == "__main__":
    main()
