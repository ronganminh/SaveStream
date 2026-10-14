FROM public.ecr.aws/docker/library/python:3.12-slim
COPY wheels /wheels
RUN pip install --no-index --find-links=/wheels celery redis
WORKDIR /app
COPY tasks.py .
