FROM python:3.12-slim

WORKDIR /app

# Instalar dependencias del sistema necesarias para SciPy
RUN apt-get update && apt-get install -y gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Comando para ejecutar el script principal
CMD ["python", "-u", "main_controller.py"]