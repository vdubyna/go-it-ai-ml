# HW-3 Docs Index: Docker для ML-моделей

Цей файл - коротка wiki-навігація для агента й людини. Він допомагає швидко знайти потрібний навчальний матеріал для задач HW-3, але не замінює PDF: якщо потрібні точні приклади коду або формулювання завдання, відкривай відповідний PDF.

## Джерела

| Матеріал | Коли відкривати | Що шукати |
| --- | --- | --- |
| [Створення Docker-імеджу для ML-моделей.pdf](<Створення Docker-імеджу для ML-моделей.pdf>) | Потрібно зібрати базовий Docker image для PyTorch inference | `save_model.py`, TorchScript `.pt`, `app/inference.py`, `requirements.txt`, базовий `Dockerfile`, `docker build` |
| [Оптимізація Docker-image для ML-моделей.pdf](<Оптимізація Docker-image для ML-моделей.pdf>) | Потрібно зменшити image або привести Dockerfile до best practices | multi-stage build, `python:*slim`, кешування `requirements.txt`, `pip --no-cache-dir`, прибирання build/runtime зайвого |
| [Оркестрація контейнерів за допомогою Docker Compose.pdf](<Оркестрація контейнерів за допомогою Docker Compose.pdf>) | Потрібно зробити API або запустити кілька контейнерних сервісів разом | FastAPI, `app/model_utils.py`, `app/main.py`, `docker-compose.yml`, `docker compose up --build` |

## Рекомендований порядок роботи

1. Почати з базової контейнеризації моделі: створити TorchScript модель, CLI inference script, `requirements.txt` і Dockerfile.
2. Переконатися, що образ збирається й запускає inference локально.
3. Оптимізувати Dockerfile: slim base image, чисті шари, cache-friendly порядок `COPY`, multi-stage build за потреби.
4. Додати FastAPI шар для HTTP inference.
5. Додати `docker-compose.yml`, щоб запускати API однією командою.

## Очікувана структура навчального проєкту

```text
pytorch-image-classifier/
├── app/
│   ├── inference.py
│   ├── main.py
│   ├── model_utils.py
│   └── requirements.txt
├── model/
│   └── traced_model.pt
├── Dockerfile
├── docker-compose.yml
├── example.jpg
└── save_model.py
```

## Поточна структура HW-3

```text
hw-3/
├── inference.py
├── export_model.py
├── model.pt
├── Dockerfile.fat
├── Dockerfile.slim
├── install_dev_tools.sh
├── requirements.txt
├── report.md
├── README.md
├── sample.jpg
└── docs/
```

## Швидкий lookup для агента

| Задача | Джерело | Орієнтир реалізації |
| --- | --- | --- |
| Згенерувати модель | Створення Docker-імеджу | `save_model.py`: `models.resnet18(...)`, `model.eval()`, `torch.jit.trace(...)`, `model/traced_model.pt` |
| Запустити CLI inference | Створення Docker-імеджу | `app/inference.py`: завантажити TorchScript, preprocess image, `torch.no_grad()`, повернути class id |
| Описати Python залежності | Створення Docker-імеджу / Compose | Мінімум: `torch`, `torchvision`, `pillow`; для API також `fastapi`, `uvicorn[standard]`, `python-multipart` |
| Написати базовий Dockerfile | Створення Docker-імеджу | `python:3.11-slim`, `WORKDIR /app`, `COPY app/`, `COPY model/`, `pip install --no-cache-dir`, `ENTRYPOINT` |
| Зменшити Docker image | Оптимізація Docker-image | multi-stage build, копіювати `requirements.txt` перед кодом, не лишати build tools у фінальному image |
| Додати FastAPI endpoint | Docker Compose | `app/model_utils.py` для спільної inference логіки, `app/main.py` з `/` і `/predict` |
| Запустити API через Compose | Docker Compose | `docker-compose.yml`: service `model-api`, `build: .`, `ports: "8000:8000"`, volume для `./model:/app/model` |

## Команди з матеріалів

```bash
python3 save_model.py
docker build -t pytorch-infer .
docker build -t pytorch-infer-optimized .
docker images | grep pytorch
docker history pytorch-infer-optimized
docker compose up --build
```

## Нотатки для реалізації

- TorchScript модель очікується в `model/traced_model.pt`.
- Для inference обов'язково використовувати `model.eval()` і `torch.no_grad()`.
- Preprocessing для зображень у матеріалах: resize до `256`, center crop `224`, convert to tensor.
- Для Dockerfile тримай `requirements.txt` окремим раннім `COPY`, щоб Docker cache не ламався при кожній зміні коду.
- Фінальний runtime image не має містити зайві build/debug інструменти, якщо вони не потрібні для запуску моделі.
- У прикладі оптимізації з PDF є ризик неузгодженості версій Python: base image показаний як `python:3.13-slim`, але шлях копіювання залежностей містить `python3.11`. У реальному коді тримай версію Python і шлях `site-packages` узгодженими або використовуй більш надійний підхід через virtualenv/wheelhouse.
- Для FastAPI endpoint `/predict` приймає файл, читає bytes, викликає `predict_image(...)` і повертає JSON з `predicted_class`.

## Як оновлювати цей index

- Якщо додаються нові навчальні матеріали для HW-3, додай їх у таблицю "Джерела".
- Якщо фактична структура проєкту відрізняється від навчальної, додай окрему секцію "Поточна структура".
- Якщо з'являються локальні команди для перевірки домашнього завдання, додай їх у "Команди з матеріалів" або нову секцію "Локальна перевірка".
