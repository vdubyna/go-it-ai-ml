# HW-3 Report: fat vs slim Docker images

## Мета

Підготувати inference-сервіс для TorchScript MobileNetV2 моделі, зібрати два Docker-образи та порівняти їх за розміром, кількістю шарів і наявністю зайвих інструментів.

## Реалізовано

- `install_dev_tools.sh` перевіряє Docker, Docker Compose, Python >= 3.9, pip, Django, torch, torchvision і pillow; за потреби встановлює відсутні компоненти; пише лог у `install.log`.
- `export_model.py` експортує `torchvision.models.mobilenet_v2` у TorchScript файл `model.pt`.
- `inference.py` приймає шлях до зображення, завантажує `model.pt` і виводить top-3 ImageNet класи.
- `Dockerfile.fat` створює навмисно важкий образ на базі Ubuntu з build/debug інструментами.
- `Dockerfile.slim` використовує multi-stage build і runtime на `python:3.11-slim`.

## Порівняння образів

| Образ | Dockerfile | Розмір | Кількість шарів | Коментар |
| --- | --- | ---: | ---: | --- |
| `hw3-pytorch-fat` | `Dockerfile.fat` | 1.22 GB | 6 | Ubuntu base + apt packages + build/debug tools |
| `hw3-pytorch-slim` | `Dockerfile.slim` | 835 MB | 8 | Multi-stage, тільки runtime venv + код + модель |

Цифри отримані локально після збірки:

```bash
docker image inspect hw3-pytorch-fat --format '{{.Size}} {{len .RootFS.Layers}}'
docker image inspect hw3-pytorch-slim --format '{{.Size}} {{len .RootFS.Layers}}'
```

Результат:

```text
hw3-pytorch-fat: 1222504733 bytes, 6 layers
hw3-pytorch-slim: 834894384 bytes, 8 layers
```

Обидва образи успішно запускають inference на `sample.jpg` і повертають top-3 класи.

```text
1. class_id=549 label=envelope probability=0.1363
2. class_id=446 label=binder probability=0.0263
3. class_id=419 label=Band Aid probability=0.0210
```

## Проблеми fat-образу

- Містить зайві інструменти для runtime: `build-essential`, `git`, `curl`, `wget`, `vim`, `htop`, `procps`.
- Має більший attack surface, бо містить більше системних пакетів.
- Повільніше завантажується в registry та довше переноситься між середовищами.
- Зайві пакети ускладнюють security scanning і можуть додавати CVE, які не потрібні для inference.

## Переваги slim-образу

- Multi-stage build відділяє встановлення залежностей від runtime.
- У фінальний образ копіюється лише virtualenv, `inference.py`, `model.pt` і `sample.jpg`.
- Немає `apt-get install` у runtime stage; entrypoints `apt`, `apt-get`, `apt-cache` прибрані з фінального образу.
- Менше зайвих інструментів і простіший шлях для оптимізації.

Перевірка зайвих інструментів:

```text
fat image:
/usr/bin/git
/usr/bin/curl
/usr/bin/vim
/usr/bin/apt-get
/usr/bin/htop

slim image:
no git/curl/vim/apt-get/htop found
```

## Подальша оптимізація

- Винести модель у volume або object storage, якщо потрібно часто оновлювати модель без rebuild image.
- Додати security scan (`trivy`, `docker scout`) і прибрати пакети, які не потрібні для production inference.
