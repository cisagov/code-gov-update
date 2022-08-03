FROM python:3.10.5-alpine3.16 as compile-stage

###
# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#
# Note: Additional labels are added by the build workflow.
###
LABEL org.opencontainers.image.authors="vm-fusion-dev-group@trio.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

# Dependencies necessary to build cryptography
# These are required to build the package if a pre-built wheel is not
# available on PyPI.
ENV CRYPTOGRAPHY_BUILD_DEPS \
  cargo \
  gcc \
  libffi-dev \
  musl-dev \
  openssl-dev \
  python3-dev

##
# Install the dependencies needed to build the cryptography Python package
##
RUN apk --no-cache add ${CRYPTOGRAPHY_BUILD_DEPS}

# The location for the Python venv we will create
ENV VIRTUAL_ENV="/.venv"

# Manually set up the Python virtual environment
RUN python -m venv --system-site-packages ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

##
# Make sure pip, pipenv, setuptools, and wheel are the latest versions
##
RUN python -m pip install --no-cache-dir --upgrade pip pipenv setuptools wheel

##
# Install code-gov-update Python requirements
##
WORKDIR /tmp
COPY src/Pipfile src/Pipfile.lock ./
RUN pipenv sync --clear --verbose

FROM python:3.10.5-alpine3.16 as build-stage

###
# Unprivileged user setup variables
###
ARG CISA_UID=421
ARG CISA_GID=${CISA_UID}
ARG CISA_USER="cisa"
ENV CISA_GROUP=${CISA_USER}
ENV CISA_HOME="/home/${CISA_USER}"

# The location for the Python venv we will use
ENV VIRTUAL_ENV="/.venv"

# Dependencies for the LLNL/scraper Python package
# These are used to estimate labor hours for code.
ENV SCRAPER_DEPS \
  cloc \
  git

###
# Create unprivileged user
###
RUN addgroup --system --gid ${CISA_GID} ${CISA_GROUP} \
  && adduser --system --uid ${CISA_UID} --ingroup ${CISA_GROUP} ${CISA_USER}

##
# Install the dependencies for the llnl-scraper Python package
##
RUN apk --no-cache add ${SCRAPER_DEPS}

# Copy in the Python venv we created in the compile stage
COPY --from=compile-stage ${VIRTUAL_ENV} ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Copy in the necessary files
COPY --chown=${CISA_USER}:${CISA_GROUP} src/update.sh src/email-update.py src/body.txt src/body.html ${CISA_HOME}/

###
# Prepare to run
###
WORKDIR ${CISA_HOME}
USER ${CISA_USER}
ENTRYPOINT ["./update.sh"]
