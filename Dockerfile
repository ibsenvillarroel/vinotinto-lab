FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ARG INSTALL_DEV=false

COPY pyproject.toml ./
COPY src ./src

RUN python -m pip install --upgrade pip \
    && if [ "$INSTALL_DEV" = "true" ]; then \
         python -m pip install --no-cache-dir -e ".[dev]"; \
       else \
         python -m pip install --no-cache-dir -e .; \
       fi

CMD ["python", "-c", "print('Vinotinto Lab analytics container ready')"]