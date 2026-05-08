# HW-3: Docker для TorchScript ML inference

Цей проєкт демонструє базовий MLOps workflow: підготовка середовища, експорт PyTorch моделі у TorchScript, запуск inference локально та у двох Docker-образах: fat і slim.

## Структура

```text
lesson-3/
├── inference.py
├── export_model.py
├── model.pt
├── Dockerfile.fat
├── Dockerfile.slim
├── install_dev_tools.sh
├── requirements.txt
├── report.md
├── sample.jpg
└── docs/
```

## Підготовка середовища

```bash
cd lesson-3
chmod +x install_dev_tools.sh
./install_dev_tools.sh
```

Скрипт перевіряє Docker, Docker Compose, Python >= 3.9, pip, Django, torch, torchvision і pillow. Логи пишуться в `install.log`.

## Експорт TorchScript моделі

```bash
cd lesson-3
python3 export_model.py
```

За замовчуванням експортується `torchvision.models.mobilenet_v2` з ImageNet weights у файл `model.pt`. Якщо weights недоступні без інтернету, скрипт попередить про це і згенерує TorchScript модель з random weights, щоб workflow залишався відтворюваним.

## Локальний inference

```bash
cd lesson-3
python3 inference.py sample.jpg
```

Приклад результату:

```text
Top-3 predictions:
1. class_id=549 label=envelope probability=0.1363
2. class_id=446 label=binder probability=0.0263
3. class_id=419 label=Band Aid probability=0.0210
```

## Docker: fat image

```bash
cd lesson-3
docker build -f Dockerfile.fat -t hw3-pytorch-fat .
docker run --rm hw3-pytorch-fat
```

Запуск зі своїм зображенням:

```bash
docker run --rm -v "$PWD:/data" hw3-pytorch-fat /data/your-image.jpg
```

## Docker: slim image

```bash
cd lesson-3
docker build -f Dockerfile.slim -t hw3-pytorch-slim .
docker run --rm hw3-pytorch-slim
```

Запуск зі своїм зображенням:

```bash
docker run --rm -v "$PWD:/data" hw3-pytorch-slim /data/your-image.jpg
```

## Перевірка розміру та шарів

```bash
docker images hw3-pytorch-fat hw3-pytorch-slim
docker history hw3-pytorch-fat
docker history hw3-pytorch-slim
```

Висновки й порівняння описані в `report.md`.
