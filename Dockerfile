# Multi-stage build to get static ffmpeg
FROM mwader/static-ffmpeg:6.0 AS ffmpeg

FROM n8nio/n8n:2.14.2

USER root

# Copy ffmpeg/ffprobe binaries
COPY --from=ffmpeg /ffmpeg /usr/local/bin/
COPY --from=ffmpeg /ffprobe /usr/local/bin/

# Ensure permissions
RUN chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

USER node
