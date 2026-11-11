# CloudSleuth web viewer: the image Jenkins builds, tests and deploys on EC2.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies first, so this layer is cached between builds.
# requirements-dev.txt includes pytest, so Jenkins can run the tests inside this same image.
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY pyproject.toml ./
COPY cloudsleuth_zeroth/ cloudsleuth_zeroth/
COPY tests/ tests/
COPY data/demo_app/ data/demo_app/

# Dataset 1 (simulator) is generated at build time: 144 cases, standard library only.
RUN python -m cloudsleuth_zeroth.simulator.generate --out data/simulator

# Run as a normal user, not root.
RUN useradd --create-home --uid 1001 cloudsleuth && chown -R cloudsleuth /app
USER cloudsleuth

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)"

CMD ["uvicorn", "cloudsleuth_zeroth.viewer.app:app", "--host", "0.0.0.0", "--port", "8000"]
