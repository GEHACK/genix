# Write-only receiver for runtimes ISO reports; run it with compose.yaml.
# receiver.py is stdlib-only, so the official python image is all it needs.
FROM python:3.13-alpine@sha256:8bcfa47b04b853a17aaf909362b847b2112fd6ec4105ea553ef9a43bafbb5916

COPY receiver.py /app/receiver.py
RUN install -d -o 65534 -g 65534 -m 0700 /data

USER 65534:65534
ENV PYTHONUNBUFFERED=1
EXPOSE 8095
VOLUME /data

# compose.yaml mounts the token hash from the repo at /app/upload_token.sha256.
ENTRYPOINT ["python3", "/app/receiver.py"]
CMD ["0.0.0.0:8095", "/data", "/app/upload_token.sha256"]
