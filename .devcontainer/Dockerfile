ARG VARIANT="3"
FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    # Required by pdftoimage
    imagemagick poppler-utils

RUN gem install solargraph

# Environment variables required by Jekyll
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    TZ="UTC" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US" \
    GITHUB_USER="jeandeaual" \
    GITHUB_TOKEN=""
